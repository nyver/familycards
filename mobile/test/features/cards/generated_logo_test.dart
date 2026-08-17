import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/cards/generated_logo.dart';

void main() {
  group('initialsFor', () {
    test('takes the first letter of the first two words', () {
      expect(initialsFor('Corner Shop'), 'CS');
      expect(initialsFor('  Mister   Twister '), 'MT');
    });

    test('takes the first two letters of a single word', () {
      expect(initialsFor('Costco'), 'CO');
    });

    test('handles a single-letter word', () {
      expect(initialsFor('X'), 'X');
    });

    test('handles non-Latin names', () {
      expect(initialsFor('Пятёрочка'), 'ПЯ');
    });

    test('does not split an emoji into a broken surrogate half', () {
      // A naive UTF-16 code-unit substring(0, 2) on a name starting with an
      // emoji (a surrogate pair) would cut it in half. Grapheme-aware
      // truncation keeps it whole.
      expect(initialsFor('🎉 Party Store'), '🎉P');
    });
  });

  testWidgets('GeneratedLogo renders the monogram text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(
          child: GeneratedLogo(storeName: 'Corner Shop', foreground: Colors.black),
        ),
      ),
    );

    expect(find.text('CS'), findsOneWidget);
  });
}
