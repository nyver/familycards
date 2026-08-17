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
}
