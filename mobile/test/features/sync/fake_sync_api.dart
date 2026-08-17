import 'dart:typed_data';

import 'package:mobile/core/net/dto/dto.dart';
import 'package:mobile/core/net/sync_api.dart';
import 'package:mobile/core/result.dart';
import 'package:mobile/features/sync/conflict_resolver.dart';

class _StoredItem {
  final String itemId;
  final String kind;
  final int rev;
  final int updatedAt;
  final bool deleted;
  final String deviceId;
  final String? nonce;
  final String? ciphertext;
  final List<String> blobRefs;

  const _StoredItem({
    required this.itemId,
    required this.kind,
    required this.rev,
    required this.updatedAt,
    required this.deleted,
    required this.deviceId,
    this.nonce,
    this.ciphertext,
    this.blobRefs = const [],
  });

  ItemDto toDto() => ItemDto(
    itemId: itemId,
    kind: kind,
    rev: rev,
    updatedAt: updatedAt,
    deleted: deleted,
    deviceId: deviceId,
    nonce: nonce,
    ciphertext: ciphertext,
    blobRefs: blobRefs,
  );
}

/// An in-memory stand-in for the wallet sync server, shared by two or more
/// [SyncService] instances in tests to exercise real convergence without a
/// network or a real server process. Applies the same conflict rule as the
/// server (via [ConflictResolver], since both must agree by construction -
/// see conflict_resolver_test.dart for verification against the canonical
/// vectors) and the same "blob must exist before it can be referenced"
/// rule as server/internal/sync's push handler.
class FakeSyncApi implements SyncApi {
  final Map<String, _StoredItem> _items = {};
  final Map<String, Uint8List> _blobs = {};
  int _lastRev = 0;

  /// Simulates the server rejecting the very next request with a network
  /// error - used to test that a failed push does not partially apply.
  bool failNextRequest = false;

  /// Artificial delay before every response, used to simulate a slow
  /// server and create a window in which a second concurrent sync call
  /// can be observed racing the first.
  Duration responseDelay = Duration.zero;

  /// Forces every getChanges call to use this page size regardless of
  /// what the caller asked for, to exercise multi-page pagination and
  /// cursor persistence deterministically.
  int? getChangesPageLimitOverride;

  final List<int> pushBatchSizes = [];
  final List<List<String>> pushCallOrder = [];
  final List<String> blobUploadOrder = [];

  Future<void> _delay() async {
    if (responseDelay > Duration.zero) {
      await Future<void>.delayed(responseDelay);
    }
  }

  @override
  Future<Result<ChangesResponse>> getChanges({
    required int since,
    int limit = 200,
  }) async {
    await _delay();
    if (failNextRequest) {
      failNextRequest = false;
      return Result.err(AppError.network('simulated failure'));
    }
    final effectiveLimit = getChangesPageLimitOverride ?? limit;
    final page = _items.values.where((i) => i.rev > since).toList()
      ..sort((a, b) => a.rev.compareTo(b.rev));
    final limited = page.take(effectiveLimit).toList();
    final nextSince = limited.isEmpty ? since : limited.last.rev;
    return Result.ok(
      ChangesResponse(
        serverRev: _lastRev,
        nextSince: nextSince,
        hasMore: nextSince < _lastRev,
        items: limited.map((i) => i.toDto()).toList(),
      ),
    );
  }

  @override
  Future<Result<PushResponse>> push({
    required String deviceId,
    required List<PushItemDto> items,
  }) async {
    await _delay();
    pushBatchSizes.add(items.length);
    pushCallOrder.add(items.map((i) => i.itemId).toList());
    if (failNextRequest) {
      failNextRequest = false;
      return Result.err(AppError.network('simulated failure'));
    }

    for (final dto in items) {
      for (final blobId in dto.blobRefs) {
        if (!_blobs.containsKey(blobId)) {
          return Result.err(
            AppError.conflict('references blobs that were not uploaded'),
          );
        }
      }
    }

    final accepted = <AcceptedItem>[];
    final conflicts = <ItemDto>[];
    for (final dto in items) {
      final cur = _items[dto.itemId];
      final current = CurrentItemState(
        exists: cur != null,
        rev: cur?.rev ?? 0,
        updatedAt: cur?.updatedAt ?? 0,
        deviceId: cur?.deviceId ?? '',
      );
      final incoming = IncomingItemState(
        baseRev: dto.baseRev,
        updatedAt: dto.updatedAt,
        deviceId: deviceId,
      );

      if (!ConflictResolver.accept(current, incoming)) {
        conflicts.add(
          cur?.toDto() ??
              ItemDto(
                itemId: dto.itemId,
                kind: dto.kind,
                rev: 0,
                updatedAt: 0,
                deleted: true,
                deviceId: '',
              ),
        );
        continue;
      }

      _lastRev++;
      final stored = _StoredItem(
        itemId: dto.itemId,
        kind: dto.kind,
        rev: _lastRev,
        updatedAt: dto.updatedAt,
        deleted: dto.deleted,
        deviceId: deviceId,
        nonce: dto.nonce,
        ciphertext: dto.ciphertext,
        blobRefs: dto.blobRefs,
      );
      _items[dto.itemId] = stored;
      accepted.add(AcceptedItem(itemId: dto.itemId, rev: _lastRev));
    }

    return Result.ok(
      PushResponse(
        serverRev: _lastRev,
        accepted: accepted,
        conflicts: conflicts,
      ),
    );
  }

  @override
  Future<Result<UploadBlobResponse>> uploadBlob({
    required String blobId,
    required Uint8List body,
  }) async {
    await _delay();
    blobUploadOrder.add(blobId);
    if (failNextRequest) {
      failNextRequest = false;
      return Result.err(AppError.network('simulated failure'));
    }
    _blobs[blobId] =
        body; // idempotent: re-uploading the same id is a no-op overwrite
    return Result.ok(UploadBlobResponse(blobId: blobId, size: body.length));
  }

  @override
  Future<Result<Uint8List>> getBlob(String blobId) async {
    await _delay();
    final bytes = _blobs[blobId];
    if (bytes == null) return Result.err(AppError.notFound('blob not found'));
    return Result.ok(bytes);
  }
}
