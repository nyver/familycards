import 'package:barcode/barcode.dart' as bw;
import 'package:mobile_scanner/mobile_scanner.dart' as scanner;

/// The 13 barcode format identifiers the app supports, exactly as they
/// appear on the wire (lowercase snake_case) - see
/// FamilyCards_SQLite_Master_Prompt.md §6.
class CardBarcodeFormat {
  static const ean13 = 'ean13';
  static const ean8 = 'ean8';
  static const upcA = 'upca';
  static const upcE = 'upce';
  static const code128 = 'code128';
  static const code39 = 'code39';
  static const code93 = 'code93';
  static const itf = 'itf';
  static const codabar = 'codabar';
  static const qr = 'qr';
  static const pdf417 = 'pdf417';
  static const aztec = 'aztec';
  static const dataMatrix = 'datamatrix';

  static const all = [
    ean13,
    ean8,
    upcA,
    upcE,
    code128,
    code39,
    code93,
    itf,
    codabar,
    qr,
    pdf417,
    aztec,
    dataMatrix, //
  ];
}

/// Result of validating a card number against a barcode format's rules.
class BarcodeValidation {
  final bool valid;
  final String? reason;
  const BarcodeValidation.ok() : valid = true, reason = null;
  const BarcodeValidation.invalid(this.reason) : valid = false;
}

/// Validates [number] against [format]'s rules: length, alphabet, and
/// checksum where the format defines one. Real cards frequently violate
/// these rules (partial prints, non-standard internal program codes), so
/// the UI must always let the user save anyway - this only informs that
/// choice, it never blocks it by itself.
BarcodeValidation validateBarcodeNumber(String format, String number) {
  switch (format) {
    case CardBarcodeFormat.ean13:
      return _validateDigitsWithChecksum(
        number,
        length: 13,
        checksum: _ean13CheckDigit,
      );
    case CardBarcodeFormat.ean8:
      return _validateDigitsWithChecksum(
        number,
        length: 8,
        checksum: _ean13CheckDigit,
      );
    case CardBarcodeFormat.upcA:
      return _validateDigitsWithChecksum(
        number,
        length: 12,
        checksum: _ean13CheckDigit,
      );
    case CardBarcodeFormat.upcE:
      return _validateUpcE(number);
    case CardBarcodeFormat.code128:
      return _validateAscii(number);
    case CardBarcodeFormat.code39:
      return _validateAlphabet(number, _code39Alphabet, 'code39');
    case CardBarcodeFormat.code93:
      return _validateAlphabet(number, _code93Alphabet, 'code93');
    case CardBarcodeFormat.itf:
      return _validateItf(number);
    case CardBarcodeFormat.codabar:
      return _validateAlphabet(number, _codabarAlphabet, 'codabar');
    case CardBarcodeFormat.qr:
    case CardBarcodeFormat.pdf417:
    case CardBarcodeFormat.aztec:
    case CardBarcodeFormat.dataMatrix:
      return number.isEmpty
          ? const BarcodeValidation.invalid('empty')
          : const BarcodeValidation.ok();
    default:
      return const BarcodeValidation.invalid('unknown format');
  }
}

/// Suggests a format for a number with none specified yet: a 13-digit
/// number with a valid EAN-13 checksum suggests ean13, otherwise code128 -
/// per FamilyCards_SQLite_Master_Prompt.md §6.
String suggestBarcodeFormat(String number) {
  if (number.length == 13 &&
      RegExp(r'^\d{13}$').hasMatch(number) &&
      _validateDigitsWithChecksum(
        number,
        length: 13,
        checksum: _ean13CheckDigit,
      ).valid) {
    return CardBarcodeFormat.ean13;
  }
  return CardBarcodeFormat.code128;
}

BarcodeValidation _validateDigitsWithChecksum(
  String number, {
  required int length,
  required int Function(String digitsWithoutCheck) checksum,
}) {
  if (number.length != length || !RegExp(r'^\d+$').hasMatch(number)) {
    return BarcodeValidation.invalid('expected $length digits');
  }
  final body = number.substring(0, length - 1);
  final expected = checksum(body);
  final actual = int.parse(number[length - 1]);
  if (expected != actual) {
    return const BarcodeValidation.invalid('checksum mismatch');
  }
  return const BarcodeValidation.ok();
}

