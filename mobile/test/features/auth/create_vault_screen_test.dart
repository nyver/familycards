import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/db/database.dart';
import 'package:mobile/features/auth/auth_providers.dart';
import 'package:mobile/features/auth/create_vault_screen.dart';
import 'package:mobile/features/auth/session_controller.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../../test_helpers/in_memory_key_value_store.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

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
    'the continue button stays disabled until the password meets the length requirement',
    (tester) async {
      await tester.pumpWidget(wrap(const CreateVaultScreen()));
      await tester.pump();

      final continueButton = find.widgetWithText(FilledButton, 'Continue');
      expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);

      await tester.enterText(find.byType(TextField).at(0), 'alice');
      await tester.enterText(find.byType(TextField).at(1), 'Alice');
      await tester.enterText(
        find.byType(TextField).at(2),
        'short',
      ); // < 10 chars
      await tester.enterText(find.byType(TextField).at(3), 'a-bootstrap-token');
      await tester.pump();

      expect(
        tester.widget<FilledButton>(continueButton).onPressed,
        isNull,
        reason: 'a password under 10 characters must keep the button disabled',
      );

      await tester.enterText(
        find.byType(TextField).at(2),
        'a sufficiently long password',
      );
      await tester.pump();

      expect(
        tester.widget<FilledButton>(continueButton).onPressed,
        isNotNull,
        reason: 'once every field is valid the button should become enabled',
      );
    },
  );

  testWidgets(
    'the password strength indicator reflects length and character variety',
    (tester) async {
      expect(evaluatePasswordStrength('short'), PasswordStrength.tooShort);
      // 22 lowercase letters, no digits/uppercase/punctuation: only one
      // character class, below the medium threshold's variety>=2.
      expect(
        evaluatePasswordStrength('alllowercaseletterss'),
        PasswordStrength.weak,
      );
      expect(
        evaluatePasswordStrength('MixedCase12345'),
        PasswordStrength.medium,
      );
      expect(
        evaluatePasswordStrength('MixedCase12345!@#\$Long'),
        PasswordStrength.strong,
      );
    },
  );
}
