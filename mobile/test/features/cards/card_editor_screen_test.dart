import 'package:drift/native.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/barcode/barcode_formats.dart';
import 'package:mobile/core/crypto/canonical_json.dart';
import 'package:mobile/core/db/database.dart';
import 'package:mobile/core/providers.dart';
import 'package:mobile/features/cards/card_editor_screen.dart';
import 'package:mobile/features/cards/card_repository.dart';
import 'package:mobile/features/cards/generated_logo.dart';
import 'package:mobile/l10n/app_localizations.dart';

// This exercises the live logo preview added to the editor: it must always
// match what card_list_screen.dart's _CardTile would show for the same
// card (see cardForeground and _LogoPreview in card_editor_screen.dart), and
// must recompute immediately on a color change or a store-name edit,
// without saving.
void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  Future<Card> createCard({
    required String storeName,
    required int color,
    String? logoAsset,
  }) async {
    final repo = CardRepository(database.cardsDao);
    final id = await repo.createCard(
      CardPayload(
        barcodeFormat: CardBarcodeFormat.ean13,
        cardNumber: '4006381333931',
        color: color,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        storeName: storeName,
        logoAsset: logoAsset,
      ),
    );
    // A one-shot fetch, not dao.watchVisibleCards().first: leaving a
    // reactive drift stream query registered (even one immediately
    // resolved via .first) before pumping the widget tree hangs
    // WidgetTester.pumpWidget indefinitely in this test environment.
    return (await repo.getCard(id))!;
  }

  Future<void> pumpEditor(WidgetTester tester, Card existing) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CardEditorScreen(existing: existing),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows a generated monogram matching the card list tile', (
    tester,
  ) async {
    final card = await createCard(storeName: 'Corner Shop', color: 0xFF3949AB);
    await pumpEditor(tester, card);

    expect(find.byType(GeneratedLogo), findsOneWidget);
    expect(find.text('CS'), findsOneWidget);

    final logo = tester.widget<GeneratedLogo>(find.byType(GeneratedLogo));
    expect(
      logo.foreground,
      cardForeground(const Color(0xFF3949AB)),
      reason: 'the preview must use the same contrast function as the tile',
    );

    await database.close();
  });

  testWidgets('recomputes the monogram immediately after editing the store name', (
    tester,
  ) async {
    final card = await createCard(storeName: 'Corner Shop', color: 0xFF3949AB);
    await pumpEditor(tester, card);

    expect(find.text('CS'), findsOneWidget);

    // The store-name field is the first TextField in the editor's ListView
    // (see card_editor_screen.dart's build order).
    await tester.enterText(find.byType(TextField).first, 'Great Market');
    await tester.pump();

    expect(find.text('CS'), findsNothing);
    expect(find.text('GM'), findsOneWidget);

    await database.close();
  });

  testWidgets('redraws the preview on the new color as soon as it is picked', (
    tester,
  ) async {
    final card = await createCard(storeName: 'Corner Shop', color: 0xFF3949AB);
    await pumpEditor(tester, card);

    final before = tester.widget<GeneratedLogo>(find.byType(GeneratedLogo));
    expect(before.foreground, cardForeground(const Color(0xFF3949AB)));

    // Pick the light yellow palette swatch - a color on the other side of
    // the contrast threshold from the card's initial color. It sits below
    // the fold in the editor's ListView (built, since it's within
    // ListView's cache extent, but not laid out on screen), so invoke its
    // GestureDetector directly rather than a coordinate-based tap, which
    // would either miss it or scroll the logo preview out of the tree.
    const yellow = Color(0xFFFDD835);
    final swatch = find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).color == yellow,
    );
    final gestureDetector = tester.widget<GestureDetector>(
      find.ancestor(of: swatch, matching: find.byType(GestureDetector)),
    );
    gestureDetector.onTap!();
    await tester.pump();

    final after = tester.widget<GeneratedLogo>(find.byType(GeneratedLogo));
    expect(after.foreground, cardForeground(yellow));
    expect(after.foreground, isNot(before.foreground));

    await database.close();
  });

  testWidgets('shows the catalog logo instead of a monogram when one is set', (
    tester,
  ) async {
    final card = await createCard(
      storeName: 'Pyaterochka',
      color: 0xFF008C44,
      logoAsset: 'assets/stores/logos/pyaterochka.webp',
    );
    await pumpEditor(tester, card);

    expect(find.byType(GeneratedLogo), findsNothing);
    expect(find.byType(Image), findsOneWidget);

    await database.close();
  });

  testWidgets(
    'the remove-logo button detaches a catalog logo and falls back to the '
    "monogram, tracking the card's own color again",
    (tester) async {
      final card = await createCard(
        storeName: 'Pyaterochka',
        color: 0xFF008C44,
        logoAsset: 'assets/stores/logos/pyaterochka.webp',
      );
      await pumpEditor(tester, card);

      final l10n = lookupAppLocalizations(const Locale('en'));
      final removeButton = find.widgetWithText(
        TextButton,
        l10n.cardEditorRemoveLogoButton,
      );
      expect(
        removeButton,
        findsOneWidget,
        reason: 'the button must be offered whenever a catalog logo is set',
      );

      await tester.tap(removeButton);
      await tester.pump();

      expect(find.byType(Image), findsNothing);
      expect(find.byType(GeneratedLogo), findsOneWidget);
      final logo = tester.widget<GeneratedLogo>(find.byType(GeneratedLogo));
      expect(logo.foreground, cardForeground(const Color(0xFF008C44)));
      expect(
        find.widgetWithText(TextButton, l10n.cardEditorRemoveLogoButton),
        findsNothing,
        reason: 'nothing left to remove once the logo is already cleared',
      );

      await database.close();
    },
  );

  testWidgets(
    'no remove-logo button is offered for a generated monogram',
    (tester) async {
      final card = await createCard(
        storeName: 'Corner Shop',
        color: 0xFF3949AB,
      );
      await pumpEditor(tester, card);

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(
        find.widgetWithText(TextButton, l10n.cardEditorRemoveLogoButton),
        findsNothing,
      );

      await database.close();
    },
  );
}
