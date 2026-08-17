import 'dart:math';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'recovery_phrase_confirm_screen.dart';
import 'session_controller.dart';

/// Shows the 12-word recovery phrase exactly once, with an explicit
/// warning that it cannot be viewed again, before proceeding to
/// confirmation. Nothing has been sent to the server yet at this point -
/// see client/vault-onboarding spec, "Показ и подтверждение кода
/// восстановления".
class RecoveryPhraseDisplayScreen extends StatelessWidget {
  final PendingVault pending;
  final String login;
  final String displayName;
  final String password;
  final String bootstrapToken;
  final String deviceName;
  final String devicePlatform;

  const RecoveryPhraseDisplayScreen({
    super.key,
    required this.pending,
    required this.login,
    required this.displayName,
    required this.password,
    required this.bootstrapToken,
    required this.deviceName,
    required this.devicePlatform,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.recoveryPhraseTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.recoveryPhraseWarning,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 4,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: pending.phraseWords.length,
                  itemBuilder: (context, i) => Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${i + 1}. ${pending.phraseWords[i]}'),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  final positions = _pickThreePositions(
                    pending.phraseWords.length,
                  );
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RecoveryPhraseConfirmScreen(
                        pending: pending,
                        positionsToConfirm: positions,
                        login: login,
                        displayName: displayName,
                        password: password,
                        bootstrapToken: bootstrapToken,
                        deviceName: deviceName,
                        devicePlatform: devicePlatform,
                      ),
                    ),
                  );
                },
                child: Text(l10n.recoveryPhraseSavedButton),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static List<int> _pickThreePositions(int wordCount) {
    final indices = List.generate(wordCount, (i) => i)
      ..shuffle(Random.secure());
    return (indices.take(3).toList()..sort());
  }
}
