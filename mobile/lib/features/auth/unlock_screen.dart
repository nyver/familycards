import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import 'auth_providers.dart';
import 'identity_store.dart';

/// Shown when a local identity exists but the vault key is not in memory
/// (cold start, or the background lock timeout elapsed). Offers biometric
/// unlock when it is both enabled (see features/settings/security_screen)
/// and currently available on the device; always offers the password
/// fallback, per "приложение SHALL предоставлять парольный запасной путь".
class UnlockScreen extends ConsumerStatefulWidget {
  final StoredIdentity identity;
  const UnlockScreen({super.key, required this.identity});

  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen> {
  final _passwordController = TextEditingController();
  bool _submitting = false;
  String? _error;
  bool? _biometricsOffered;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final enabled = await ref
        .read(securitySettingsStoreProvider)
        .isBiometricEnabled();
    if (!enabled) {
      if (mounted) setState(() => _biometricsOffered = false);
      return;
    }
    final available = await ref
        .read(biometricAuthenticatorProvider)
        .isAvailable();
    if (mounted) setState(() => _biometricsOffered = available);
    if (available) await _unlockWithBiometrics();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _unlockWithBiometrics() async {
    final l10n = AppLocalizations.of(context)!;
    final authenticated = await ref
        .read(biometricAuthenticatorProvider)
        .authenticate(l10n.unlockGreeting(widget.identity.displayName));
    if (!authenticated || !mounted) return;

    final result = await ref
        .read(sessionControllerProvider.notifier)
        .unlockWithBiometrics();
    if (!mounted) return;
    result.fold((_) {}, (_) {
      // Fall through to the password field silently - the persisted key
      // may have been cleared elsewhere; no need to alarm the user.
    });
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    final result = await ref
        .read(sessionControllerProvider.notifier)
        .unlockWithPassword(_passwordController.text);

    if (!mounted) return;
    setState(() => _submitting = false);

    result.fold((_) {}, (error) {
      final l10n = AppLocalizations.of(context)!;
      setState(() => _error = l10n.unlockIncorrectPassword);
      _passwordController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.unlockGreeting(widget.identity.displayName),
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _passwordController,
                obscureText: true,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l10n.passwordLabel,
                  border: const OutlineInputBorder(),
                  errorText: _error,
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.unlockButton),
              ),
              if (_biometricsOffered == true) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _submitting ? null : _unlockWithBiometrics,
                  icon: const Icon(Icons.fingerprint),
                  label: Text(l10n.unlockBiometricButton),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
