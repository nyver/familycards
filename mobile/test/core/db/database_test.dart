import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/db/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('migrations apply cleanly to an empty database', () async {
    // Opening and touching the tables is enough to force onCreate to run;
    // if the schema is malformed this throws.
    final cards = await db.cardsDao.watchVisibleCards().first;
    expect(cards, isEmpty);
  });

  test('a fresh database seeds exactly one sync_state row', () async {
    final state = await db.syncStateDao.getState();
    expect(state.id, 1);
    expect(state.lastServerRev, 0);
    expect(state.lastSyncAt, 0);
  });

  test('inserting and reading back a card round-trips all fields', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.cardsDao.insertNewCard(
      CardsCompanion.insert(
        id: 'card-1',
        storeName: 'Pyaterochka',
        cardNumber: '4600000000000',
        barcodeFormat: 'ean13',
        color: 0xFF008C44,
        createdAt: now,
        updatedAt: now,
      ),
    );

    final card = await db.cardsDao.getCard('card-1');
    expect(card, isNotNull);
    expect(card!.storeName, 'Pyaterochka');
    expect(card.cardNumber, '4600000000000');
    expect(card.barcodeFormat, 'ean13');
    expect(card.color, 0xFF008C44);
    expect(card.deleted, isFalse);
    expect(card.dirty, isFalse);
  });

  test('soft delete moves a card into the trash stream', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.cardsDao.insertNewCard(
      CardsCompanion.insert(
        id: 'card-2',
        storeName: 'Magnit',
        cardNumber: '1234567890128',
        barcodeFormat: 'ean13',
        color: 0xFFE31E24,
        createdAt: now,
        updatedAt: now,
      ),
    );

    await db.cardsDao.softDelete('card-2', now + 1, now + 1);

    final visible = await db.cardsDao.watchVisibleCards().first;
    expect(visible.where((c) => c.id == 'card-2'), isEmpty);

    final trash = await db.cardsDao.watchTrash().first;
    expect(trash.map((c) => c.id), contains('card-2'));

    final card = await db.cardsDao.getCard('card-2');
    expect(card!.dirty, isTrue);
  });

  test('sync cursor updates independently of lastSyncAt', () async {
    await db.syncStateDao.updateCursor(42);
    await db.syncStateDao.updateLastSyncAt(1000);

    final state = await db.syncStateDao.getState();
    expect(state.lastServerRev, 42);
    expect(state.lastSyncAt, 1000);

    await db.syncStateDao.updateCursor(100);
    final state2 = await db.syncStateDao.getState();
    expect(state2.lastServerRev, 100);
    expect(
      state2.lastSyncAt,
      1000,
      reason: 'updating the cursor must not reset lastSyncAt',
    );
  });

  test('local blob metadata round-trips and tracks upload state', () async {
    await db.localBlobsDao.recordBlob(
      LocalBlobsCompanion.insert(
        blobId: 'blob-1',
        path: '/tmp/blob-1',
        size: 1234,
        createdAt: 0,
      ),
    );

    expect(await db.localBlobsDao.exists('blob-1'), isTrue);
    final unuploaded = await db.localBlobsDao.getUnuploaded();
    expect(unuploaded.map((b) => b.blobId), contains('blob-1'));

    await db.localBlobsDao.markUploaded('blob-1');
    final unuploadedAfter = await db.localBlobsDao.getUnuploaded();
    expect(unuploadedAfter.map((b) => b.blobId), isNot(contains('blob-1')));
  });
}
