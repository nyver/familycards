import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/crypto/envelope.dart';
import 'package:mobile/core/db/database.dart';
import 'package:mobile/features/cards/card_repository.dart';
import 'package:mobile/features/settings/export_service.dart';
import 'package:mobile/features/settings/import_service.dart';

Card _card(String id, String name, String number) {
  return Card(
    id: id,
    storeName: name,
    cardNumber: number,
    barcodeFormat: 'code128',
    secondaryNumber: null,
    note: '',
    color: 0xFF112233,
    logoAsset: null,
    frontBlobId: null,
    backBlobId: null,
    customFields: '[]',
    favorite: false,
    sortOrder: 0,
    useCount: 0,
    createdAt: 1000,
    updatedAt: 1000,
    deleted: false,
    deletedAt: null,
    baseRev: 0,
    dirty: false,
  );
}

void main() {
  test('a wrong password fails to decrypt an archive for import', () async {
    final bytes = await ExportService.encryptCards([
      _card('card-1', 'Pyaterochka', '4600000000000'),
    ], 'correct horse');

    await expectLater(
      ExportService.decryptCards(bytes, 'wrong password'),
      throwsA(isA<DecryptionFailedException>()),
    );
  });

  test('payloadFromExportJson fills in the fields export omits', () {
    final payload = ImportService.payloadFromExportJson({
      'store_name': 'Pyaterochka',
      'card_number': '4600000000000',
      'barcode_format': 'ean13',
      'secondary_number': null,
      'note': 'a note',
      'color': 0xFF008C44,
      'custom_fields': [],
      'favorite': true,
    }, importedAt: 12345);

    expect(payload.storeName, 'Pyaterochka');
    expect(payload.cardNumber, '4600000000000');
    expect(payload.barcodeFormat, 'ean13');
    expect(payload.favorite, isTrue);
    expect(payload.createdAt, 12345);
    expect(payload.frontBlob, isNull);
    expect(payload.backBlob, isNull);
    expect(payload.logoAsset, isNull);
    expect(payload.sortOrder, 0);
  });

  group('CardRepository.importCards', () {
    late AppDatabase database;
    late CardRepository repository;

    setUp(() {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      repository = CardRepository(database.cardsDao);
    });

    tearDown(() async {
      await database.close();
    });

    test('adds every card from an archive with no duplicates', () async {
      final source = [
        _card('card-1', 'Pyaterochka', '4600000000000'),
        _card('card-2', 'Magnit', '1234567890128'),
      ];
      final bytes = await ExportService.encryptCards(source, 'password');
      final decoded = await ExportService.decryptCards(bytes, 'password');
      final payloads = decoded
          .map(
            (json) => ImportService.payloadFromExportJson(
              json,
              importedAt: 5000,
            ),
          )
          .toList();

      final result = await repository.importCards(
        payloads,
        includeDuplicates: false,
      );

      expect(result.added, 2);
      expect(result.skippedDuplicates, 0);

      final visible = await database.cardsDao.watchVisibleCards().first;
      expect(visible, hasLength(2));
      for (final card in visible) {
        expect(card.dirty, isTrue);
      }
      expect(
        visible.map((c) => c.id).toSet(),
        isNot(contains('card-1')),
        reason: 'imported cards get fresh UUIDv7 ids, not the exported ones',
      );
    });

    test(
      'skips a card that duplicates an existing visible card by default',
      () async {
        await repository.createCard(
          ImportService.payloadFromExportJson({
            'store_name': 'Pyaterochka',
            'card_number': '4600000000000',
            'barcode_format': 'ean13',
            'color': 0xFF008C44,
          }, importedAt: 1000),
        );

        final bytes = await ExportService.encryptCards([
          _card('card-1', 'Pyaterochka', '4600000000000'),
          _card('card-2', 'Magnit', '1234567890128'),
        ], 'password');
        final decoded = await ExportService.decryptCards(bytes, 'password');
        final payloads = decoded
            .map(
              (json) => ImportService.payloadFromExportJson(
                json,
                importedAt: 5000,
              ),
            )
            .toList();

        final result = await repository.importCards(
          payloads,
          includeDuplicates: false,
        );

        expect(result.added, 1);
        expect(result.skippedDuplicates, 1);
        final visible = await database.cardsDao.watchVisibleCards().first;
        expect(visible, hasLength(2)); // the pre-existing one + Magnit
      },
    );

    test(
      'includes duplicates as new cards when includeDuplicates is true',
      () async {
        await repository.createCard(
          ImportService.payloadFromExportJson({
            'store_name': 'Pyaterochka',
            'card_number': '4600000000000',
            'barcode_format': 'ean13',
            'color': 0xFF008C44,
          }, importedAt: 1000),
        );

        final bytes = await ExportService.encryptCards([
          _card('card-1', 'Pyaterochka', '4600000000000'),
        ], 'password');
        final decoded = await ExportService.decryptCards(bytes, 'password');
        final payloads = decoded
            .map(
              (json) => ImportService.payloadFromExportJson(
                json,
                importedAt: 5000,
              ),
            )
            .toList();

        final result = await repository.importCards(
          payloads,
          includeDuplicates: true,
        );

        expect(result.added, 1);
        expect(result.skippedDuplicates, 0);
        final visible = await database.cardsDao.watchVisibleCards().first;
        expect(visible, hasLength(2)); // both the original and the import
      },
    );
  });
}
