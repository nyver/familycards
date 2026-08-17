import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/barcode/barcode_formats.dart';
import 'package:mobile_scanner/mobile_scanner.dart' as scanner;

/// Independent reference implementation of the GTIN (EAN/UPC family)
/// mod-10 check digit, written in a different style/loop direction than
/// the implementation under test, so agreement between the two is a real
/// cross-check rather than the same logic checking itself.
String _referenceCheckDigit(String body) {
  var sum = 0;
  final digits = body.split('').map(int.parse).toList();
  final n = digits.length;
  for (var i = 0; i < n; i++) {
    // 1 = rightmost body digit (immediately left of the check digit).
    final positionFromRightWithinBody = n - i;
    final weight = positionFromRightWithinBody.isOdd ? 3 : 1;
    sum += digits[i] * weight;
  }
  return ((10 - (sum % 10)) % 10).toString();
}

void main() {
  group('EAN-13', () {
    test('accepts numbers whose checksum matches the independent reference implementation', () {
      for (final body in [
        '400638133393',
        '000000000000',
        '999999999999',
        '123456789012',
      ]) {
        final number = body + _referenceCheckDigit(body);
        final result = validateBarcodeNumber(CardBarcodeFormat.ean13, number);
        expect(
          result.valid,
          isTrue,
          reason: '$number should validate (body=$body)',
        );
      }
    });

    test('rejects a number with a corrupted checksum digit', () {
      final body = '400638133393';
      final correctCheck = int.parse(_referenceCheckDigit(body));
      final wrongCheck = (correctCheck + 1) % 10;
      final result = validateBarcodeNumber(
        CardBarcodeFormat.ean13,
        '$body$wrongCheck',
      );
      expect(result.valid, isFalse);
    });

    test('rejects the wrong length', () {
      expect(
        validateBarcodeNumber(CardBarcodeFormat.ean13, '123').valid,
        isFalse,
      );
    });

    test('rejects non-digit characters', () {
      expect(
        validateBarcodeNumber(CardBarcodeFormat.ean13, '40063813339X').valid,
        isFalse,
      );
    });
  });

  group('EAN-8', () {
    test('accepts a checksum-valid 8-digit number', () {
      const body = '4017072';
      final number = body + _referenceCheckDigit(body);
      expect(
        validateBarcodeNumber(CardBarcodeFormat.ean8, number).valid,
        isTrue,
      );
    });

    test('rejects a bad checksum', () {
      expect(
        validateBarcodeNumber(CardBarcodeFormat.ean8, '40170721').valid,
        isFalse,
      );
    });
  });

  group('UPC-A', () {
    test('accepts a checksum-valid 12-digit number', () {
      const body = '03600029145';
      final number = body + _referenceCheckDigit(body);
      expect(
        validateBarcodeNumber(CardBarcodeFormat.upcA, number).valid,
        isTrue,
      );
    });

    test('rejects a bad checksum', () {
      expect(
        validateBarcodeNumber(CardBarcodeFormat.upcA, '036000291451').valid,
        isFalse,
      );
    });
  });

  group('UPC-E', () {
    test('accepts a code that expands to a checksum-valid UPC-A', () {
      // Manually expand a known-good UPC-E: system digit 0, encoded
      // digits 55555 + trailing digit 6 (expansion rule: 5..9 => ns d1
      // d2 d3 d4 d5 0000 d6), then compute the matching check digit.
      const ns = '0';
      const encoded = '555556'; // d1..d6, d6=6 falls in the 5-9 case
      final expandedBody = '$ns${encoded.substring(0, 5)}0000${encoded[5]}';
      final check = _referenceCheckDigit(expandedBody);
      final upce = '$ns$encoded$check';
      expect(validateBarcodeNumber(CardBarcodeFormat.upcE, upce).valid, isTrue);
    });

    test('rejects the wrong length', () {
      expect(
        validateBarcodeNumber(CardBarcodeFormat.upcE, '1234567').valid,
        isFalse,
      );
    });
  });

  group('ITF', () {
    test('accepts an even number of digits', () {
      expect(
        validateBarcodeNumber(CardBarcodeFormat.itf, '1234').valid,
        isTrue,
      );
      expect(
        validateBarcodeNumber(CardBarcodeFormat.itf, '123456').valid,
        isTrue,
      );
    });

    test('rejects an odd number of digits', () {
      expect(
        validateBarcodeNumber(CardBarcodeFormat.itf, '12345').valid,
        isFalse,
      );
    });

    test('rejects non-digit characters', () {
      expect(
        validateBarcodeNumber(CardBarcodeFormat.itf, '12A4').valid,
        isFalse,
      );
    });
  });

  group('Code 39', () {
    test('accepts the documented alphabet', () {
      expect(
        validateBarcodeNumber(CardBarcodeFormat.code39, 'ABC-123 .\$/+%').valid,
        isTrue,
      );
    });

    test('rejects lowercase-only characters outside the alphabet like *', () {
      expect(
        validateBarcodeNumber(CardBarcodeFormat.code39, 'ABC*123').valid,
        isFalse,
      );
    });
  });

  group('Codabar', () {
    test('accepts digits and the documented symbol set', () {
      expect(
        validateBarcodeNumber(CardBarcodeFormat.codabar, 'A1234-5678B').valid,
        isTrue,
      );
    });

    test('rejects characters outside the alphabet', () {
      expect(
        validateBarcodeNumber(CardBarcodeFormat.codabar, 'A123#456B').valid,
        isFalse,
      );
    });
  });

  group('Code 128 and free-text 2D formats', () {
    test('code128 accepts any ASCII text', () {
      expect(
        validateBarcodeNumber(
          CardBarcodeFormat.code128,
          'Any-ASCII_123!',
        ).valid,
        isTrue,
      );
    });

    test('code128 rejects non-ASCII characters', () {
      expect(
        validateBarcodeNumber(CardBarcodeFormat.code128, 'Пятёрочка').valid,
        isFalse,
      );
    });

    test('qr, pdf417, aztec, and datamatrix accept any non-empty text', () {
      for (final format in [
        CardBarcodeFormat.qr,
        CardBarcodeFormat.pdf417,
        CardBarcodeFormat.aztec,
        CardBarcodeFormat.dataMatrix,
      ]) {
        expect(
          validateBarcodeNumber(format, 'Любой текст, 123!').valid,
          isTrue,
          reason: format,
        );
        expect(
          validateBarcodeNumber(format, '').valid,
          isFalse,
          reason: format,
        );
      }
    });
  });

  group('format auto-detection', () {
    test('suggests ean13 for a 13-digit checksum-valid number', () {
      const body = '400638133393';
      final number = body + _referenceCheckDigit(body);
      expect(suggestBarcodeFormat(number), CardBarcodeFormat.ean13);
    });

    test('suggests code128 for anything else', () {
      expect(suggestBarcodeFormat('not-a-gtin'), CardBarcodeFormat.code128);
      expect(
        suggestBarcodeFormat('1234567890123'),
        CardBarcodeFormat.code128,
      ); // 13 digits, bad checksum
    });
  });

  group('scanner format mapping round-trips for every supported format', () {
    for (final format in CardBarcodeFormat.all) {
      test(format, () {
        final scannerFormat = toScannerFormat(format);
        expect(scannerFormat, isNot(scanner.BarcodeFormat.unknown));
        expect(fromScannerFormat(scannerFormat), format);
      });
    }
  });

  group('render barcode mapping covers every supported format', () {
    for (final format in CardBarcodeFormat.all) {
      test(format, () {
        // Must not throw for any supported format.
        expect(() => toRenderBarcode(format), returnsNormally);
      });
    }
  });
}
