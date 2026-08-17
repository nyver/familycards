import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import '../../core/crypto/argon2.dart';
import '../../core/crypto/envelope.dart';
import '../../core/db/database.dart';

/// AAD tag for the local export container, distinct from every other use
/// of the envelope primitives so an export file can never be mistaken for
/// (or substituted into) a sync/wrap ciphertext.
final _exportAad = utf8.encode('export-v1');
const _magic = 'FCW_EXPORT_V1';

/// Builds and reads the encrypted local export archive (`.fcw`): a single
/// JSON file containing an Argon2id-derived-key XChaCha20-Poly1305
/// envelope around the plaintext card list. Uses only the crypto
/// primitives already in the app (no archive/zip dependency) - see
/// DECISIONS.md.
class ExportService {
  const ExportService._();

  /// Encrypts [cards] under a key derived from [password] and returns the
  /// bytes to write to a `.fcw` file.
  static Future<Uint8List> encryptCards(
    List<Card> cards,
    String password,
  ) async {
    final payload = jsonEncode({
      'cards': cards.map(_cardToExportJson).toList(),
    });
    final salt = _randomBytes(16);
    const params = Argon2Params.defaults;
    final key = await deriveKeyEncryptionKey(
      password: password,
      salt: salt,
      params: params,
    );
    final envelope = await encryptEnvelope(
      plaintext: utf8.encode(payload),
      key: key,
      aad: _exportAad,
    );

    final container = {
      'magic': _magic,
      'kdf_salt': base64Encode(salt),
      'kdf_params': params.toJson(),
      'nonce': base64Encode(envelope.nonce),
      'ciphertext': base64Encode(envelope.ciphertext),
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(container)));
  }

  /// Decrypts a `.fcw` file's bytes with [password], returning the
  /// contained cards as decoded JSON maps. Throws
  /// [DecryptionFailedException] for a wrong password, a corrupted file,
  /// or a file that isn't a Family Card Wallet export at all.
  static Future<List<Map<String, dynamic>>> decryptCards(
    Uint8List fileBytes,
    String password,
  ) async {
    final Map<String, dynamic> container;
    try {
      container = jsonDecode(utf8.decode(fileBytes)) as Map<String, dynamic>;
    } catch (e) {
      throw DecryptionFailedException('not a Family Card Wallet export: $e');
    }
    if (container['magic'] != _magic) {
      throw const DecryptionFailedException('not a Family Card Wallet export');
    }

    final salt = base64Decode(container['kdf_salt'] as String);
    final params = Argon2Params.fromJson(
      container['kdf_params'] as Map<String, dynamic>,
    );
    final key = await deriveKeyEncryptionKey(
      password: password,
      salt: salt,
      params: params,
    );
    final envelope = Envelope(
      nonce: base64Decode(container['nonce'] as String),
      ciphertext: base64Decode(container['ciphertext'] as String),
    );
    final plaintext = await decryptEnvelope(
      envelope: envelope,
      key: key,
      aad: _exportAad,
    );

    final decoded = jsonDecode(utf8.decode(plaintext)) as Map<String, dynamic>;
    return (decoded['cards'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  static Map<String, dynamic> _cardToExportJson(Card c) => {
    'store_name': c.storeName,
    'card_number': c.cardNumber,
    'barcode_format': c.barcodeFormat,
    'secondary_number': c.secondaryNumber,
    'note': c.note,
    'color': c.color,
    'custom_fields': jsonDecode(c.customFields),
    'favorite': c.favorite,
  };
}

Uint8List _randomBytes(int length) {
  final random = Random.secure();
  return Uint8List.fromList(List.generate(length, (_) => random.nextInt(256)));
}
