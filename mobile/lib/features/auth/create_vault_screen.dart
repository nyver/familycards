import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/device_info.dart';
import '../../l10n/app_localizations.dart';
import 'auth_providers.dart';
import 'recovery_phrase_display_screen.dart';

const minPasswordLength = 10;

/// Password strength buckets shown to the user while typing. This is a
/// coarse, purely local heuristic (length + character variety) - not a
/// substitute for the length requirement itself, which is enforced
/// separately.
enum PasswordStrength { tooShort, weak, medium, strong }

PasswordStrength evaluatePasswordStrength(String password) {
  if (password.length < minPasswordLength) return PasswordStrength.tooShort;
  var variety = 0;
  if (password.contains(RegExp(r'[a-z]'))) variety++;
  if (password.contains(RegExp(r'[A-Z]'))) variety++;
  if (password.contains(RegExp(r'[0-9]'))) variety++;
  if (password.contains(RegExp(r'[^a-zA-Z0-9]'))) variety++;
  if (password.length >= 16 && variety >= 3) return PasswordStrength.strong;
  if (password.length >= 12 && variety >= 2) return PasswordStrength.medium;
  return PasswordStrength.weak;
}

/// Step 1 of vault creation: collects the account details. The recovery
/// phrase is generated and shown next (RecoveryPhraseDisplayScreen); the
/// account is only actually created on the server after the user confirms
/// they saved it - see client/vault-onboarding spec.
class CreateVaultScreen extends ConsumerStatefulWidget {
  const CreateVaultScreen({super.key});

  @override
  ConsumerState<CreateVaultScreen> createState() => _CreateVaultScreenState();
}

class _CreateVaultScreenState extends ConsumerState<CreateVaultScreen> {
  final _loginController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _bootstrapTokenController = TextEditingController();
  bool _preparing = false;

  @override
  void dispose() {
    _loginController.dispose();
    _displayNameController.dispose();
    _passwordController.dispose();
    _bootstrapTokenController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _loginController.text.trim().isNotEmpty &&
      _displayNameController.text.trim().isNotEmpty &&
      _bootstrapTokenController.text.trim().isNotEmpty &&
      evaluatePasswordStrength(_passwordController.text) !=
          PasswordStrength.tooShort;

  Future<void> _continue() async {
    final wordlistAsync = ref.read(bip39WordlistProvider);
    final wordlist = wordlistAsync.valueOrNull;
    if (wordlist == null) return;

    setState(() => _preparing = true);
    final pending = await ref
        .read(sessionControllerProvider.notifier)
        .prepareNewVault(wordlist);
    if (!mounted) return;
    setState(() => _preparing = false);

    final device = currentDeviceIdentity();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecoveryPhraseDisplayScreen(
          pending: pending,
          login: _loginController.text.trim(),
          displayName: _displayNameController.text.trim(),
          password: _passwordController.text,
          bootstrapToken: _bootstrapTokenController.text.trim(),
          deviceName: device.name,
          devicePlatform: device.platform,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final wordlistAsync = ref.watch(bip39WordlistProvider);
    final strength = evaluatePasswordStrength(_passwordController.text);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.createVaultTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _loginController,
                decoration: InputDecoration(
                  labelText: l10n.loginLabel,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _displayNameController,
                decoration: InputDecoration(
                  labelText: l10n.displayNameLabel,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l10n.passwordLabel,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              _PasswordStrengthBar(strength: strength),
              const SizedBox(height: 4),
              Text(
                strength == PasswordStrength.tooShort
                    ? l10n.passwordTooShort(minPasswordLength)
                    : l10n.passwordStrengthLabel(strength.name),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bootstrapTokenController,
                decoration: InputDecoration(
                  labelText: l10n.bootstrapTokenLabel,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: (_canSubmit && !_preparing && wordlistAsync.hasValue)
                    ? _continue
                    : null,
                child: _preparing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.commonContinue),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordStrengthBar extends StatelessWidget {
  final PasswordStrength strength;
  const _PasswordStrengthBar({required this.strength});

  @override
  Widget build(BuildContext context) {
    final value = switch (strength) {
      PasswordStrength.tooShort => 0.15,
      PasswordStrength.weak => 0.4,
      PasswordStrength.medium => 0.7,
      PasswordStrength.strong => 1.0,
    };
    final color = switch (strength) {
      PasswordStrength.tooShort => Colors.red,
      PasswordStrength.weak => Colors.orange,
      PasswordStrength.medium => Colors.yellow.shade800,
      PasswordStrength.strong => Colors.green,
    };
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(value: value, color: color, minHeight: 6),
    );
  }
}
