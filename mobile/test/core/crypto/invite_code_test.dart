import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/crypto/invite_code.dart';

void main() {
  test('generates a 26-character code using only the Crockford alphabet', () {
    final code = InviteCode.generate();
    expect(code.length, 26);
    for (final char in code.split('')) {
      expect(
        '0123456789ABCDEFGHJKMNPQRSTVWXYZ'.contains(char),
        isTrue,
        reason: 'unexpected char $char',
      );
    }
  });

  test('carries at least 128 bits of entropy', () {
    // 5 bits/char (32-symbol alphabet) * 26 chars = 130 bits.
    const bitsPerChar = 5; // log2(32)
    expect(InviteCode.length * bitsPerChar, greaterThanOrEqualTo(128));
  });

  test('excludes the ambiguous letters I, L, O, U from generated codes', () {
    // Generate many codes; statistically this would almost certainly hit
    // one of the excluded letters if they were mistakenly included.
    for (var i = 0; i < 500; i++) {
      final code = InviteCode.generate();
      for (final excluded in ['I', 'L', 'O', 'U']) {
        expect(code.contains(excluded), isFalse);
      }
    }
  });

  test('format inserts a hyphen every 4 characters', () {
    expect(
      InviteCode.format('7K4M9QRTVXY2B4C6D8E9F2G4HJ'),
      '7K4M-9QRT-VXY2-B4C6-D8E9-F2G4-HJ',
    );
  });

  test('normalize strips hyphens and whitespace and uppercases', () {
    expect(
      InviteCode.normalize('7k4m-9qrt-vxy2-b4c6-d8e9-f2g4-hj'),
      '7K4M9QRTVXY2B4C6D8E9F2G4HJ',
    );
    expect(
      InviteCode.normalize(' 7K4M 9QRT VXY2 B4C6 D8E9 F2G4 HJ '),
      '7K4M9QRTVXY2B4C6D8E9F2G4HJ',
    );
  });

  test('normalize substitutes ambiguous characters like a real user typo would produce', () {
    // A user reading "0" might type "O", and reading "1" might type "I" or "L".
    expect(
      InviteCode.normalize('OI4M-9QRT-VXY2-B4C6-D8E9-F2G4-LJ'),
      '014M9QRTVXY2B4C6D8E9F2G41J',
    );
  });

  test('normalize rejects input of the wrong length', () {
    expect(InviteCode.normalize('SHORT'), isNull);
    expect(InviteCode.normalize('7K4M9QRTVXY2B4C6D8E9F2G4HJXX'), isNull);
  });

  test(
    'normalize rejects characters outside the alphabet even after substitution',
    () {
      expect(InviteCode.normalize('!' * 26), isNull);
    },
  );

  test('a generated code round-trips through format and normalize', () {
    final code = InviteCode.generate();
    final formatted = InviteCode.format(code);
    final normalized = InviteCode.normalize(formatted);
    expect(normalized, code);
  });
}
