import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/net/certificate_fingerprint.dart';

void main() {
  group('tryParseSha256Fingerprint', () {
    test('parses a plain lowercase hex string', () {
      final hex = List.generate(32, (i) => i).map(
        (b) => b.toRadixString(16).padLeft(2, '0'),
      ).join();
      final bytes = tryParseSha256Fingerprint(hex);
      expect(bytes, isNotNull);
      expect(bytes, hasLength(32));
      expect(bytes!.first, 0x00);
      expect(bytes.last, 0x1f);
    });

    test('accepts uppercase hex with colon separators', () {
      const formatted =
          'AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:'
          'AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99';
      final bytes = tryParseSha256Fingerprint(formatted);
      expect(bytes, isNotNull);
      expect(bytes, hasLength(32));
      expect(bytes![0], 0xAA);
      expect(bytes[1], 0xBB);
    });

    test('accepts space and dash separators, mixed case', () {
      final rawBytes = List.generate(32, (i) => (i * 7) % 256);
      final withColons = formatFingerprint(rawBytes);
      final withSpaces = withColons.replaceAll(':', ' ').toLowerCase();
      final withDashes = withColons.replaceAll(':', '-');

      expect(tryParseSha256Fingerprint(withSpaces), rawBytes);
      expect(tryParseSha256Fingerprint(withDashes), rawBytes);
    });

    test('rejects a value that is too short', () {
      expect(tryParseSha256Fingerprint('AA:BB:CC'), isNull);
    });

    test('rejects a value that is too long', () {
      final tooLong = '${formatFingerprint(List.filled(32, 0xAB))}:FF';
      expect(tryParseSha256Fingerprint(tooLong), isNull);
    });

    test('rejects non-hex characters', () {
      final invalid = formatFingerprint(
        List.filled(32, 0xAB),
      ).replaceFirst('AB', 'ZZ');
      expect(tryParseSha256Fingerprint(invalid), isNull);
    });

    test('rejects an empty string', () {
      expect(tryParseSha256Fingerprint(''), isNull);
    });
  });

  group('parseSha256Fingerprint', () {
    test('throws InvalidFingerprintFormatException for malformed input', () {
      expect(
        () => parseSha256Fingerprint('not a fingerprint'),
        throwsA(isA<InvalidFingerprintFormatException>()),
      );
    });

    test('returns the same bytes as the nullable variant on valid input', () {
      final raw = List.generate(32, (i) => i);
      final formatted = formatFingerprint(raw);
      expect(parseSha256Fingerprint(formatted), raw);
    });
  });

  group('formatFingerprint / tryParseSha256Fingerprint round trip', () {
    test('round-trips arbitrary 32-byte sequences', () {
      final raw = Uint8List.fromList(
        List.generate(32, (i) => (i * 31 + 7) % 256),
      );
      final formatted = formatFingerprint(raw);
      expect(formatted.split(':'), hasLength(32));
      expect(formatted, equals(formatted.toUpperCase()));
      final parsed = tryParseSha256Fingerprint(formatted);
      expect(parsed, raw);
    });
  });

  group('constantTimeBytesEqual', () {
    test('returns true for identical byte lists', () {
      expect(constantTimeBytesEqual([1, 2, 3], [1, 2, 3]), isTrue);
    });

    test('returns false for differing byte lists of the same length', () {
      expect(constantTimeBytesEqual([1, 2, 3], [1, 2, 4]), isFalse);
    });

    test('returns false for lists of different lengths', () {
      expect(constantTimeBytesEqual([1, 2, 3], [1, 2]), isFalse);
    });
  });
}
