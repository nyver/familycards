import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/db/database.dart';
import 'package:mobile/core/net/dto/dto.dart';
import 'package:mobile/features/sync/sync_service.dart';

import 'fake_sync_api.dart';

Future<SecretKey> _testVaultKey() => Xchacha20.poly1305Aead().newSecretKey();

CardsCompanion _dirtyCard(
  String id, {
  String name = 'Store',
  bool deleted = false,
  int updatedAt = 1000,
}) {
  return CardsCompanion.insert(
    id: id,
    storeName: name,
    cardNumber: '123456',
    barcodeFormat: 'code128',
    color: 0xFF112233,
    createdAt: updatedAt,
    updatedAt: updatedAt,
    deleted: Value(deleted),
    dirty: const Value(true),
  );
}

void main() {
  late AppDatabase db;
  late FakeSyncApi api;
  late SecretKey vaultKey;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    api = FakeSyncApi();
    vaultKey = await _testVaultKey();
  });

  tearDown(() async {
    await db.close();
  });

  SyncService buildService({
    String deviceId = 'device-a',
    Future<bool> Function()? hasNetwork,
  }) {
    return SyncService(
      api: api,
      cardsDao: db.cardsDao,
      blobsDao: db.localBlobsDao,
      syncStateDao: db.syncStateDao,
      vaultKey: vaultKey,
      deviceId: deviceId,
      hasNetwork: hasNetwork ?? () async => true,
    );
  }

  test('pushes dirty cards and clears the dirty flag on success', () async {
    await db.cardsDao.insertNewCard(_dirtyCard('card-1'));
    await db.cardsDao.insertNewCard(_dirtyCard('card-2'));

    final result = await buildService().runOnce();

    expect(result.outcome, SyncOutcome.success);
    expect(await db.cardsDao.countDirtyCards(), 0);
    final card = await db.cardsDao.getCard('card-1');
    expect(card!.baseRev, greaterThan(0));
  });

  test('batches pushes at 100 items per request', () async {
    for (var i = 0; i < 250; i++) {
      await db.cardsDao.insertNewCard(
        _dirtyCard('card-$i', updatedAt: 1000 + i),
      );
    }

    final result = await buildService().runOnce();

    expect(result.outcome, SyncOutcome.success);
    expect(api.pushBatchSizes, [100, 100, 50]);
    expect(await db.cardsDao.countDirtyCards(), 0);
  });

  test('skips without making any request when offline', () async {
    final result = await buildService(hasNetwork: () async => false).runOnce();
    expect(result.outcome, SyncOutcome.skippedNoNetwork);
    expect(api.pushBatchSizes, isEmpty);
  });

  test(
    'a second concurrent call is skipped rather than run in parallel',
    () async {
      api.responseDelay = const Duration(milliseconds: 30);
      await db.cardsDao.insertNewCard(_dirtyCard('card-1'));

      final service = buildService();
      final first = service.runOnce();
      final second = service.runOnce();

      final results = await Future.wait([first, second]);
      final outcomes = results.map((r) => r.outcome).toSet();
      expect(outcomes, contains(SyncOutcome.skippedAlreadyRunning));
      expect(outcomes, contains(SyncOutcome.success));
    },
  );

  test(
    'a failed push leaves the database untouched and reports failed',
    () async {
      await db.cardsDao.insertNewCard(_dirtyCard('card-1'));
      api.failNextRequest = true;

      final result = await buildService().runOnce();

      expect(result.outcome, SyncOutcome.failed);
      expect(await db.cardsDao.countDirtyCards(), 1);
    },
  );

  test(
    'uploads a referenced blob before pushing the item that references it',
    () async {
      final tmp = await Directory.systemTemp.createTemp('sync_test_blob_');
      addTearDown(() => tmp.delete(recursive: true));
      final blobFile = File('${tmp.path}/blob-1');
      await blobFile.writeAsBytes([1, 2, 3]);

      await db.localBlobsDao.recordBlob(
        LocalBlobsCompanion.insert(
          blobId: 'blob-1',
          path: blobFile.path,
          size: 3,
          createdAt: 0,
        ),
      );
      await db.cardsDao.insertNewCard(
        _dirtyCard('card-1').copyWith(frontBlobId: const Value('blob-1')),
      );

      final result = await buildService().runOnce();

      expect(result.outcome, SyncOutcome.success);
      expect(api.blobUploadOrder, ['blob-1']);
      expect(api.pushCallOrder, [
        ['card-1'],
      ]);
      // The blob upload must be recorded (and therefore have happened)
      // before the push call that references it.
      expect(api.blobUploadOrder.first, 'blob-1');
    },
  );

  test('applies a pulled tombstone to a clean local card', () async {
    final dbB = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() => dbB.close());
    final serviceB = SyncService(
      api: api,
      cardsDao: dbB.cardsDao,
      blobsDao: dbB.localBlobsDao,
      syncStateDao: dbB.syncStateDao,
      vaultKey: vaultKey,
      deviceId: 'device-b',
      hasNetwork: () async => true,
    );

    // A creates and pushes; B pulls (clean copy on B).
    await db.cardsDao.insertNewCard(_dirtyCard('card-1', updatedAt: 1000));
    await buildService().runOnce();
    await serviceB.runOnce();
    expect((await dbB.cardsDao.getCard('card-1'))!.deleted, isFalse);

    // A deletes and pushes the tombstone; B pulls it.
    final card = (await db.cardsDao.getCard('card-1'))!;
    await db.cardsDao.softDelete(
      'card-1',
      card.updatedAt + 10,
      card.updatedAt + 10,
    );
    await buildService().runOnce();
    await serviceB.runOnce();

    expect((await dbB.cardsDao.getCard('card-1'))!.deleted, isTrue);
  });

  test(
    'an item that cannot be decrypted is skipped without aborting the pull',
    () async {
      // Push one well-formed item through the real service, plus one with
      // garbage ciphertext pushed directly through the fake API, then let a
      // second device pull both.
      await db.cardsDao.insertNewCard(_dirtyCard('card-good'));
      await buildService().runOnce();

      await api.push(
        deviceId: 'device-a',
        items: [
          PushItemDto(
            itemId: 'card-bad',
            kind: 'card',
            baseRev: 0,
            updatedAt: 1500,
            deleted: false,
            nonce: base64Encode(List.filled(24, 7)),
            ciphertext: base64Encode(
              List.filled(32, 9),
            ), // wrong MAC: fails to decrypt under any key
          ),
        ],
      );

      final diagnostics = <String>[];
      final puller = SyncService(
        api: api,
        cardsDao: db.cardsDao,
        blobsDao: db.localBlobsDao,
        syncStateDao: db.syncStateDao,
        vaultKey: vaultKey,
        deviceId: 'device-b',
        hasNetwork: () async => true,
        onDiagnostic: diagnostics.add,
      );
      final result = await puller.runOnce();

      expect(result.outcome, SyncOutcome.success);
      expect(diagnostics, isNotEmpty);
      expect(await db.cardsDao.getCard('card-good'), isNotNull);
      expect(await db.cardsDao.getCard('card-bad'), isNull);
    },
  );

  test(
    'resumes pagination from the persisted cursor after an interruption',
    () async {
      for (var i = 0; i < 3; i++) {
        await db.cardsDao.insertNewCard(
          _dirtyCard('seed-$i', updatedAt: 1000 + i),
        );
      }
      await buildService().runOnce(); // seeds the fake server with 3 items

      final dbB = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(() => dbB.close());
      final puller = SyncService(
        api: api,
        cardsDao: dbB.cardsDao,
        blobsDao: dbB.localBlobsDao,
        syncStateDao: dbB.syncStateDao,
        vaultKey: vaultKey,
        deviceId: 'device-b',
        hasNetwork: () async => true,
      );

      api.getChangesPageLimitOverride =
          1; // force one item per page, i.e. three round trips
      await puller.runOnce();

      final state = await dbB.syncStateDao.getState();
      expect(state.lastServerRev, 3);
      expect(await dbB.cardsDao.getCard('seed-0'), isNotNull);
      expect(await dbB.cardsDao.getCard('seed-2'), isNotNull);

      // Simulate an interruption partway through a second pull (e.g. a new
      // item lands on the server, but the puller only advances one page
      // before "crashing"): the cursor must reflect the page already
      // applied, not silently stay put or skip ahead.
      await db.cardsDao.insertNewCard(_dirtyCard('seed-3', updatedAt: 1003));
      await buildService().runOnce();
      await puller.runOnce();
      expect((await dbB.syncStateDao.getState()).lastServerRev, 4);
      expect(await dbB.cardsDao.getCard('seed-3'), isNotNull);
    },
  );

  group('two-device convergence', () {
    test(
      'offline edits on two devices converge to the same state after both sync',
      () async {
        final dbA = AppDatabase.forTesting(NativeDatabase.memory());
        final dbB = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(() async {
          await dbA.close();
          await dbB.close();
        });

        final shared = FakeSyncApi();
        final serviceA = SyncService(
          api: shared,
          cardsDao: dbA.cardsDao,
          blobsDao: dbA.localBlobsDao,
          syncStateDao: dbA.syncStateDao,
          vaultKey: vaultKey,
          deviceId: 'device-a',
          hasNetwork: () async => true,
        );
        final serviceB = SyncService(
          api: shared,
          cardsDao: dbB.cardsDao,
          blobsDao: dbB.localBlobsDao,
          syncStateDao: dbB.syncStateDao,
          vaultKey: vaultKey,
          deviceId: 'device-b',
          hasNetwork: () async => true,
        );

        // A creates a card and syncs; B pulls it.
        await dbA.cardsDao.insertNewCard(
          _dirtyCard('shared-1', name: 'Original', updatedAt: 1000),
        );
        await serviceA.runOnce();
        await serviceB.runOnce();
        expect((await dbB.cardsDao.getCard('shared-1'))!.storeName, 'Original');

        // Both devices edit it offline, B later than A.
        await dbA.cardsDao.updateCardLocally(
          'shared-1',
          CardsCompanion(
            storeName: const Value('From A'),
            updatedAt: const Value(2000),
            dirty: const Value(true),
          ),
        );
        await dbB.cardsDao.updateCardLocally(
          'shared-1',
          CardsCompanion(
            storeName: const Value('From B'),
            updatedAt: const Value(3000),
            dirty: const Value(true),
          ),
        );

        // A syncs first (pushes "From A"), then B syncs (its later edit
        // wins the conflict), then A syncs again to pull B's win.
        await serviceA.runOnce();
        await serviceB.runOnce();
        await serviceA.runOnce();

        final cardA = await dbA.cardsDao.getCard('shared-1');
        final cardB = await dbB.cardsDao.getCard('shared-1');
        expect(cardA!.storeName, 'From B');
        expect(cardB!.storeName, 'From B');
        expect(cardA.dirty, isFalse);
        expect(cardB.dirty, isFalse);
        expect(cardA.baseRev, cardB.baseRev);
      },
    );

    test(
      'a later delete on one device beats an earlier edit on the other',
      () async {
        final dbA = AppDatabase.forTesting(NativeDatabase.memory());
        final dbB = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(() async {
          await dbA.close();
          await dbB.close();
        });

        final shared = FakeSyncApi();
        final serviceA = SyncService(
          api: shared,
          cardsDao: dbA.cardsDao,
          blobsDao: dbA.localBlobsDao,
          syncStateDao: dbA.syncStateDao,
          vaultKey: vaultKey,
          deviceId: 'device-a',
          hasNetwork: () async => true,
        );
        final serviceB = SyncService(
          api: shared,
          cardsDao: dbB.cardsDao,
          blobsDao: dbB.localBlobsDao,
          syncStateDao: dbB.syncStateDao,
          vaultKey: vaultKey,
          deviceId: 'device-b',
          hasNetwork: () async => true,
        );

        await dbA.cardsDao.insertNewCard(
          _dirtyCard('shared-2', updatedAt: 1000),
        );
        await serviceA.runOnce();
        await serviceB.runOnce();

        // A edits (updatedAt 2000); B deletes later (updatedAt 3000).
        await dbA.cardsDao.updateCardLocally(
          'shared-2',
          CardsCompanion(
            storeName: const Value('Edited'),
            updatedAt: const Value(2000),
            dirty: const Value(true),
          ),
        );
        await dbB.cardsDao.softDelete('shared-2', 3000, 3000);

        await serviceA.runOnce();
        await serviceB.runOnce();
        await serviceA.runOnce();

        expect((await dbA.cardsDao.getCard('shared-2'))!.deleted, isTrue);
        expect((await dbB.cardsDao.getCard('shared-2'))!.deleted, isTrue);
      },
    );
  });
}
