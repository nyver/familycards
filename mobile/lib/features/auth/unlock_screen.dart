import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'auth_providers.dart';
import 'identity_store.dart';

/// Shown when a local identity exists but the vault key is not in memory
/// (cold start, or the background lock timeout elapsed). Biometric unlock
/// (when enabled) is wired up in features/settings; this screen always
/// offers the password fallback.
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

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
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
            ],
          ),
        ),
      ),
    );
  }
}
