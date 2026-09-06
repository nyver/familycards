import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/net/certificate_fingerprint.dart';
import '../../core/result.dart';
import '../../l10n/app_localizations.dart';
import 'auth_providers.dart';
import 'certificate_pin_ui.dart';

/// First onboarding screen: the user enters the address of their
/// self-hosted server, which is verified via GET /v1/health before
/// proceeding - see client/vault-onboarding spec, "Выбор и проверка
/// адреса сервера". Also supports pinning the server's TLS certificate:
/// either by pasting a fingerprint copied from the server's startup log
/// up front, or via trust-on-first-use, confirming the fingerprint the
/// server actually presents when no pin is set yet and its certificate
/// isn't trusted by the system's CA store.
class ServerAddressScreen extends ConsumerStatefulWidget {
  const ServerAddressScreen({super.key});

  @override
  ConsumerState<ServerAddressScreen> createState() =>
      _ServerAddressScreenState();
}

class _ServerAddressScreenState extends ConsumerState<ServerAddressScreen> {
  final _controller = TextEditingController();
  final _fingerprintController = TextEditingController();
  bool _checking = false;
  String? _error;
  String? _fingerprintError;

  @override
  void dispose() {
    _controller.dispose();
    _fingerprintController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final address = _controller.text.trim();
    if (address.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;

    Uint8List? pin;
    final fingerprintText = _fingerprintController.text.trim();
    if (fingerprintText.isNotEmpty) {
      pin = tryParseSha256Fingerprint(fingerprintText);
      if (pin == null) {
        setState(() {
          _fingerprintError = l10n.certificateFingerprintInvalid;
        });
        return;
      }
    }

    setState(() {
      _checking = true;
      _error = null;
      _fingerprintError = null;
    });

    await _checkAndHandle(address, pin);
  }

  /// Runs the health check with [pin] applied and reacts to the result:
  /// on success, [SessionController] has already moved on to onboarding.
  /// On a certificate failure with no user-supplied pin, this triggers
  /// the trust-on-first-use confirmation flow and retries once confirmed
  /// - there is no way to proceed past a certificate warning without
  /// that explicit confirmation.
  Future<void> _checkAndHandle(String address, Uint8List? pin) async {
    final controller = ref.read(sessionControllerProvider.notifier);
    final result = await controller.checkAndSetServer(
      address,
      pinnedFingerprint: pin,
    );
    if (!mounted) return;

    final error = result.errorOrNull;
    if (error == null) {
      setState(() => _checking = false);
      return;
    }

    if (error.kind == AppErrorKind.certificateMismatch && pin == null) {
      final cert = await controller.probePresentedCertificate(address);
      if (!mounted) return;
      if (cert == null) {
        final l10n = AppLocalizations.of(context)!;
        setState(() {
          _checking = false;
          _error = l10n.onboardingServerUnreachable;
        });
        return;
      }
      final confirmedPin = await confirmCertificateFingerprint(context, cert);
      if (!mounted) return;
      if (confirmedPin == null) {
        setState(() => _checking = false);
        return;
      }
      _fingerprintController.text = formatFingerprint(confirmedPin);
      await _checkAndHandle(address, confirmedPin);
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _checking = false;
      if (error.kind == AppErrorKind.certificateMismatch) {
        _fingerprintError = l10n.certificateMismatchMessage;
      } else {
        _error = error.kind == AppErrorKind.network
            ? l10n.onboardingServerUnreachable
            : l10n.onboardingServerIncompatible;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
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
              CertificateFingerprintField(
                controller: _fingerprintController,
                enabled: !_checking,
                errorText: _fingerprintError,
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
