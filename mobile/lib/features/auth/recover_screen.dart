import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/crypto/recovery_phrase.dart';
import '../../core/device_info.dart';
import '../../l10n/app_localizations.dart';
import 'auth_providers.dart';
import 'create_vault_screen.dart'
    show minPasswordLength, evaluatePasswordStrength, PasswordStrength;

/// Recovers access using the 12-word recovery phrase shown once at vault
/// creation. The phrase is validated locally (dictionary + checksum)
/// before any network call - see client/vault-onboarding spec,
/// "Восстановление доступа по фразе".
class RecoverScreen extends ConsumerStatefulWidget {
  const RecoverScreen({super.key});

  @override
  ConsumerState<RecoverScreen> createState() => _RecoverScreenState();
}

class _RecoverScreenState extends ConsumerState<RecoverScreen> {
  final _loginController = TextEditingController();
  final _phraseController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _loginController.dispose();
    _phraseController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  List<String> get _phraseWords => _phraseController.text
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();

  bool get _canSubmit =>
      _loginController.text.trim().isNotEmpty &&
      _phraseWords.length == RecoveryPhrase.wordCount &&
      evaluatePasswordStrength(_newPasswordController.text) !=
          PasswordStrength.tooShort;

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final wordlistAsync = ref.read(bip39WordlistProvider);
    final wordlist = wordlistAsync.valueOrNull;
    if (wordlist == null) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    final device = currentDeviceIdentity();
    final result = await ref
        .read(sessionControllerProvider.notifier)
        .recoverByPhrase(
          login: _loginController.text.trim(),
          phraseWords: _phraseWords,
          newPassword: _newPasswordController.text,
          bip39Wordlist: wordlist,
          deviceName: device.name,
          devicePlatform: device.platform,
        );

    if (!mounted) return;
    setState(() => _submitting = false);

    result.fold(
      (_) {
        // recoverByPhrase() already transitioned the session to AuthReady;
        // pop this pushed screen (and everything under it back to
        // AuthGate's own route) so the now-updated card list becomes
        // visible.
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
      (error) {
        // Every failure mode here (bad phrase, unknown login, server
        // rejection) is presented uniformly, matching the login screen's
        // policy of not distinguishing "wrong secret" from "unknown
        // account".
        setState(() => _error = l10n.recoverInvalidPhrase);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.recoverTitle)),
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
                controller: _phraseController,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: l10n.recoveryPhraseInputLabel,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l10n.newPasswordLabel,
                  helperText: l10n.passwordTooShort(minPasswordLength),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: (_canSubmit && !_submitting) ? _submit : null,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.recoverSubmitButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
