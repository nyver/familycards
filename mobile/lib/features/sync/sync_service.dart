import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/crypto/canonical_json.dart';
import '../../core/crypto/envelope.dart';
import '../../core/db/daos/cards_dao.dart';
import '../../core/db/daos/local_blobs_dao.dart';
import '../../core/db/daos/sync_state_dao.dart';
import '../../core/db/database.dart';
import '../../core/net/dto/dto.dart';
import '../../core/net/sync_api.dart';
import '../../core/result.dart';
import '../cards/card_repository.dart';
import '../cards/photo_attachment.dart' show blobCacheDir;
import 'conflict_resolver.dart';

/// How a single call to [SyncService.runOnce] concluded.
enum SyncOutcome { success, failed, skippedAlreadyRunning, skippedNoNetwork }

class SyncCycleResult {
  final SyncOutcome outcome;
  final AppError? error;
  const SyncCycleResult(this.outcome, [this.error]);
}

/// Performs one full sync cycle: upload pending blobs, push local
/// changes, pull remote changes, lazily download missing photos, then
/// record the sync timestamp - in that exact order (see
/// specs/client/sync/spec.md, "Порядок цикла синхронизации"). Stateless
/// across calls except for the `_running` reentrancy guard; all durable
/// state (cursor, dirty flags, blob upload status) lives in the database.
class SyncService {
  final SyncApi api;
  final CardsDao cardsDao;
  final LocalBlobsDao blobsDao;
  final SyncStateDao syncStateDao;
  final SecretKey vaultKey;
  final String deviceId;
  final Future<bool> Function() hasNetwork;

  /// Called with a card's name whenever its unsynced local edit was lost
  /// to a push conflict. Mutable (rather than constructor-only) so
  /// [SyncController] can wire it to its own notice stream after
  /// constructing this service - see the doc comment there.
  void Function(String cardName)? onConflictLostSink;
  void Function(String message)? onDiagnostic;

  bool _running = false;

  SyncService({
    required this.api,
    required this.cardsDao,
    required this.blobsDao,
    required this.syncStateDao,
    required this.vaultKey,
    required this.deviceId,
    this.onDiagnostic,
    Future<bool> Function()? hasNetwork,
  }) : hasNetwork = hasNetwork ?? _defaultHasNetwork;

  static Future<bool> _defaultHasNetwork() async {
    final results = await Connectivity().checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }

  Future<SyncCycleResult> runOnce() async {
    // Set synchronously, before the first `await`, so two calls made
    // back-to-back (e.g. a trigger firing while a debounced sync is
    // already starting) cannot both observe `_running == false` and race
    // past this guard - there is no suspension point between the check
    // and the set.
    if (_running) {
      return const SyncCycleResult(SyncOutcome.skippedAlreadyRunning);
    }
    _running = true;

    try {
      if (!await hasNetwork()) {
        return const SyncCycleResult(SyncOutcome.skippedNoNetwork);
      }

      final blobErr = await _uploadPendingBlobs();
      if (blobErr != null) return SyncCycleResult(SyncOutcome.failed, blobErr);

      final pushErr = await _pushLocalChanges();
      if (pushErr != null) return SyncCycleResult(SyncOutcome.failed, pushErr);

      final pullErr = await _pullRemoteChanges();
      if (pullErr != null) return SyncCycleResult(SyncOutcome.failed, pullErr);

      await _downloadMissingBlobs();

      await syncStateDao.updateLastSyncAt(
        DateTime.now().millisecondsSinceEpoch,
      );
      return const SyncCycleResult(SyncOutcome.success);
    } finally {
      _running = false;
    }
  }

  // ---- Step 1: blobs before items ----

  Future<AppError?> _uploadPendingBlobs() async {
    final pending = await blobsDao.getUnuploaded();
    for (final blob in pending) {
      final file = File(blob.path);
      if (!await file.exists()) {
        // The cached file is gone (e.g. app storage was cleared); nothing
        // to upload, and retrying forever would be pointless.
        await blobsDao.deleteBlob(blob.blobId);
        continue;
      }
      final bytes = await file.readAsBytes();
      final result = await api.uploadBlob(blobId: blob.blobId, body: bytes);
      if (result.isErr) return result.errorOrNull;
      await blobsDao.markUploaded(blob.blobId);
    }
    return null;
  }

