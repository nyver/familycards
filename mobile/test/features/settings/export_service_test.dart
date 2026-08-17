import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/crypto/envelope.dart';
import 'package:mobile/core/db/database.dart';
import 'package:mobile/features/settings/export_service.dart';

Card _card(String id, String name, String number) {
  return Card(
    id: id,
    storeName: name,
    cardNumber: number,
    barcodeFormat: 'code128',
    secondaryNumber: null,
    note: 'secret note',
    color: 0xFF112233,
    logoAsset: null,
    frontBlobId: null,
    backBlobId: null,
    customFields: '[]',
    favorite: false,
    sortOrder: 0,
    createdAt: 1000,
    updatedAt: 1000,
    deleted: false,
    deletedAt: null,
    baseRev: 0,
    dirty: false,
  );
}

void main() {
  test('a correct password decrypts the exported cards', () async {
    final cards = [
      _card('card-1', 'Pyaterochka', '4600000000000'),
      _card('card-2', 'Magnit', '1234567890128'),
    ];

    final bytes = await ExportService.encryptCards(cards, 'correct horse');
    final decrypted = await ExportService.decryptCards(bytes, 'correct horse');

    expect(decrypted, hasLength(2));
    expect(decrypted[0]['store_name'], 'Pyaterochka');
    expect(decrypted[0]['card_number'], '4600000000000');
    expect(decrypted[1]['store_name'], 'Magnit');
  });

  test('the archive is not readable as plaintext', () async {
    final cards = [_card('card-1', 'Pyaterochka', '4600000000000')];
    final bytes = await ExportService.encryptCards(cards, 'correct horse');

    // The container is JSON (so the file format itself is inspectable),
    // but none of the sensitive fields appear anywhere in it unencrypted.
    final asText = utf8.decode(bytes);
    expect(asText.contains('Pyaterochka'), isFalse);
    expect(asText.contains('4600000000000'), isFalse);
    expect(asText.contains('secret note'), isFalse);
  });

  test('a wrong password fails to decrypt', () async {
    final cards = [_card('card-1', 'Pyaterochka', '4600000000000')];
    final bytes = await ExportService.encryptCards(cards, 'correct horse');

    await expectLater(
      ExportService.decryptCards(bytes, 'wrong password'),
      throwsA(isA<DecryptionFailedException>()),
    );
  });

  test('a file that is not a Family Card Wallet export is rejected', () async {
    final bytes = utf8.encode(jsonEncode({'not': 'an export'}));
    await expectLater(
      ExportService.decryptCards(bytes, 'anything'),
      throwsA(isA<DecryptionFailedException>()),
    );
  });
}
