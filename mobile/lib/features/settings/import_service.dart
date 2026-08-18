import '../../core/crypto/canonical_json.dart';

/// Turns the raw JSON maps `ExportService.decryptCards` returns back into
/// [CardPayload]s ready for `CardRepository.importCards`. The export format
/// only carries a subset of `CardPayload` (see export_service.dart's
/// `_cardToExportJson`) - photos, `logo_asset`, `sort_order`, and
/// `created_at` are not part of it, so those get the same defaults the
/// card editor already uses for a freshly authored card (see
/// card_editor_screen.dart).
class ImportService {
  const ImportService._();

  static CardPayload payloadFromExportJson(
    Map<String, dynamic> json, {
    required int importedAt,
  }) {
    return CardPayload(
      barcodeFormat: json['barcode_format'] as String,
      cardNumber: json['card_number'] as String,
      color: json['color'] as int,
      createdAt: importedAt,
      customFields: (json['custom_fields'] as List<dynamic>? ?? const [])
          .map((e) => CustomField.fromJson(e as Map<String, dynamic>))
          .toList(),
      favorite: json['favorite'] as bool? ?? false,
      note: json['note'] as String? ?? '',
      secondaryNumber: json['secondary_number'] as String?,
      storeName: json['store_name'] as String,
    );
  }
}
