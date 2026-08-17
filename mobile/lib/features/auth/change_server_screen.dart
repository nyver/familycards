import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'auth_providers.dart';

/// Lets the user switch to a different server. Since the local database,
/// identity, and vault key all belong to the *current* server's vault,
/// switching requires wiping all of them - the user must explicitly
/// confirm before that happens. See client/vault-onboarding spec, "Смена
/// сервера очищает локальное состояние".
class ChangeServerScreen extends ConsumerStatefulWidget {
  const ChangeServerScreen({super.key});

  @override
  ConsumerState<ChangeServerScreen> createState() => _ChangeServerScreenState();
}

class _ChangeServerScreenState extends ConsumerState<ChangeServerScreen> {
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _confirmAndSwitch() async {
    final l10n = AppLocalizations.of(context)!;
    final address = _controller.text.trim();
    if (address.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.changeServerWarningTitle),
        content: Text(l10n.changeServerWarningBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.changeServerConfirmButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    await ref
        .read(sessionControllerProvider.notifier)
        .changeServerAndWipeLocalData(address);
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.changeServerTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _controller,
                enabled: !_submitting,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: l10n.onboardingServerAddressLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _submitting ? null : _confirmAndSwitch,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.changeServerConfirmButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
