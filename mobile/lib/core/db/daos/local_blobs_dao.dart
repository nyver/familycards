import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'local_blobs_dao.g.dart';

@DriftAccessor(tables: [LocalBlobs])
class LocalBlobsDao extends DatabaseAccessor<AppDatabase>
    with _$LocalBlobsDaoMixin {
  LocalBlobsDao(super.db);

  Future<void> recordBlob(LocalBlobsCompanion blob) =>
      into(localBlobs).insertOnConflictUpdate(blob);

  Future<LocalBlob?> getBlob(String blobId) => (select(
    localBlobs,
  )..where((b) => b.blobId.equals(blobId))).getSingleOrNull();

  Future<bool> exists(String blobId) async {
    final row = await getBlob(blobId);
    return row != null;
  }

  Future<List<LocalBlob>> getUnuploaded() {
    return (select(localBlobs)..where((b) => b.uploaded.equals(false))).get();
  }

  Future<void> markUploaded(String blobId) {
    return (update(localBlobs)..where((b) => b.blobId.equals(blobId))).write(
      const LocalBlobsCompanion(uploaded: Value(true)),
    );
  }

  Future<void> deleteBlob(String blobId) =>
      (delete(localBlobs)..where((b) => b.blobId.equals(blobId))).go();

  Future<void> deleteAll() => delete(localBlobs).go();
}
