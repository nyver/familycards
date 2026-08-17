import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'daos/cards_dao.dart';
import 'daos/local_blobs_dao.dart';
import 'daos/sync_state_dao.dart';
import 'tables.dart';

part 'database.g.dart';

/// The local SQLite database - the app's single source of truth for reads.
/// Sync writes into the same tables the UI reads from; there is no
/// separate cache layer.
@DriftDatabase(
  tables: [Cards, SyncState, LocalBlobs],
  daos: [CardsDao, SyncStateDao, LocalBlobsDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  /// A database that only exists in memory, for tests.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await into(syncState).insert(const SyncStateCompanion());
    },
  );

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'family_card_wallet.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}
