import 'package:drift/drift.dart' show Value;
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

  test(
    'visible cards sort favorites first, then most-used within each group',
    () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      Future<void> insert(String id, {required bool favorite, int at = 0}) {
        return db.cardsDao.insertNewCard(
          CardsCompanion.insert(
            id: id,
            storeName: id,
            cardNumber: '123456',
            barcodeFormat: 'code128',
            color: 0xFF112233,
            createdAt: now + at,
            updatedAt: now + at,
            favorite: Value(favorite),
          ),
        );
      }

      // Insertion order deliberately does not match the expected sort
      // order, so the test cannot pass by accident from insertion order
      // alone.
      await insert('fav-low-use', favorite: true, at: 0);
      await insert('plain-low-use', favorite: false, at: 1);
      await insert('fav-high-use', favorite: true, at: 2);
      await insert('plain-high-use', favorite: false, at: 3);

      // 3 uses each for the "high-use" cards, 1 each for "low-use".
      for (var i = 0; i < 3; i++) {
        await db.cardsDao.incrementUseCount('fav-high-use');
        await db.cardsDao.incrementUseCount('plain-high-use');
      }
      await db.cardsDao.incrementUseCount('fav-low-use');
      await db.cardsDao.incrementUseCount('plain-low-use');

      final visible = await db.cardsDao.watchVisibleCards().first;
      expect(visible.map((c) => c.id), [
        'fav-high-use',
        'fav-low-use',
        'plain-high-use',
        'plain-low-use',
      ]);
    },
  );

  test(
    'incrementUseCount does not mark the card dirty or bump updatedAt',
    () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.cardsDao.insertNewCard(
        CardsCompanion.insert(
          id: 'card-3',
          storeName: 'Lenta',
          cardNumber: '1234567890128',
          barcodeFormat: 'ean13',
          color: 0xFF0056A3,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.cardsDao.markSynced('card-3', 1); // simulate a synced card

      await db.cardsDao.incrementUseCount('card-3');
      await db.cardsDao.incrementUseCount('card-3');

      final card = await db.cardsDao.getCard('card-3');
      expect(card!.useCount, 2);
      expect(
        card.dirty,
        isFalse,
        reason: 'usage tracking must never trigger a sync push',
      );
      expect(card.updatedAt, now);
    },
  );

  test(
    'existsVisibleByStoreAndNumber finds a matching visible card',
    () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.cardsDao.insertNewCard(
        CardsCompanion.insert(
          id: 'card-4',
          storeName: 'Pyaterochka',
          cardNumber: '4600000000000',
          barcodeFormat: 'ean13',
          color: 0xFF008C44,
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect(
        await db.cardsDao.existsVisibleByStoreAndNumber(
          'Pyaterochka',
          '4600000000000',
        ),
        isTrue,
      );
    },
  );

  test(
    'existsVisibleByStoreAndNumber returns false when nothing matches',
    () async {
      expect(
        await db.cardsDao.existsVisibleByStoreAndNumber(
          'Nonexistent',
          '000',
        ),
        isFalse,
      );
    },
  );

  test(
    'existsVisibleByStoreAndNumber ignores a deleted card with the same '
    'store and number',
    () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.cardsDao.insertNewCard(
        CardsCompanion.insert(
          id: 'card-5',
          storeName: 'Magnit',
          cardNumber: '1234567890128',
          barcodeFormat: 'ean13',
          color: 0xFFE31E24,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.cardsDao.softDelete('card-5', now + 1, now + 1);

      expect(
        await db.cardsDao.existsVisibleByStoreAndNumber(
          'Magnit',
          '1234567890128',
        ),
        isFalse,
      );
    },
  );

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
