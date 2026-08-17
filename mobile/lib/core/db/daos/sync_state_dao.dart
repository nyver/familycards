import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'sync_state_dao.g.dart';

@DriftAccessor(tables: [SyncState])
class SyncStateDao extends DatabaseAccessor<AppDatabase>
    with _$SyncStateDaoMixin {
  SyncStateDao(super.db);

  Future<SyncStateData> getState() async {
    final row = await (select(
      syncState,
    )..where((s) => s.id.equals(1))).getSingleOrNull();
    return row ?? const SyncStateData(id: 1, lastServerRev: 0, lastSyncAt: 0);
  }

  Stream<SyncStateData> watchState() {
    return (select(
      syncState,
    )..where((s) => s.id.equals(1))).watchSingleOrNull().map(
      (row) =>
          row ?? const SyncStateData(id: 1, lastServerRev: 0, lastSyncAt: 0),
    );
  }

  Future<void> updateCursor(int lastServerRev) {
    return into(syncState).insertOnConflictUpdate(
      SyncStateCompanion(
        id: const Value(1),
        lastServerRev: Value(lastServerRev),
      ),
    );
  }

  Future<void> updateLastSyncAt(int lastSyncAtMillis) {
    return into(syncState).insertOnConflictUpdate(
      SyncStateCompanion(
        id: const Value(1),
        lastSyncAt: Value(lastSyncAtMillis),
      ),
    );
  }
}
