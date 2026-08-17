import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/result.dart';
import '../../l10n/app_localizations.dart';
import 'auth_providers.dart';

/// First onboarding screen: the user enters the address of their
/// self-hosted server, which is verified via GET /v1/health before
/// proceeding - see client/vault-onboarding spec, "Выбор и проверка
/// адреса сервера".
class ServerAddressScreen extends ConsumerStatefulWidget {
  const ServerAddressScreen({super.key});

  @override
  ConsumerState<ServerAddressScreen> createState() =>
      _ServerAddressScreenState();
}

class _ServerAddressScreenState extends ConsumerState<ServerAddressScreen> {
  final _controller = TextEditingController();
  bool _checking = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final address = _controller.text.trim();
    if (address.isEmpty) return;

    setState(() {
      _checking = true;
      _error = null;
    });

    final result = await ref
        .read(sessionControllerProvider.notifier)
        .checkAndSetServer(address);

    if (!mounted) return;
    setState(() => _checking = false);

    result.fold((_) {}, (error) {
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _error = error.kind == AppErrorKind.network
            ? l10n.onboardingServerUnreachable
            : l10n.onboardingServerIncompatible;
      });
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
                l10n.onboardingWelcomeTitle,
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _controller,
                enabled: !_checking,
                autofillHints: const [AutofillHints.url],
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: l10n.onboardingServerAddressLabel,
                  hintText: 'wallet.example.com',
                  border: const OutlineInputBorder(),
                  errorText: _error,
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _checking ? null : _submit,
                child: _checking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.onboardingServerCheckButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
