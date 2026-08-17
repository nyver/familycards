import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app.dart';
import 'package:mobile/core/db/database.dart';
import 'package:mobile/features/auth/auth_providers.dart';
import 'package:mobile/features/auth/session_controller.dart';

import 'test_helpers/in_memory_key_value_store.dart';

/// These tests only exercise app-level chrome (title, theme), not the
/// auth flow itself, so the session controller is backed entirely by
/// in-memory fakes - a real platform secure storage / path_provider
/// channel is not available in a plain widget test.
List<Override> _fakeSessionOverrides() => [
  sessionControllerProvider.overrideWith(
    (ref) => SessionController(
      database: AppDatabase.forTesting(NativeDatabase.memory()),
      keyValueStore: InMemoryKeyValueStore(),
    ),
  ),
];

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  testWidgets('app launches and shows the localized title in English', (
    tester,
  ) async {
    tester.platformDispatcher.localesTestValue = [const Locale('en')];
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    await tester.pumpWidget(
      ProviderScope(
        overrides: _fakeSessionOverrides(),
        child: const FamilyCardWalletApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Family Card Wallet'), findsOneWidget);
  });

  testWidgets(
    'app shows the localized title in Russian when the system locale is Russian',
    (tester) async {
      tester.platformDispatcher.localesTestValue = [const Locale('ru')];
      addTearDown(tester.platformDispatcher.clearAllTestValues);

      await tester.pumpWidget(
        ProviderScope(
          overrides: _fakeSessionOverrides(),
          child: const FamilyCardWalletApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Семейный кошелёк карт'), findsOneWidget);
    },
  );

  testWidgets('resolves a dark theme when the system requests dark', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    await tester.pumpWidget(
      ProviderScope(
        overrides: _fakeSessionOverrides(),
        child: const FamilyCardWalletApp(),
      ),
    );
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final resolvedBrightness = app.darkTheme!.colorScheme.brightness;
    expect(resolvedBrightness, Brightness.dark);

    final context = tester.element(find.byType(Scaffold).first);
    expect(Theme.of(context).brightness, Brightness.dark);
  });

  testWidgets('resolves a light theme when the system requests light', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    await tester.pumpWidget(
      ProviderScope(
        overrides: _fakeSessionOverrides(),
        child: const FamilyCardWalletApp(),
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(Scaffold).first);
    expect(Theme.of(context).brightness, Brightness.light);
  });
}