  // ---- Step 2: push local changes, batched ----

  Future<AppError?> _pushLocalChanges() async {
    while (true) {
      final dirty = await cardsDao.getDirtyCards(limit: 100);
      if (dirty.isEmpty) return null;

      final items = await Future.wait(dirty.map(_toPushItemDto));
      final result = await api.push(deviceId: deviceId, items: items);
      if (result.isErr) return result.errorOrNull;

      final response = result.valueOrNull!;
      for (final accepted in response.accepted) {
        await cardsDao.markSynced(accepted.itemId, accepted.rev);
      }

      final byId = {for (final c in dirty) c.id: c};
      for (final conflict in response.conflicts) {
        final localCard = byId[conflict.itemId];
        await _applyRemoteItem(conflict);
        if (localCard != null) onConflictLostSink?.call(localCard.storeName);
      }

      if (dirty.length < 100) return null;
    }
  }

  Future<PushItemDto> _toPushItemDto(Card card) async {
    if (card.deleted) {
      return PushItemDto(
        itemId: card.id,
        kind: 'card',
        baseRev: card.baseRev,
        updatedAt: card.updatedAt,
        deleted: true,
      );
    }

    final payload = CardRepository.toPayload(card);
    final plaintext = canonicalPayloadBytes(payload);
    final envelope = await encryptItem(
      itemId: card.id,
      canonicalPayload: plaintext,
      vaultKey: vaultKey,
    );
    final blobRefs = [
      if (card.frontBlobId != null) card.frontBlobId!,
      if (card.backBlobId != null) card.backBlobId!,
    ];

    return PushItemDto(
      itemId: card.id,
      kind: 'card',
      baseRev: card.baseRev,
      updatedAt: card.updatedAt,
      deleted: false,
      nonce: base64Encode(envelope.nonce),
      ciphertext: base64Encode(envelope.ciphertext),
      blobRefs: blobRefs,
    );
  }

  // ---- Step 3: pull remote changes, paginated ----

  Future<AppError?> _pullRemoteChanges() async {
    var since = (await syncStateDao.getState()).lastServerRev;

    while (true) {
      final result = await api.getChanges(since: since, limit: 200);
      if (result.isErr) return result.errorOrNull;
      final page = result.valueOrNull!;

      for (final item in page.items) {
        await _applyIncomingItem(item);
      }

      since = page.nextSince;
      // Persisted after every page (not just at the end) so an
      // interrupted cycle resumes from here instead of reprocessing
      // already-applied pages.
      await syncStateDao.updateCursor(since);

      if (!page.hasMore) return null;
    }
  }

  Future<void> _applyIncomingItem(ItemDto item) async {
    final local = await cardsDao.getCard(item.itemId);
    if (local != null && local.dirty) {
      final localWins = ConflictResolver.localWinsOverRemote(
        localBaseRev: local.baseRev,
        localUpdatedAt: local.updatedAt,
        localDeviceId: deviceId,
        remoteRev: item.rev,
        remoteUpdatedAt: item.updatedAt,
        remoteDeviceId: item.deviceId,
      );
      if (localWins) {
        return; // keep the unsynced local edit; it will be pushed next cycle
      }
    }
    await _applyRemoteItem(item);
  }

