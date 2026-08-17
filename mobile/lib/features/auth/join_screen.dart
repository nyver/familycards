import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/device_info.dart';
import '../../core/result.dart';
import '../../l10n/app_localizations.dart';
import 'auth_providers.dart';
import 'create_vault_screen.dart'
    show minPasswordLength, evaluatePasswordStrength, PasswordStrength;
import 'invite_qr_scan_screen.dart';

class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({super.key});

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  final _codeController = TextEditingController();
  final _loginController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    _loginController.dispose();
    _displayNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _codeController.text.trim().isNotEmpty &&
      _loginController.text.trim().isNotEmpty &&
      _displayNameController.text.trim().isNotEmpty &&
      evaluatePasswordStrength(_passwordController.text) !=
          PasswordStrength.tooShort;

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _submitting = true;
      _error = null;
    });

    final device = currentDeviceIdentity();
    final result = await ref
        .read(sessionControllerProvider.notifier)
        .joinByInvite(
          rawCode: _codeController.text.trim(),
          login: _loginController.text.trim(),
          displayName: _displayNameController.text.trim(),
          password: _passwordController.text,
          deviceName: device.name,
          devicePlatform: device.platform,
        );

    if (!mounted) return;
    setState(() => _submitting = false);

    result.fold(
      (_) {
        // joinByInvite() already transitioned the session to AuthReady;
        // pop this pushed screen (and everything under it back to
        // AuthGate's own route) so the now-updated card list becomes
        // visible.
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
      (error) {
        setState(() {
          _error = switch (error.kind) {
            AppErrorKind.gone => l10n.joinInviteExpired,
            AppErrorKind.invalidRequest => l10n.joinInvalidCode,
            AppErrorKind.conflict => l10n.joinLoginTakenOrFull,
            AppErrorKind.crypto => l10n.joinInvalidCode,
            _ => error.message,
          };
        });
      },
    );
  }

  Future<void> _scanQr() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const InviteQrScanScreen()),
    );
    if (result == null) return;
    setState(() => _codeController.text = result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.startJoinByCode)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _codeController,
                      decoration: InputDecoration(
                        labelText: l10n.inviteCodeLabel,
                        border: const OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.characters,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    tooltip: l10n.inviteScanQrButton,
                    onPressed: _scanQr,
                  ),
                ],
              ),
              const SizedBox(height: 12),
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
                    : Text(l10n.startJoinByCode),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
