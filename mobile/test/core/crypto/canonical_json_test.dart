import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/crypto/canonical_json.dart';

void main() {
  const basePayload = CardPayload(
    barcodeFormat: 'ean13',
    cardNumber: '4600000000000',
    color: 4294198070,
    createdAt: 1755300000000,
    customFields: [CustomField('Level', 'Gold')],
    favorite: true,
    logoAsset: 'pyaterochka',
    sortOrder: 10,
    storeName: 'Пятёрочка',
  );

  test('serialization is stable across repeated calls', () {
    final bytes1 = canonicalPayloadBytes(basePayload);
    final bytes2 = canonicalPayloadBytes(basePayload);
    expect(bytes1, equals(bytes2));
  });

  test('keys are emitted in fixed alphabetical order regardless of construction order', () {
    // Two payloads built with fields specified in different orders in the
    // constructor call must still serialize identically, since Dart named
    // arguments do not affect field storage order and _canonicalMap always
    // rebuilds the map with the same fixed key order.
    const a = CardPayload(
      storeName: 'Store',
      cardNumber: '123',
      barcodeFormat: 'code128',
      color: 100,
      createdAt: 1,
    );
    const b = CardPayload(
      color: 100,
      createdAt: 1,
      barcodeFormat: 'code128',
      cardNumber: '123',
      storeName: 'Store',
    );
    expect(canonicalPayloadBytes(a), equals(canonicalPayloadBytes(b)));
  });

  test('the exact key order matches the spec example', () {
    final jsonString = utf8.decode(canonicalPayloadBytes(basePayload));
    final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
    expect(decoded.keys.toList(), [
      'back_blob',
      'barcode_format',
      'card_number',
      'color',
      'created_at',
      'custom_fields',
      'favorite',
      'front_blob',
      'logo_asset',
      'note',
      'schema',
      'secondary_number',
      'sort_order',
      'store_name',
    ]);
  });

  test('color and timestamps are serialized as integers, never floats', () {
    final jsonString = utf8.decode(canonicalPayloadBytes(basePayload));
    expect(jsonString.contains('4294198070.0'), isFalse);
    expect(jsonString.contains('1755300000000.0'), isFalse);
    expect(jsonString.contains('"color":4294198070'), isTrue);
    expect(jsonString.contains('"created_at":1755300000000'), isTrue);
  });

  test('there is no insignificant whitespace', () {
    final jsonString = utf8.decode(canonicalPayloadBytes(basePayload));
    expect(jsonString.contains(' '), isFalse);
    expect(jsonString.contains('\n'), isFalse);
  });

  test('transport metadata fields are never present in the payload', () {
    final jsonString = utf8.decode(canonicalPayloadBytes(basePayload));
    for (final forbidden in [
      '"id"',
      '"updated_at"',
      '"deleted"',
      '"base_rev"',
      '"dirty"',
    ]) {
      expect(
        jsonString.contains(forbidden),
        isFalse,
        reason: '$forbidden must not appear in the payload',
      );
    }
  });

  test(
    'content_hash is identical for the same payload built independently',
    () async {
      const a = CardPayload(
        barcodeFormat: 'ean13',
        cardNumber: '4600000000000',
        color: 4294198070,
        createdAt: 1755300000000,
        customFields: [CustomField('Level', 'Gold')],
        favorite: true,
        logoAsset: 'pyaterochka',
        sortOrder: 10,
        storeName: 'Пятёрочка',
      );
      final hashA = await contentHash(basePayload);
      final hashB = await contentHash(a);
      expect(hashA, equals(hashB));
    },
  );

  test('content_hash changes when a field changes', () async {
    final original = await contentHash(basePayload);
    final changed = await contentHash(
      CardPayload(
        barcodeFormat: basePayload.barcodeFormat,
        cardNumber: '9999999999999',
        color: basePayload.color,
        createdAt: basePayload.createdAt,
        storeName: basePayload.storeName,
      ),
    );
    expect(original, isNot(equals(changed)));
  });

  test('round-trips through canonical bytes and back without losing data', () {
    final bytes = canonicalPayloadBytes(basePayload);
    final parsed = parseCanonicalPayload(bytes);
    expect(parsed.storeName, basePayload.storeName);
    expect(parsed.cardNumber, basePayload.cardNumber);
    expect(parsed.color, basePayload.color);
    expect(parsed.customFields, basePayload.customFields);
    expect(parsed.favorite, basePayload.favorite);
  });

  test('non-ASCII characters survive the round trip exactly', () {
    const payload = CardPayload(
      barcodeFormat: 'ean13',
      cardNumber: '1',
      color: 0,
      createdAt: 0,
      note: 'Заметка с эмодзи 🎉 and ASCII',
      storeName: 'Пятёрочка',
    );
    final bytes = canonicalPayloadBytes(payload);
    final parsed = parseCanonicalPayload(bytes);
    expect(parsed.note, payload.note);
    expect(parsed.storeName, payload.storeName);
  });
}