/// GTIN check digit algorithm shared by EAN-13, EAN-8, and UPC-A: from the
/// rightmost digit of the body, alternate weights 3 and 1.
int _ean13CheckDigit(String body) {
  var sum = 0;
  final digits = body.split('').map(int.parse).toList().reversed.toList();
  for (var i = 0; i < digits.length; i++) {
    sum += digits[i] * (i.isEven ? 3 : 1);
  }
  return (10 - (sum % 10)) % 10;
}

BarcodeValidation _validateUpcE(String number) {
  if (number.length != 8 || !RegExp(r'^\d{8}$').hasMatch(number)) {
    return const BarcodeValidation.invalid('expected 8 digits');
  }
  final expanded = _expandUpcEToUpcA(number);
  if (expanded == null)
    return const BarcodeValidation.invalid('cannot expand to UPC-A');
  return _validateDigitsWithChecksum(
    expanded,
    length: 12,
    checksum: _ean13CheckDigit,
  );
}

/// Expands an 8-digit UPC-E code to its 12-digit UPC-A equivalent per the
/// standard GS1 zero-suppression rules, so its checksum can be validated
/// with the same algorithm as UPC-A.
String? _expandUpcEToUpcA(String upce) {
  final ns = upce[0];
  final d = upce.substring(1, 7); // 6 encoded digits
  final check = upce[7];

  final String body;
  switch (d[5]) {
    case '0':
    case '1':
    case '2':
      body = '${d[0]}${d[1]}${d[5]}0000${d[2]}${d[3]}${d[4]}';
      break;
    case '3':
      body = '${d[0]}${d[1]}${d[2]}00000${d[3]}${d[4]}';
      break;
    case '4':
      body = '${d[0]}${d[1]}${d[2]}${d[3]}00000${d[4]}';
      break;
    default:
      body = '${d[0]}${d[1]}${d[2]}${d[3]}${d[4]}0000${d[5]}';
  }
  return '$ns$body$check';
}

BarcodeValidation _validateAscii(String number) {
  if (number.isEmpty) return const BarcodeValidation.invalid('empty');
  final onlyAscii = number.codeUnits.every((c) => c >= 0 && c <= 127);
  return onlyAscii
      ? const BarcodeValidation.ok()
      : const BarcodeValidation.invalid('non-ASCII character');
}

BarcodeValidation _validateItf(String number) {
  if (!RegExp(r'^\d+$').hasMatch(number) || number.isEmpty) {
    return const BarcodeValidation.invalid('digits only');
  }
  if (number.length.isOdd) {
    return const BarcodeValidation.invalid(
      'ITF requires an even number of digits',
    );
  }
  return const BarcodeValidation.ok();
}

const _code39Alphabet = r'0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ-. $/+%';
const _code93Alphabet = r'0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ-. $/+%';
const _codabarAlphabet = r'0123456789-$:/.+ABCD';

BarcodeValidation _validateAlphabet(
  String number,
  String alphabet,
  String formatName,
) {
  if (number.isEmpty) return const BarcodeValidation.invalid('empty');
  final upper = number.toUpperCase();
  for (final char in upper.split('')) {
    if (!alphabet.contains(char)) {
      return BarcodeValidation.invalid('character not valid for $formatName');
    }
  }
  return const BarcodeValidation.ok();
}

