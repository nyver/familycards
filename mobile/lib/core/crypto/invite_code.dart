import 'dart:math';

/// 26-character invite codes using Crockford's Base32 alphabet: digits and
/// uppercase letters minus I, L, O, U (which are excluded specifically
/// because they are easily confused with 1, 1, 0, and V when handwritten
/// or read aloud). At 5 bits/char, 26 characters give 130 bits of entropy
/// - the code is the sole cryptographic secret protecting the wrapped
/// vault key (see [wrapVaultKeyWithInviteKey]) and the sole proof of
/// possession for the unauthenticated invite endpoints, so it must clear
/// the same >=128-bit bar as any other bearer secret in this system. The
/// canonical (post-normalization) form is exactly 26 characters with no
/// separators; [format] adds display-only hyphens.
class InviteCode {
  static const _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  static const length = 26;
  static const _groupSize = 4;

  /// Generates a fresh random 26-character code in canonical form.
  static String generate() {
    final random = Random.secure();
    return List.generate(
      length,
      (_) => _alphabet[random.nextInt(_alphabet.length)],
    ).join();
  }

  /// Formats a canonical code for display, inserting a hyphen every 4
  /// characters, e.g. "7K4M9QRTVXY2B4C6D8E9F2G4HJ" ->
  /// "7K4M-9QRT-VXY2-B4C6-D8E9-F2G4-HJ".
  static String format(String canonical) {
    if (canonical.length != length) return canonical;
    final groups = <String>[];
    for (var i = 0; i < canonical.length; i += _groupSize) {
      final end = (i + _groupSize < canonical.length)
          ? i + _groupSize
          : canonical.length;
      groups.add(canonical.substring(i, end));
    }
    return groups.join('-');
  }

  /// Normalizes user-entered text into canonical form: uppercases,
  /// strips whitespace/hyphens, and maps the classic Crockford
  /// ambiguous-character substitutions (O -> 0, I and L -> 1). Returns
  /// null if the result is not a valid 26-character Crockford Base32
  /// string.
  static String? normalize(String input) {
    final stripped = input
        .toUpperCase()
        .replaceAll(RegExp(r'[\s-]'), '')
        .split('')
        .map(_substituteAmbiguous)
        .join();

    if (stripped.length != length) return null;
    for (final char in stripped.split('')) {
      if (!_alphabet.contains(char)) return null;
    }
    return stripped;
  }

  static String _substituteAmbiguous(String char) {
    switch (char) {
      case 'O':
        return '0';
      case 'I':
      case 'L':
        return '1';
      default:
        return char;
    }
  }
}
