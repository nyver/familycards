import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// A decrypted-vs-encrypted pair matching the wire protocol's separate
/// `nonce` and `ciphertext` fields (see docs/API.md and
/// FamilyCards_SQLite_Master_Prompt.md §3). `ciphertext` here always
/// includes the Poly1305 authentication tag appended, matching what
/// XChaCha20-Poly1305 conventionally calls "ciphertext".
class Envelope {
  final Uint8List nonce;
  final Uint8List ciphertext;

  const Envelope({required this.nonce, required this.ciphertext});
}

/// AAD (associated data) tags fixed by the crypto spec. Each context uses
/// a distinct tag so a ciphertext encrypted for one purpose can never be
/// mistaken for (or replayed as) another.
class AadTags {
  static final itemSuffix = utf8.encode('item-v1');
  static final blob = utf8.encode('blob-v1');
  static final vkWrap = utf8.encode('vk-wrap-v1');
  static final invite = utf8.encode('invite-v1');
}

const _nonceLength = 24; // XChaCha20 nonce length
const _macLength = 16; // Poly1305 tag length

final _cipher = Xchacha20.poly1305Aead();

/// Thrown when decryption fails: wrong key, tampered ciphertext, or AAD
/// mismatch (e.g. a ciphertext being replayed under a different item_id).
/// Deliberately does not distinguish the cause - by design, an attacker
/// (or a caller with a bug) should not learn which check failed.
class DecryptionFailedException implements Exception {
  final String message;
  const DecryptionFailedException([this.message = 'decryption failed']);
  @override
  String toString() => 'DecryptionFailedException: $message';
}

/// Encrypts [plaintext] with [key] under XChaCha20-Poly1305, binding it to
/// [aad]. A fresh random nonce is generated for every call - never reuse a
/// nonce with the same key.
Future<Envelope> encryptEnvelope({
  required List<int> plaintext,
  required SecretKey key,
  required List<int> aad,
}) async {
  final secretBox = await _cipher.encrypt(plaintext, secretKey: key, aad: aad);
  return Envelope(
    nonce: Uint8List.fromList(secretBox.nonce),
    ciphertext: secretBox.concatenation(nonce: false, mac: true),
  );
}

/// Decrypts an [Envelope] produced by [encryptEnvelope]. Throws
/// [DecryptionFailedException] on any failure (wrong key, tampered bytes,
/// or AAD mismatch) rather than letting the underlying cryptography
/// exception type leak through to callers.
Future<Uint8List> decryptEnvelope({
  required Envelope envelope,
  required SecretKey key,
  required List<int> aad,
}) async {
  if (envelope.ciphertext.length < _macLength) {
    throw const DecryptionFailedException('ciphertext too short');
  }
  try {
    final secretBox = SecretBox.fromConcatenation(
      Uint8List.fromList([...envelope.nonce, ...envelope.ciphertext]),
      nonceLength: _nonceLength,
      macLength: _macLength,
    );
    final plaintext = await _cipher.decrypt(
      secretBox,
      secretKey: key,
      aad: aad,
    );
    return Uint8List.fromList(plaintext);
  } catch (_) {
    throw const DecryptionFailedException();
  }
}

/// Builds the AAD for an item: `item_id || 0x1F || "item-v1"`. The 0x1F
/// separator prevents a concatenation ambiguity between two different
/// variable-length item ids from ever producing the same AAD bytes.
List<int> itemAad(String itemId) {
  return [...utf8.encode(itemId), 0x1F, ...AadTags.itemSuffix];
}

/// Encrypts a card's canonical JSON payload for transport/storage.
Future<Envelope> encryptItem({
  required String itemId,
  required List<int> canonicalPayload,
  required SecretKey vaultKey,
}) {
  return encryptEnvelope(
    plaintext: canonicalPayload,
    key: vaultKey,
    aad: itemAad(itemId),
  );
}

/// Decrypts a card's canonical JSON payload. Throws
/// [DecryptionFailedException] if `itemId` does not match the id the
/// envelope was encrypted under (AAD mismatch) - this is what prevents a
/// ciphertext from being replayed onto a different item's row.
Future<Uint8List> decryptItem({
  required String itemId,
  required Envelope envelope,
  required SecretKey vaultKey,
}) {
  return decryptEnvelope(
    envelope: envelope,
    key: vaultKey,
    aad: itemAad(itemId),
  );
}

/// Encrypts a blob (card photo). Returns the exact bytes to upload
/// (`nonce || ciphertext`) and the content-addressed blob id (hex sha256
/// of those same bytes).
Future<({Uint8List uploadBytes, String blobId})> encryptBlob({
  required List<int> imageBytes,
  required SecretKey vaultKey,
}) async {
  final secretBox = await _cipher.encrypt(
    imageBytes,
    secretKey: vaultKey,
    aad: AadTags.blob,
  );
  final uploadBytes = secretBox.concatenation(nonce: true, mac: true);
  final digest = await Sha256().hash(uploadBytes);
  final blobId = digest.bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  return (uploadBytes: uploadBytes, blobId: blobId);
}

/// Decrypts blob bytes previously produced by [encryptBlob] (or downloaded
/// from the server for a `blob_id` the caller already trusts).
Future<Uint8List> decryptBlob({
  required Uint8List uploadBytes,
  required SecretKey vaultKey,
}) async {
  if (uploadBytes.length < _nonceLength + _macLength) {
    throw const DecryptionFailedException('blob too short');
  }
  try {
    final secretBox = SecretBox.fromConcatenation(
      uploadBytes,
      nonceLength: _nonceLength,
      macLength: _macLength,
    );
    final plaintext = await _cipher.decrypt(
      secretBox,
      secretKey: vaultKey,
      aad: AadTags.blob,
    );
    return Uint8List.fromList(plaintext);
  } catch (_) {
    throw const DecryptionFailedException();
  }
}

/// Wraps a vault key (VK) with a key-encryption key (KEK/IKEK/RKEK),
/// binding it to a purpose tag (`vk-wrap-v1` for password/recovery wraps,
/// `invite-v1` for invite-code wraps).
Future<Envelope> wrapVaultKey({
  required Uint8List vaultKey,
  required SecretKey keyEncryptionKey,
  required List<int> aad,
}) {
  return encryptEnvelope(plaintext: vaultKey, key: keyEncryptionKey, aad: aad);
}

/// Unwraps a vault key. Throws [DecryptionFailedException] on a wrong
/// password/code/phrase, a corrupted envelope, or a purpose-tag mismatch.
Future<Uint8List> unwrapVaultKey({
  required Envelope envelope,
  required SecretKey keyEncryptionKey,
  required List<int> aad,
}) {
  return decryptEnvelope(envelope: envelope, key: keyEncryptionKey, aad: aad);
}
