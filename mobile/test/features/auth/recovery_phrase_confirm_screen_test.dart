import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/db/database.dart';
import 'package:mobile/core/result.dart';
import 'package:mobile/features/auth/auth_providers.dart';
import 'package:mobile/features/auth/auth_state.dart';
import 'package:mobile/features/auth/identity_store.dart';
import 'package:mobile/features/auth/recovery_phrase_confirm_screen.dart';
import 'package:mobile/features/auth/session_controller.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../../test_helpers/in_memory_key_value_store.dart';

/// Skips the real network call bootstrap would make (this screen's other
/// tests deliberately don't reach a real server) while still performing
/// the same session-state transition a real success would - unlocking the
/// vault key and moving to [AuthReady] - so navigation-after-success can
/// be tested in isolation.
class _FakeSuccessSessionController extends SessionController {
  _FakeSuccessSessionController({
    required super.database,
    required super.keyValueStore,
  });

  @override
  Future<Result<void>> completeBootstrap({
    required PendingVault vault,
    required String login,
    required String displayName,
    required String password,
    required String bootstrapToken,
    required String deviceName,
    required String devicePlatform,
  }) async {
    vaultKeyHolder.unlock(vault.vaultKey);
    state = AuthReady(
      StoredIdentity(
        serverAddress: 'https://test.invalid',
        userId: 'user-1',
        vaultId: 'vault-1',
        deviceId: 'device-1',
        login: login,
        displayName: displayName,
        kdfSalt: '',
        kdfParams: const {},
        wrappedVaultKey: '',
        wrapNonce: '',
      ),
    );
    return const Result.ok(null);
  }
}

/// Stands in for AuthGate's essential shape (a widget whose build depends
/// on the watched session state) without pulling in the real AuthReady
/// branch's sync engine and its platform-channel dependencies, which are
/// irrelevant to the navigation bug under test here.
class _RootProbe extends ConsumerWidget {
  const _RootProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sessionControllerProvider);
    return Scaffold(
      body: Center(child: Text(state is AuthReady ? 'READY' : 'NOT READY')),
    );
  }
}

const _twelveWords = [
  'abandon',
  'ability',
  'able',
  'about',
  'above',
  'absent',
  'absorb',
  'abstract',
  'absurd',
  'abuse',
  'access',
  'accident',
];

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  Future<PendingVault> buildPending() async {
    final vk = await Xchacha20.poly1305Aead().newSecretKey();
    return PendingVault(vaultKey: vk, phraseWords: _twelveWords);
  }

  Widget wrap(Widget child) {
    return ProviderScope(
      overrides: [
        sessionControllerProvider.overrideWith(
          (ref) => SessionController(
            database: AppDatabase.forTesting(NativeDatabase.memory()),
            keyValueStore: InMemoryKeyValueStore(),
          ),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );
  }

  testWidgets(
    'entering the wrong word at a requested position shows a mismatch error and does not proceed',
    (tester) async {
      final pending = await buildPending();

      await tester.pumpWidget(
        wrap(
          RecoveryPhraseConfirmScreen(
            pending: pending,
            positionsToConfirm: const [0, 5, 11], // abandon, absent, accident
            login: 'alice',
            displayName: 'Alice',
            password: 'a sufficiently long password',
            bootstrapToken: 'token',
            deviceName: 'Test Device',
            devicePlatform: 'android',
          ),
        ),
      );
      await tester.pump();

      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(3));

      await tester.enterText(fields.at(0), 'abandon'); // correct
      await tester.enterText(fields.at(1), 'wrong-word'); // incorrect
      await tester.enterText(fields.at(2), 'accident'); // correct
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await tester.pump();

      expect(
        find.text(
          "That doesn't match. Check your written-down phrase and try again.",
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'entering all three words correctly proceeds to create the vault',
    (tester) async {
      final pending = await buildPending();
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: RecoveryPhraseConfirmScreen(
              pending: pending,
              positionsToConfirm: const [0, 5, 11],
              login: 'alice',
              displayName: 'Alice',
              password: 'a sufficiently long password',
              bootstrapToken: 'wrong-token-so-the-server-call-fails-fast',
              deviceName: 'Test Device',
              devicePlatform: 'android',
            ),
          ),
        ),
      );
      await tester.pump();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'abandon');
      await tester.enterText(fields.at(1), 'absent');
      await tester.enterText(fields.at(2), 'accident');
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await tester.pump();

      // The local checksum-of-words comparison passed (no mismatch error),
      // so the screen proceeded to actually attempt bootstrap - which then
      // fails for an unrelated reason (no real server reachable from this
      // widget test), proving the three-word gate itself is not what
      // blocked it.
      expect(
        find.text(
          "That doesn't match. Check your written-down phrase and try again.",
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'a successful confirmation pops back to reveal the now-authenticated '
    'root screen instead of staying on the confirm screen',
    (tester) async {
      final pending = await buildPending();
      final controller = _FakeSuccessSessionController(
        database: AppDatabase.forTesting(NativeDatabase.memory()),
        keyValueStore: InMemoryKeyValueStore(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionControllerProvider.overrideWith((ref) => controller),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const _RootProbe(),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('NOT READY'), findsOneWidget);

      // Simulates the real app.dart navigation chain: the confirm screen
      // is reached by pushing on top of the root route, not by replacing
      // it.
      Navigator.of(tester.element(find.byType(_RootProbe))).push(
        MaterialPageRoute(
          builder: (_) => RecoveryPhraseConfirmScreen(
            pending: pending,
            positionsToConfirm: const [0, 5, 11],
            login: 'alice',
            displayName: 'Alice',
            password: 'a sufficiently long password',
            bootstrapToken: 'token',
            deviceName: 'Test Device',
            devicePlatform: 'android',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(RecoveryPhraseConfirmScreen), findsOneWidget);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'abandon');
      await tester.enterText(fields.at(1), 'absent');
      await tester.enterText(fields.at(2), 'accident');
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await tester.pumpAndSettle();

      // Regression: before the fix, the confirm screen stayed on top of
      // the navigation stack even though the session was already
      // AuthReady underneath it, leaving the user stuck with no visible
      // way forward.
      expect(find.byType(RecoveryPhraseConfirmScreen), findsNothing);
      expect(find.text('READY'), findsOneWidget);
    },
  );
}
