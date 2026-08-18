import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/barcode/barcode_formats.dart';
import 'package:mobile/core/crypto/canonical_json.dart';
import 'package:mobile/core/db/database.dart';
import 'package:mobile/core/providers.dart';
import 'package:mobile/features/cards/card_detail_screen.dart';
import 'package:mobile/features/cards/card_repository.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:screen_brightness_platform_interface/screen_brightness_platform_interface.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

/// Records every brightness change requested by the app so the test can
/// assert on raise-on-open / restore-on-background behavior without a real
/// platform brightness channel.
class _FakeScreenBrightnessPlatform extends ScreenBrightnessPlatform {
  final List<double> applied = [];
  int resetCalls = 0;

  @override
  Future<void> setApplicationScreenBrightness(double brightness) async {
    applied.add(brightness);
  }

  @override
  Future<void> resetApplicationScreenBrightness() async {
    resetCalls++;
  }
}

class _FakeWakelockPlatform extends WakelockPlusPlatformInterface {
  bool isEnabled = false;

  @override
  Future<void> toggle({required bool enable}) async {
    isEnabled = enable;
  }

  @override
  Future<bool> get enabled async => isEnabled;
}

void main() {
  late _FakeScreenBrightnessPlatform fakeBrightness;
  late _FakeWakelockPlatform fakeWakelock;
  late AppDatabase database;
  late String cardId;

  setUp(() async {
    fakeBrightness = _FakeScreenBrightnessPlatform();
    ScreenBrightnessPlatform.instance = fakeBrightness;
    fakeWakelock = _FakeWakelockPlatform();
    wakelockPlusPlatformInstance = fakeWakelock;

    database = AppDatabase.forTesting(NativeDatabase.memory());
    final now = DateTime.now().millisecondsSinceEpoch;
    cardId = await CardRepository(database.cardsDao).createCard(
      CardPayload(
        barcodeFormat: CardBarcodeFormat.ean13,
        cardNumber: '4006381333931',
        color: 0xFF3949AB,
        createdAt: now,
        storeName: 'Test Store',
      ),
    );
  });

  Future<void> pumpDetailScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CardDetailScreen(cardId: cardId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Drift keeps a short-lived Timer alive per stream subscription after its
  // listener is cancelled, to dedupe rapid re-subscriptions (see drift's
  // stream_queries.dart - "Drift uses timers internally so that after you
  // stopped listening to a stream, it can keep its cache just a bit
  // longer"). flutter_test's testWidgets fails the test if any Timer is
  // still pending once the test body returns, and that check runs before
  // package:test's own tearDown/addTearDown callbacks fire - so the
  // database must be closed as the last statement of each test body
  // instead.

  testWidgets(
    'raises screen brightness and enables the wakelock while visible',
    (tester) async {
      await pumpDetailScreen(tester);

      expect(fakeBrightness.applied, contains(1.0));
      expect(fakeWakelock.isEnabled, isTrue);

      await database.close();
    },
  );

  testWidgets(
    'restores brightness when the app is backgrounded, and re-raises on resume',
    (tester) async {
      await pumpDetailScreen(tester);
      expect(fakeBrightness.resetCalls, 0);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(fakeBrightness.resetCalls, 1);

      final appliedBeforeResume = fakeBrightness.applied.length;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(fakeBrightness.applied.length, greaterThan(appliedBeforeResume));

      await database.close();
    },
  );

  testWidgets('restores brightness and disables the wakelock on exit', (
    tester,
  ) async {
    await pumpDetailScreen(tester);

    // Pop the detail screen by rebuilding the tree without it - this
    // disposes the State, which is where cleanup happens.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    expect(fakeBrightness.resetCalls, greaterThanOrEqualTo(1));
    expect(fakeWakelock.isEnabled, isFalse);

    await database.close();
  });

  testWidgets(
    'toggling favorite on the viewed card does not swap in a different '
    "card's data",
    (tester) async {
      final repo = CardRepository(database.cardsDao);
      final now = DateTime.now().millisecondsSinceEpoch;
      final xId = await repo.createCard(
        CardPayload(
          barcodeFormat: CardBarcodeFormat.code128,
          cardNumber: '111111',
          color: 0xFF3949AB,
          createdAt: now,
          storeName: 'Store X',
        ),
      );
      await repo.createCard(
        CardPayload(
          barcodeFormat: CardBarcodeFormat.code128,
          cardNumber: '222222',
          color: 0xFF3949AB,
          createdAt: now + 1,
          storeName: 'Store Y',
        ),
      );
      final zId = await repo.createCard(
        CardPayload(
          barcodeFormat: CardBarcodeFormat.code128,
          cardNumber: '333333',
          color: 0xFF3949AB,
          createdAt: now + 2,
          storeName: 'Store Z',
        ),
      );
      // X starts favorite, so the visible order is [X, Y, Z] and Z (not
      // yet favorite) sits at page index 2.
      await repo.toggleFavorite(xId, true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(database)],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: CardDetailScreen(cardId: zId),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Store Z'), findsOneWidget);
      expect(find.text('3333 33'), findsOneWidget);

      // Favoriting Z moves it ahead of Y in the sort order (favorites
      // first) - a real reorder of the card the user is actively viewing.
      await tester.tap(find.byIcon(Icons.star_border));
      await tester.pumpAndSettle();

      // Regression: before the fix, the PageView's scroll position stayed
      // fixed at index 2 while the list reordered underneath it, so index
      // 2 now pointed at Y - the screen silently showed Y's card number
      // under Z's own (correctly updated) AppBar title.
      expect(find.text('Store Z'), findsOneWidget);
      expect(find.text('3333 33'), findsOneWidget);
      expect(find.text('Store Y'), findsNothing);
      expect(find.text('2222 22'), findsNothing);

      await database.close();
    },
  );
}
