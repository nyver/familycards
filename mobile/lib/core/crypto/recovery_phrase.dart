import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Generates and validates 12-word recovery phrases using the standard
/// BIP-39 scheme (128 bits of CSPRNG entropy + a 4-bit checksum = 132
/// bits, split into twelve 11-bit indices into a 2048-word list). The
/// phrase itself (words joined by single spaces) is fed directly into
/// Argon2id as the "password" when deriving RKEK - see
/// FamilyCards_SQLite_Master_Prompt.md §3.
///
/// This class only implements the mnemonic encoding; it does not
/// implement the rest of the BIP-39 standard (e.g. the PBKDF2-based seed
/// stretching used by cryptocurrency wallets) - RKEK derivation uses
/// Argon2id per this project's own spec instead.
class RecoveryPhrase {
  static const wordCount = 12;
  static const _entropyBytes = 16; // 128 bits
  static const _checksumBits = 4; // entropyBits / 32
  static const _bitsPerWord = 11;
  static const expectedWordlistLength = 2048;

  /// Generates a fresh 12-word phrase from CSPRNG entropy.
  static Future<List<String>> generate(List<String> wordlist) async {
    _checkWordlist(wordlist);

    final entropy = _randomBytes(_entropyBytes);
    final checksum = await _checksumBitsFor(entropy);

    final bits = <int>[..._bytesToBits(entropy), ...checksum];
    final indices = _bitsToIndices(bits);
    return indices.map((i) => wordlist[i]).toList();
  }

  /// Validates a phrase against [wordlist]: every word must exist in the
  /// dictionary, and the encoded checksum must match the entropy encoded
  /// by the other words. Word comparison is case-insensitive and trims
  /// surrounding whitespace, but does not otherwise fuzzy-match - callers
  /// wanting "did you mean" suggestions should build that on top.
  static Future<bool> validate(
    List<String> words,
    List<String> wordlist,
  ) async {
    _checkWordlist(wordlist);
    if (words.length != wordCount) return false;

    final indices = <int>[];
    for (final rawWord in words) {
      final word = rawWord.trim().toLowerCase();
      final index = wordlist.indexOf(word);
      if (index == -1) return false;
      indices.add(index);
    }

    final bits = indices.expand((i) => _intToBits(i, _bitsPerWord)).toList();
    final entropyBits = bits.sublist(0, _entropyBytes * 8);
    final claimedChecksum = bits.sublist(_entropyBytes * 8);

    final entropy = _bitsToBytes(entropyBits);
    final actualChecksum = await _checksumBitsFor(entropy);

    if (claimedChecksum.length != actualChecksum.length) return false;
    for (var i = 0; i < claimedChecksum.length; i++) {
      if (claimedChecksum[i] != actualChecksum[i]) return false;
    }
    return true;
  }

  /// The exact string fed into Argon2id as the RKEK "password": words
  /// joined by single ASCII spaces, lowercase, no leading/trailing
  /// whitespace. Both generation and later re-entry by the user must
  /// normalize to this same form or RKEK derivation will silently produce
  /// a different key.
  static String toKdfInput(List<String> words) =>
      words.map((w) => w.trim().toLowerCase()).join(' ');

  static void _checkWordlist(List<String> wordlist) {
    if (wordlist.length != expectedWordlistLength) {
      throw ArgumentError(
        'BIP-39 wordlist must have exactly $expectedWordlistLength words, got ${wordlist.length}',
      );
    }
  }

  static Future<List<int>> _checksumBitsFor(Uint8List entropy) async {
    final hash = await Sha256().hash(entropy);
    final firstByteBits = _byteToBits(hash.bytes[0]);
    return firstByteBits.sublist(0, _checksumBits);
  }

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List.generate(length, (_) => random.nextInt(256)),
    );
  }

  static List<int> _bytesToBits(List<int> bytes) {
    return bytes.expand(_byteToBits).toList();
  }

  static List<int> _byteToBits(int byte) {
    return List.generate(8, (i) => (byte >> (7 - i)) & 1);
  }

  static List<int> _intToBits(int value, int bitCount) {
    return List.generate(bitCount, (i) => (value >> (bitCount - 1 - i)) & 1);
  }

  static List<int> _bitsToIndices(List<int> bits) {
    final indices = <int>[];
    for (var i = 0; i < bits.length; i += _bitsPerWord) {
      var value = 0;
      for (var j = 0; j < _bitsPerWord; j++) {
        value = (value << 1) | bits[i + j];
      }
      indices.add(value);
    }
    return indices;
  }

  static Uint8List _bitsToBytes(List<int> bits) {
    final bytes = Uint8List(bits.length ~/ 8);
    for (var i = 0; i < bytes.length; i++) {
      var value = 0;
      for (var j = 0; j < 8; j++) {
        value = (value << 1) | bits[i * 8 + j];
      }
      bytes[i] = value;
    }
    return bytes;
  }
}

/// Loads the BIP-39 English wordlist from its bundled asset. Kept as a
/// free function (rather than baked into [RecoveryPhrase]) so tests can
/// supply an in-memory wordlist without touching the Flutter asset
/// bundle.
Future<List<String>> loadBip39Wordlist(
  Future<String> Function() readAsset,
) async {
  final content = await readAsset();
  final words = content
      .split('\n')
      .map((w) => w.trim())
      .where((w) => w.isNotEmpty)
      .toList();
  return words;
}