  /// Overwrites local state with an authoritative remote version - used
  /// both for pull and for conflicts reported by push (the server has
  /// already decided in both cases; the client's job is just to apply it).
  Future<void> _applyRemoteItem(ItemDto item) async {
    if (item.deleted) {
      final existing = await cardsDao.getCard(item.itemId);
      if (existing == null) return; // nothing local to tombstone
      await cardsDao.updateCardLocally(
        item.itemId,
        CardsCompanion(
          deleted: const Value(true),
          deletedAt: Value(item.updatedAt),
          updatedAt: Value(item.updatedAt),
          baseRev: Value(item.rev),
          dirty: const Value(false),
        ),
      );
      return;
    }

    final Uint8List plaintext;
    try {
      plaintext = await decryptItem(
        itemId: item.itemId,
        envelope: Envelope(
          nonce: base64Decode(item.nonce!),
          ciphertext: base64Decode(item.ciphertext!),
        ),
        vaultKey: vaultKey,
      );
    } on DecryptionFailedException {
      onDiagnostic?.call(
        'Could not decrypt item ${item.itemId} at rev ${item.rev}; skipped.',
      );
      return;
    }

    final payload = parseCanonicalPayload(plaintext);
    final companion = CardRepository.toCompanion(
      payload,
      id: item.itemId,
      updatedAt: item.updatedAt,
      dirty: false,
      baseRev: Value(item.rev),
    ).copyWith(deleted: const Value(false), deletedAt: const Value(null));
    await cardsDao.applyRemote(companion);
  }

  // ---- Step 4: lazy blob download for visible cards ----

  Future<void> _downloadMissingBlobs() async {
    final visible = await cardsDao.getVisibleCards();
    final neededIds = <String>{
      for (final card in visible) ...[
        if (card.frontBlobId != null) card.frontBlobId!,
        if (card.backBlobId != null) card.backBlobId!,
      ],
    };

    for (final blobId in neededIds) {
      if (await blobsDao.exists(blobId)) continue;
      try {
        final result = await api.getBlob(blobId);
        final bytes = result.valueOrNull;
        if (bytes == null) continue; // best-effort; retried next cycle

        final dir = await blobCacheDir();
        final path = p.join(dir.path, blobId);
        await File(path).writeAsBytes(bytes, flush: true);
        await blobsDao.recordBlob(
          LocalBlobsCompanion.insert(
            blobId: blobId,
            path: path,
            size: bytes.length,
            createdAt: DateTime.now().millisecondsSinceEpoch,
            uploaded: const Value(true),
          ),
        );
      } catch (_) {
        // A single photo failing to download must not break the screen
        // or the rest of the cycle - see "Сбой догрузки не ломает экран".
      }
    }
  }
}

/// The sync engine's externally visible state, driving the compact status
/// indicator (see sync_status_provider.dart). [pendingCount] and
/// [lastSyncAt] are meaningful regardless of [phase]; [lastErrorMessage]
/// is only set once a cycle has failed and is cleared on the next success.
enum SyncPhase { idle, syncing, error }

class SyncStatus {
  final SyncPhase phase;
  final DateTime? lastSyncAt;
  final int pendingCount;
  final String? lastErrorMessage;

  const SyncStatus({
    this.phase = SyncPhase.idle,
    this.lastSyncAt,
    this.pendingCount = 0,
    this.lastErrorMessage,
  });

  SyncStatus copyWith({
    SyncPhase? phase,
    DateTime? lastSyncAt,
    int? pendingCount,
    String? lastErrorMessage,
    bool clearError = false,
  }) {
    return SyncStatus(
      phase: phase ?? this.phase,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      pendingCount: pendingCount ?? this.pendingCount,
      lastErrorMessage: clearError
          ? null
          : (lastErrorMessage ?? this.lastErrorMessage),
    );
  }
}

const _debounceDelay = Duration(seconds: 3);
const _periodicInterval = Duration(minutes: 15);

/// Exponential backoff schedule for consecutive cycle failures: 2, 4, 8,
/// 16, 30 seconds, five attempts total - see "Обработка ошибок и
/// повторные попытки".
const _backoffDelays = [
  Duration(seconds: 2),
  Duration(seconds: 4),
  Duration(seconds: 8),
  Duration(seconds: 16),
  Duration(seconds: 30),
];

/// Owns the sync engine's lifecycle for the duration of an authenticated
/// session: every external trigger (app start, foreground, a debounced
/// local edit, pull-to-refresh, the 15-minute periodic tick), and the
/// backoff retry chain that follows a failed cycle. A [StateNotifier] so
/// the compact status indicator can watch it directly via riverpod.
class SyncController extends StateNotifier<SyncStatus> {
  final SyncService _service;
  final CardsDao _cardsDao;

