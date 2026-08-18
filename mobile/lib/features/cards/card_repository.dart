import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../../core/crypto/canonical_json.dart';
import '../../core/db/daos/cards_dao.dart';
import '../../core/db/database.dart';

const _trashRetention = Duration(days: 30);
const _uuid = Uuid();

/// Bridges the drift-backed [CardsDao] with the encryption layer's
/// [CardPayload]: creates cards with fresh UUIDv7 ids, and marks a card
/// dirty (needing sync) only when an edit actually changes its content,
/// per the content_hash comparison in core/crypto/canonical_json.dart.
class CardRepository {
  final CardsDao dao;
  CardRepository(this.dao);

  Stream<List<Card>> watchVisibleCards() => dao.watchVisibleCards();
  Stream<List<Card>> watchTrash() => dao.watchTrash();
  Stream<Card?> watchCard(String id) => dao.watchCard(id);
  Future<Card?> getCard(String id) => dao.getCard(id);

  /// Converts a stored row into the plaintext payload shape the crypto
  /// layer works with.
  static CardPayload toPayload(Card card) => CardPayload(
    backBlob: card.backBlobId,
    barcodeFormat: card.barcodeFormat,
    cardNumber: card.cardNumber,
    color: card.color,
    createdAt: card.createdAt,
    customFields: (jsonDecode(card.customFields) as List<dynamic>)
        .map((e) => CustomField.fromJson(e as Map<String, dynamic>))
        .toList(),
    favorite: card.favorite,
    frontBlob: card.frontBlobId,
    logoAsset: card.logoAsset,
    note: card.note,
    secondaryNumber: card.secondaryNumber,
    sortOrder: card.sortOrder,
    storeName: card.storeName,
  );

  /// Builds the full [CardsCompanion] a payload maps to - the single place
  /// create, update, and the sync engine's remote-apply path (see
  /// features/sync/sync_service.dart) all go through, so a field added to
  /// [CardPayload] can't be forgotten in one of the three independently.
  static CardsCompanion toCompanion(
    CardPayload payload, {
    required String id,
    required int updatedAt,
    required bool dirty,
    Value<int> baseRev = const Value.absent(),
  }) {
    return CardsCompanion.insert(
      id: id,
      storeName: payload.storeName,
      cardNumber: payload.cardNumber,
      barcodeFormat: payload.barcodeFormat,
      color: payload.color,
      createdAt: payload.createdAt,
      updatedAt: updatedAt,
      secondaryNumber: Value(payload.secondaryNumber),
      note: Value(payload.note),
      logoAsset: Value(payload.logoAsset),
      frontBlobId: Value(payload.frontBlob),
      backBlobId: Value(payload.backBlob),
      customFields: Value(
        jsonEncode(payload.customFields.map((f) => f.toJson()).toList()),
      ),
      favorite: Value(payload.favorite),
      sortOrder: Value(payload.sortOrder),
      dirty: Value(dirty),
      baseRev: baseRev,
    );
  }

  /// Creates a new card from a payload, generating a UUIDv7 id and marking
  /// it dirty (it has never been pushed).
  Future<String> createCard(CardPayload payload) async {
    final id = _uuid.v7();
    final now = DateTime.now().millisecondsSinceEpoch;
    await dao.insertNewCard(
      toCompanion(payload, id: id, updatedAt: now, dirty: true),
    );
    return id;
  }

  /// Imports cards decoded from a local export archive (see
  /// features/settings/import_service.dart). Each payload goes through the
  /// same [createCard] path as manual entry - fresh UUIDv7 id, marked
  /// dirty - unless it duplicates an existing visible card by store name
  /// and card number, in which case it is skipped unless
  /// [includeDuplicates] is true.
  Future<ImportResult> importCards(
    List<CardPayload> payloads, {
    required bool includeDuplicates,
  }) async {
    var added = 0;
    var skippedDuplicates = 0;
    for (final payload in payloads) {
      if (!includeDuplicates) {
        final isDuplicate = await dao.existsVisibleByStoreAndNumber(
          payload.storeName,
          payload.cardNumber,
        );
        if (isDuplicate) {
          skippedDuplicates++;
          continue;
        }
      }
      await createCard(payload);
      added++;
    }
    return ImportResult(added: added, skippedDuplicates: skippedDuplicates);
  }

  /// Applies an edit to an existing card. If the new payload's canonical
  /// content is identical to what is already stored, this is a no-op:
  /// updatedAt is not bumped and the card is not marked dirty, so an
  /// unchanged save never triggers a needless sync push.
  Future<void> updateCard(String id, CardPayload newPayload) async {
    final existing = await dao.getCard(id);
    if (existing == null) return;

    final existingHash = await contentHash(toPayload(existing));
    final newHash = await contentHash(newPayload);
    if (existingHash == newHash) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    await dao.updateCardLocally(
      id,
      toCompanion(newPayload, id: id, updatedAt: now, dirty: true),
    );
  }

  Future<void> toggleFavorite(String id, bool favorite) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await dao.updateCardLocally(
      id,
      CardsCompanion(
        favorite: Value(favorite),
        updatedAt: Value(now),
        dirty: const Value(true),
      ),
    );
  }

  /// Records that the card's detail screen was opened, for the "most
  /// used first" sort order.
  Future<void> recordUsage(String id) => dao.incrementUseCount(id);

  Future<void> softDelete(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await dao.softDelete(id, now, now);
  }

  Future<void> restore(String id) async {
    await dao.restore(id, DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> purgeForever(String id) => dao.purge(id);

  /// Physically removes trash entries older than the 30-day retention
  /// window. Intended to run once at app startup and periodically
  /// thereafter.
  Future<int> purgeExpiredTrash() {
    final cutoff = DateTime.now()
        .subtract(_trashRetention)
        .millisecondsSinceEpoch;
    return dao.purgeTrashOlderThan(cutoff);
  }
}

/// Outcome of [CardRepository.importCards]: how many cards were added and
/// how many were skipped because they duplicated an existing card.
class ImportResult {
  final int added;
  final int skippedDuplicates;
  const ImportResult({required this.added, required this.skippedDuplicates});
}
