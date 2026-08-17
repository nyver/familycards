import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// One user-defined "key: value" field attached to a card. Order matters
/// (it is a list, not a map) and is preserved exactly as the user arranged
/// it - unlike the payload's own top-level keys, which are canonically
/// sorted.
class CustomField {
  final String k;
  final String v;
  const CustomField(this.k, this.v);

  Map<String, dynamic> toJson() => {'k': k, 'v': v};

  factory CustomField.fromJson(Map<String, dynamic> json) =>
      CustomField(json['k'] as String, json['v'] as String);

  @override
  bool operator ==(Object other) =>
      other is CustomField && other.k == k && other.v == v;
  @override
  int get hashCode => Object.hash(k, v);
}

/// The plaintext card payload that gets canonically serialized, hashed,
/// and encrypted. Deliberately excludes transport metadata (`id`,
/// `updated_at`, `deleted`, `base_rev`, `dirty`) - those live outside the
/// encrypted envelope, per the spec.
class CardPayload {
  final String? backBlob;
  final String barcodeFormat;
  final String cardNumber;
  final int color; // ARGB, as an unsigned 32-bit value
  final int createdAt; // unix ms
  final List<CustomField> customFields;
  final bool favorite;
  final String? frontBlob;
  final String? logoAsset;
  final String note;
  final int schema;
  final String? secondaryNumber;
  final int sortOrder;
  final String storeName;

  const CardPayload({
    this.backBlob,
    required this.barcodeFormat,
    required this.cardNumber,
    required this.color,
    required this.createdAt,
    this.customFields = const [],
    this.favorite = false,
    this.frontBlob,
    this.logoAsset,
    this.note = '',
    this.schema = 1,
    this.secondaryNumber,
    this.sortOrder = 0,
    required this.storeName,
  });

  /// Builds the canonical map: keys in a fixed, alphabetically sorted
  /// order (matching FamilyCards_SQLite_Master_Prompt.md §5 exactly), no
  /// key omitted regardless of null-ness. Dart's [Map] preserves insertion
  /// order and [jsonEncode] serializes in that order, so building the map
  /// with keys already alphabetized is sufficient to make serialization
  /// canonical - no separate sort step is needed downstream.
  Map<String, dynamic> _canonicalMap() => {
    'back_blob': backBlob,
    'barcode_format': barcodeFormat,
    'card_number': cardNumber,
    'color': color,
    'created_at': createdAt,
    'custom_fields': customFields.map((f) => f.toJson()).toList(),
    'favorite': favorite,
    'front_blob': frontBlob,
    'logo_asset': logoAsset,
    'note': note,
    'schema': schema,
    'secondary_number': secondaryNumber,
    'sort_order': sortOrder,
    'store_name': storeName,
  };

  factory CardPayload.fromJson(Map<String, dynamic> json) => CardPayload(
    backBlob: json['back_blob'] as String?,
    barcodeFormat: json['barcode_format'] as String,
    cardNumber: json['card_number'] as String,
    color: json['color'] as int,
    createdAt: json['created_at'] as int,
    customFields: (json['custom_fields'] as List<dynamic>? ?? const [])
        .map((e) => CustomField.fromJson(e as Map<String, dynamic>))
        .toList(),
    favorite: json['favorite'] as bool? ?? false,
    frontBlob: json['front_blob'] as String?,
    logoAsset: json['logo_asset'] as String?,
    note: json['note'] as String? ?? '',
    schema: json['schema'] as int? ?? 1,
    secondaryNumber: json['secondary_number'] as String?,
    sortOrder: json['sort_order'] as int? ?? 0,
    storeName: json['store_name'] as String,
  );
}

/// Serializes [payload] to its canonical UTF-8 byte representation: sorted
/// keys, no insignificant whitespace, integers (never floating point) for
/// `color` and timestamps. This exact byte sequence is what gets hashed
/// (for [contentHash]) and encrypted.
Uint8List canonicalPayloadBytes(CardPayload payload) {
  final jsonString = jsonEncode(payload._canonicalMap());
  return Uint8List.fromList(utf8.encode(jsonString));
}

/// sha256 of the canonical plaintext. Local-only: never transmitted. Used
/// purely to detect whether a save actually changed anything, so a
/// no-op edit does not spuriously mark a card dirty.
Future<String> contentHash(CardPayload payload) async {
  final bytes = canonicalPayloadBytes(payload);
  final digest = await Sha256().hash(bytes);
  return digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// Parses canonical payload bytes back into a [CardPayload].
CardPayload parseCanonicalPayload(List<int> bytes) {
  final jsonString = utf8.decode(bytes);
  return CardPayload.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
}
