import 'dart:math';

/// 8-character invite codes using Crockford's Base32 alphabet: digits and
/// uppercase letters minus I, L, O, U (which are excluded specifically
/// because they are easily confused with 1, 1, 0, and V when handwritten
/// or read aloud). The canonical (post-normalization) form is exactly 8
/// characters with no separators; [format] adds a display-only hyphen.
class InviteCode {
  static const _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  static const length = 8;

  /// Generates a fresh random 8-character code in canonical form.
  static String generate() {
    final random = Random.secure();
    return List.generate(
      length,
      (_) => _alphabet[random.nextInt(_alphabet.length)],
    ).join();
  }

  /// Formats a canonical code for display, e.g. "7K4M9QRT" -> "7K4M-9QRT".
  static String format(String canonical) {
    if (canonical.length != length) return canonical;
    return '${canonical.substring(0, 4)}-${canonical.substring(4)}';
  }

  /// Normalizes user-entered text into canonical form: uppercases,
  /// strips whitespace/hyphens, and maps the classic Crockford
  /// ambiguous-character substitutions (O -> 0, I and L -> 1). Returns
  /// null if the result is not a valid 8-character Crockford Base32
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
