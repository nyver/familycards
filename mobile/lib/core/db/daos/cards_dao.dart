import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'cards_dao.g.dart';

@DriftAccessor(tables: [Cards])
class CardsDao extends DatabaseAccessor<AppDatabase> with _$CardsDaoMixin {
  CardsDao(super.db);

  /// Live, non-deleted cards ordered for the main list: favorites first,
  /// then most-used first within each group, then creation order for
  /// cards tied on use count (including cards never opened yet).
  Stream<List<Card>> watchVisibleCards() {
    final query = select(cards)
      ..where((c) => c.deleted.equals(false))
      ..orderBy([
        (c) => OrderingTerm.desc(c.favorite),
        (c) => OrderingTerm.desc(c.useCount),
        (c) => OrderingTerm.asc(c.createdAt),
      ]);
    return query.watch();
  }

  Stream<List<Card>> watchTrash() {
    final query = select(cards)
      ..where((c) => c.deleted.equals(true))
      ..orderBy([(c) => OrderingTerm.desc(c.deletedAt)]);
    return query.watch();
  }

  /// One-shot equivalent of [watchVisibleCards], used by the sync engine
  /// to find cards that may need a lazily-downloaded photo.
  Future<List<Card>> getVisibleCards() =>
      (select(cards)..where((c) => c.deleted.equals(false))).get();

  Future<Card?> getCard(String id) =>
      (select(cards)..where((c) => c.id.equals(id))).getSingleOrNull();

  Stream<Card?> watchCard(String id) =>
      (select(cards)..where((c) => c.id.equals(id))).watchSingleOrNull();

  /// Inserts a brand-new, locally created card. Marked dirty so it is
  /// picked up by the next sync push.
  Future<void> insertNewCard(CardsCompanion card) => into(cards).insert(card);

  /// Applies a local edit to an existing card, bumping updatedAt and
  /// marking dirty. Callers are responsible for deciding whether the
  /// content actually changed (see content_hash in the crypto layer) -
  /// this DAO does not itself compare old vs. new content.
  Future<void> updateCardLocally(String id, CardsCompanion changes) async {
    await (update(cards)..where((c) => c.id.equals(id))).write(changes);
  }

  Future<void> softDelete(String id, int deletedAtMillis, int updatedAtMillis) {
    return (update(cards)..where((c) => c.id.equals(id))).write(
      CardsCompanion(
        deleted: const Value(true),
        deletedAt: Value(deletedAtMillis),
        updatedAt: Value(updatedAtMillis),
        dirty: const Value(true),
      ),
    );
  }

  Future<void> restore(String id, int updatedAtMillis) {
    return (update(cards)..where((c) => c.id.equals(id))).write(
      CardsCompanion(
        deleted: const Value(false),
        deletedAt: const Value(null),
        updatedAt: Value(updatedAtMillis),
        dirty: const Value(true),
      ),
    );
  }

  /// Physically removes a card row - used for the trash's "delete forever"
  /// action and for the 30-day trash auto-purge. Does not touch the
  /// server; the corresponding tombstone push already happened when the
  /// card was soft-deleted.
  Future<void> purge(String id) =>
      (delete(cards)..where((c) => c.id.equals(id))).go();

  Future<int> purgeTrashOlderThan(int cutoffMillis) {
    return (delete(cards)..where(
          (c) =>
              c.deleted.equals(true) &
              c.deletedAt.isSmallerThanValue(cutoffMillis),
        ))
        .go();
  }

  Future<List<Card>> getDirtyCards({int limit = 100}) {
    return (select(cards)
          ..where((c) => c.dirty.equals(true))
          ..limit(limit))
        .get();
  }

  Future<int> countDirtyCards() async {
    final count = countAll(filter: cards.dirty.equals(true));
    final query = selectOnly(cards)..addColumns([count]);
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  /// Live count of not-yet-synced cards, used both to display the pending
  /// count in the sync status indicator and to trigger a debounced sync
  /// whenever a local edit increases it.
  Stream<int> watchDirtyCount() {
    final count = countAll(filter: cards.dirty.equals(true));
    final query = selectOnly(cards)..addColumns([count]);
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  /// Marks a card clean after a successful push, recording the server-
  /// assigned revision.
  Future<void> markSynced(String id, int newBaseRev) {
    return (update(cards)..where((c) => c.id.equals(id))).write(
      CardsCompanion(dirty: const Value(false), baseRev: Value(newBaseRev)),
    );
  }

  /// Applies a remote version of a card (from a pull, or from a server-
  /// side conflict resolution), overwriting local state and clearing the
  /// dirty flag. Used for both existing and never-before-seen items.
  Future<void> applyRemote(CardsCompanion remote) {
    return into(cards).insertOnConflictUpdate(remote);
  }

  /// Records a "use" of a card - opening its detail screen to show the
  /// barcode. Local-only bookkeeping: deliberately does not touch
  /// `updatedAt`/`dirty`, so it never triggers a sync push and never
  /// becomes part of the encrypted payload (see tables.dart's doc comment
  /// on `useCount`).
  Future<void> incrementUseCount(String id) async {
    final row = await getCard(id);
    if (row == null) return;
    await (update(cards)..where((c) => c.id.equals(id))).write(
      CardsCompanion(useCount: Value(row.useCount + 1)),
    );
  }
}
