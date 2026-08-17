import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/device_info.dart';
import '../../core/result.dart';
import '../../l10n/app_localizations.dart';
import 'auth_providers.dart';
import 'recover_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _submitting = true;
      _error = null;
    });

    final device = currentDeviceIdentity();
    final result = await ref
        .read(sessionControllerProvider.notifier)
        .login(
          login: _loginController.text.trim(),
          password: _passwordController.text,
          deviceName: device.name,
          devicePlatform: device.platform,
        );

    if (!mounted) return;
    setState(() => _submitting = false);

    result.fold(
      (_) {
        // login() already transitioned the session to AuthReady; pop this
        // pushed screen (and everything under it back to AuthGate's own
        // route) so the now-updated card list becomes visible.
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
      (error) {
        setState(() {
          _error = switch (error.kind) {
            AppErrorKind.network => l10n.loginNoNetwork,
            AppErrorKind.conflict => l10n.loginDeviceLimitReached,
            _ => l10n.loginInvalidCredentials,
          };
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.startLogin)),
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
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l10n.passwordLabel,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _submit(),
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
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.startLogin),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RecoverScreen()),
                ),
                child: Text(l10n.loginForgotPassword),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
