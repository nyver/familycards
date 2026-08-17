import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'create_vault_screen.dart';
import 'join_screen.dart';
import 'login_screen.dart';

/// Stateless choice between the three onboarding paths: create a vault,
/// join an existing one by invite code, or log in to an existing account
/// on this server - see client/vault-onboarding spec, "Стартовый выбор
/// сценария".
class StartScreen extends StatelessWidget {
  final String serverAddress;
  const StartScreen({super.key, required this.serverAddress});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.onboardingWelcomeTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreateVaultScreen()),
                ),
                child: Text(l10n.startCreateVault),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const JoinScreen())),
                child: Text(l10n.startJoinByCode),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
                child: Text(l10n.startLogin),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
