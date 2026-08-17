import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/crypto/invite_code.dart';

void main() {
  test('generates an 8-character code using only the Crockford alphabet', () {
    final code = InviteCode.generate();
    expect(code.length, 8);
    for (final char in code.split('')) {
      expect(
        '0123456789ABCDEFGHJKMNPQRSTVWXYZ'.contains(char),
        isTrue,
        reason: 'unexpected char $char',
      );
    }
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

  test('format inserts a hyphen after the 4th character', () {
    expect(InviteCode.format('7K4M9QRT'), '7K4M-9QRT');
  });

  test('normalize strips hyphens and whitespace and uppercases', () {
    expect(InviteCode.normalize('7k4m-9qrt'), '7K4M9QRT');
    expect(InviteCode.normalize(' 7K4M 9QRT '), '7K4M9QRT');
  });

  test('normalize substitutes ambiguous characters like a real user typo would produce', () {
    // A user reading "0" might type "O", and reading "1" might type "I" or "L".
    expect(InviteCode.normalize('OI4M-L9RT'), '014M19RT');
  });

  test('normalize rejects input of the wrong length', () {
    expect(InviteCode.normalize('SHORT'), isNull);
    expect(InviteCode.normalize('WAYTOOLONGCODE'), isNull);
  });

  test(
    'normalize rejects characters outside the alphabet even after substitution',
    () {
      expect(InviteCode.normalize('!!!!!!!!'), isNull);
    },
  );

  test('a generated code round-trips through format and normalize', () {
    final code = InviteCode.generate();
    final formatted = InviteCode.format(code);
    final normalized = InviteCode.normalize(formatted);
    expect(normalized, code);
  });
}
