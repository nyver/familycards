import 'package:drift/drift.dart';

/// Local, plaintext card storage - the single source of truth for reads.
/// Sync metadata (baseRev, dirty) lives alongside the plaintext fields so
/// the sync engine can operate on the same rows the UI reads, without a
/// separate shadow table.
class Cards extends Table {
  TextColumn get id => text()(); // UUIDv7
  TextColumn get storeName => text()();
  TextColumn get cardNumber => text()();
  TextColumn get barcodeFormat => text()();
  TextColumn get secondaryNumber => text().nullable()();
  TextColumn get note => text().withDefault(const Constant(''))();
  IntColumn get color => integer()(); // ARGB
  TextColumn get logoAsset => text().nullable()();
  TextColumn get frontBlobId => text().nullable()();
  TextColumn get backBlobId => text().nullable()();
  TextColumn get customFields =>
      text().withDefault(const Constant('[]'))(); // JSON array of {k,v}
  BoolColumn get favorite => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()(); // unix ms
  IntColumn get updatedAt => integer()(); // unix ms
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  IntColumn get deletedAt => integer().nullable()(); // unix ms

  // Sync metadata.
  IntColumn get baseRev => integer().withDefault(const Constant(0))();
  BoolColumn get dirty => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Single-row table tracking the client's sync cursor.
class SyncState extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  IntColumn get lastServerRev => integer().withDefault(const Constant(0))();
  IntColumn get lastSyncAt => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Locally cached, decrypted blob files (card photos) and their upload
/// state.
class LocalBlobs extends Table {
  TextColumn get blobId => text()();
  TextColumn get path => text()(); // path to the decrypted on-disk cache
  IntColumn get size => integer()();
  BoolColumn get uploaded => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {blobId};
}