  Timer? _debounceTimer;
  Timer? _periodicTimer;
  Timer? _backoffTimer;
  int _consecutiveFailures = 0;
  StreamSubscription<int>? _dirtySub;
  bool _disposed = false;

  final _conflictNotices = StreamController<String>.broadcast();

  /// Card names whose local edit was lost to a push conflict - surfaced by
  /// the UI as a non-blocking snackbar (see "Уведомление о потерянной
  /// правке").
  Stream<String> get conflictNotices => _conflictNotices.stream;

  /// Builds the [SyncService] internally (rather than accepting one) so it
  /// can wire the service's conflict callback back to [conflictNotices]
  /// without a construction-order cycle.
  SyncController({
    required SyncApi api,
    required CardsDao cardsDao,
    required LocalBlobsDao blobsDao,
    required SyncStateDao syncStateDao,
    required SecretKey vaultKey,
    required String deviceId,
  }) : _cardsDao = cardsDao,
       _service = SyncService(
         api: api,
         cardsDao: cardsDao,
         blobsDao: blobsDao,
         syncStateDao: syncStateDao,
         vaultKey: vaultKey,
         deviceId: deviceId,
       ),
       super(const SyncStatus()) {
    _service.onConflictLostSink = _conflictNotices.add;
    _dirtySub = _cardsDao.watchDirtyCount().listen(_onDirtyCountChanged);
  }

  /// Called once when the authenticated session begins: starts the
  /// periodic timer and runs an immediate sync.
  void start() {
    _startPeriodicTimer();
    _trigger();
  }

  void onAppForeground() {
    _startPeriodicTimer();
    _trigger();
  }

  void onAppBackground() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  Future<void> refreshNow() => _trigger();

  void _startPeriodicTimer() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(_periodicInterval, (_) => _trigger());
  }

  void _onDirtyCountChanged(int count) {
    if (_disposed) return;
    // Only a genuine increase (a new local edit) should (re)start the
    // debounce timer - a decrease just means a sync already cleared some
    // dirty flags and must not retrigger itself. Compared against the
    // previous pendingCount already held in state, rather than a second
    // piece of mutable state that could drift out of sync with it.
    final increased = count > state.pendingCount;
    state = state.copyWith(pendingCount: count);
    if (increased) {
      _scheduleDebouncedSync();
    }
  }

  void _scheduleDebouncedSync() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDelay, _trigger);
  }

  /// Entry point for every external trigger: cancels any pending backoff
  /// wait and a fresh attempt chain of up to five tries.
  Future<void> _trigger() async {
    _backoffTimer?.cancel();
    _backoffTimer = null;
    _consecutiveFailures = 0;
    await _attemptSync();
  }

  Future<void> _attemptSync() async {
    if (_disposed) return;
    state = state.copyWith(phase: SyncPhase.syncing);

    final result = await _service.runOnce();
    if (_disposed) return;

    switch (result.outcome) {
      case SyncOutcome.success:
        _consecutiveFailures = 0;
        state = state.copyWith(
          phase: SyncPhase.idle,
          lastSyncAt: DateTime.now(),
          pendingCount: await _cardsDao.countDirtyCards(),
          clearError: true,
        );
      case SyncOutcome.failed:
        _consecutiveFailures++;
        state = state.copyWith(
          phase: SyncPhase.error,
          lastErrorMessage: result.error?.message,
        );
        if (_consecutiveFailures < _backoffDelays.length) {
          _backoffTimer = Timer(
            _backoffDelays[_consecutiveFailures - 1],
            _attemptSync,
          );
        }
      case SyncOutcome.skippedNoNetwork:
        state = state.copyWith(phase: SyncPhase.idle);
      case SyncOutcome.skippedAlreadyRunning:
        // Another cycle is genuinely in flight; leave the indicator
        // showing "syncing" as-is.
        break;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
    _periodicTimer?.cancel();
    _backoffTimer?.cancel();
    _dirtySub?.cancel();
    _conflictNotices.close();
    super.dispose();
  }
}
