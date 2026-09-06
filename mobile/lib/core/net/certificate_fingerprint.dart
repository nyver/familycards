import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

/// Number of raw bytes in a SHA-256 digest.
const sha256FingerprintLength = 32;

/// Thrown when a user-entered fingerprint cannot be parsed as a 32-byte
/// SHA-256 digest.
class InvalidFingerprintFormatException implements Exception {
  final String message;
  const InvalidFingerprintFormatException([
    this.message = 'not a valid SHA-256 certificate fingerprint',
  ]);

  @override
  String toString() => 'InvalidFingerprintFormatException: $message';
}

final _hexPairsOnly = RegExp(r'^[0-9a-fA-F]+$');
final _separators = RegExp(r'[:\s-]');

/// Parses a user-entered SHA-256 fingerprint into 32 raw bytes. Accepts any
/// mix of upper/lower-case hex, with or without ':'/' '/'-' separators
/// between byte pairs (matching both openssl's `sha256 Fingerprint=` output
/// and a plain 64-character hex string). Returns null if, once separators
/// are stripped, the input is not exactly 32 bytes of valid hex.
Uint8List? tryParseSha256Fingerprint(String input) {
  final stripped = input.replaceAll(_separators, '');
  if (stripped.length != sha256FingerprintLength * 2) return null;
  if (!_hexPairsOnly.hasMatch(stripped)) return null;

  final bytes = Uint8List(sha256FingerprintLength);
  for (var i = 0; i < sha256FingerprintLength; i++) {
    bytes[i] = int.parse(stripped.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return bytes;
}

/// Like [tryParseSha256Fingerprint], but throws
/// [InvalidFingerprintFormatException] instead of returning null.
Uint8List parseSha256Fingerprint(String input) {
  final bytes = tryParseSha256Fingerprint(input);
  if (bytes == null) throw const InvalidFingerprintFormatException();
  return bytes;
}

/// Formats raw digest bytes as uppercase colon-separated hex (e.g.
/// `"AB:CD:EF:..."`) - the canonical display and storage form used
/// throughout the app, matching what a server's startup log or
/// `openssl x509 -fingerprint -sha256` prints.
String formatFingerprint(List<int> bytes) {
  return bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(':');
}

/// Computes the SHA-256 digest of a certificate's DER-encoded bytes -
/// exactly what is compared against a pinned fingerprint. Synchronous
/// (unlike `package:cryptography`'s API) because it must run inside
/// [HttpClient.badCertificateCallback], which is not async.
Uint8List sha256OfCertificate(X509Certificate certificate) {
  return Uint8List.fromList(crypto.sha256.convert(certificate.der).bytes);
}

/// Compares two byte sequences in constant time (with respect to their
/// contents - the early-return on length mismatch is safe since lengths
/// are not secret), so that checking a presented certificate's digest
/// against a pinned fingerprint cannot leak information via timing.
bool constantTimeBytesEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}
