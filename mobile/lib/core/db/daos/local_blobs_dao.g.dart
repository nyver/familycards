// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_blobs_dao.dart';

// ignore_for_file: type=lint
mixin _$LocalBlobsDaoMixin on DatabaseAccessor<AppDatabase> {
  $LocalBlobsTable get localBlobs => attachedDatabase.localBlobs;
  LocalBlobsDaoManager get managers => LocalBlobsDaoManager(this);
}

class LocalBlobsDaoManager {
  final _$LocalBlobsDaoMixin _db;
  LocalBlobsDaoManager(this._db);
  $$LocalBlobsTableTableManager get localBlobs =>
      $$LocalBlobsTableTableManager(_db.attachedDatabase, _db.localBlobs);
}