/// Maps a card's format string to the mobile_scanner format used to
/// recognize it via the camera.
scanner.BarcodeFormat toScannerFormat(String format) {
  return switch (format) {
    CardBarcodeFormat.ean13 => scanner.BarcodeFormat.ean13,
    CardBarcodeFormat.ean8 => scanner.BarcodeFormat.ean8,
    CardBarcodeFormat.upcA => scanner.BarcodeFormat.upcA,
    CardBarcodeFormat.upcE => scanner.BarcodeFormat.upcE,
    CardBarcodeFormat.code128 => scanner.BarcodeFormat.code128,
    CardBarcodeFormat.code39 => scanner.BarcodeFormat.code39,
    CardBarcodeFormat.code93 => scanner.BarcodeFormat.code93,
    CardBarcodeFormat.itf => scanner.BarcodeFormat.itf14,
    CardBarcodeFormat.codabar => scanner.BarcodeFormat.codabar,
    CardBarcodeFormat.qr => scanner.BarcodeFormat.qrCode,
    CardBarcodeFormat.pdf417 => scanner.BarcodeFormat.pdf417,
    CardBarcodeFormat.aztec => scanner.BarcodeFormat.aztec,
    CardBarcodeFormat.dataMatrix => scanner.BarcodeFormat.dataMatrix,
    _ => scanner.BarcodeFormat.unknown,
  };
}

/// The reverse of [toScannerFormat], used to fill in a card's format field
/// from what the camera recognized.
String? fromScannerFormat(scanner.BarcodeFormat format) {
  return switch (format) {
    scanner.BarcodeFormat.ean13 => CardBarcodeFormat.ean13,
    scanner.BarcodeFormat.ean8 => CardBarcodeFormat.ean8,
    scanner.BarcodeFormat.upcA => CardBarcodeFormat.upcA,
    scanner.BarcodeFormat.upcE => CardBarcodeFormat.upcE,
    scanner.BarcodeFormat.code128 => CardBarcodeFormat.code128,
    scanner.BarcodeFormat.code39 => CardBarcodeFormat.code39,
    scanner.BarcodeFormat.code93 => CardBarcodeFormat.code93,
    scanner.BarcodeFormat.itf14 => CardBarcodeFormat.itf,
    scanner.BarcodeFormat.codabar => CardBarcodeFormat.codabar,
    scanner.BarcodeFormat.qrCode => CardBarcodeFormat.qr,
    scanner.BarcodeFormat.pdf417 => CardBarcodeFormat.pdf417,
    scanner.BarcodeFormat.aztec => CardBarcodeFormat.aztec,
    scanner.BarcodeFormat.dataMatrix => CardBarcodeFormat.dataMatrix,
    _ => null,
  };
}

/// Maps a card's format string to the barcode_widget renderer used to
/// display it full-screen.
bw.Barcode toRenderBarcode(String format) {
  return switch (format) {
    CardBarcodeFormat.ean13 => bw.Barcode.ean13(),
    CardBarcodeFormat.ean8 => bw.Barcode.ean8(),
    CardBarcodeFormat.upcA => bw.Barcode.upcA(),
    CardBarcodeFormat.upcE => bw.Barcode.upcE(),
    CardBarcodeFormat.code128 => bw.Barcode.code128(),
    CardBarcodeFormat.code39 => bw.Barcode.code39(),
    CardBarcodeFormat.code93 => bw.Barcode.code93(),
    CardBarcodeFormat.itf => bw.Barcode.itf(),
    CardBarcodeFormat.codabar => bw.Barcode.codabar(),
    CardBarcodeFormat.qr => bw.Barcode.qrCode(),
    CardBarcodeFormat.pdf417 => bw.Barcode.pdf417(),
    CardBarcodeFormat.aztec => bw.Barcode.aztec(),
    CardBarcodeFormat.dataMatrix => bw.Barcode.dataMatrix(),
    _ => bw.Barcode.code128(),
  };
}

/// Whether a format renders as a 1D barcode (needs the number printed
/// below it) vs. a 2D symbol.
bool isOneDimensional(String format) => const {
  CardBarcodeFormat.ean13,
  CardBarcodeFormat.ean8,
  CardBarcodeFormat.upcA,
  CardBarcodeFormat.upcE,
  CardBarcodeFormat.code128,
  CardBarcodeFormat.code39,
  CardBarcodeFormat.code93,
  CardBarcodeFormat.itf,
  CardBarcodeFormat.codabar,
}.contains(format);
