import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/net/certificate_fingerprint.dart';
import '../../core/result.dart';
import '../../l10n/app_localizations.dart';
import 'auth_providers.dart';
import 'certificate_pin_ui.dart';

/// Lets the user switch to a different server. Since the local database,
/// identity, and vault key all belong to the *current* server's vault,
/// switching requires wiping all of them - the user must explicitly
/// confirm before that happens. See client/vault-onboarding spec, "Смена
/// сервера очищает локальное состояние". The new address (and, if given,
/// its pinned certificate fingerprint) is verified via GET /v1/health
/// *before* anything is wiped, so a bad address or certificate never
/// costs the user their local data.
class ChangeServerScreen extends ConsumerStatefulWidget {
  const ChangeServerScreen({super.key});

  @override
  ConsumerState<ChangeServerScreen> createState() => _ChangeServerScreenState();
}

class _ChangeServerScreenState extends ConsumerState<ChangeServerScreen> {
  final _controller = TextEditingController();
  final _fingerprintController = TextEditingController();
  bool _submitting = false;
  String? _error;
  String? _fingerprintError;

  @override
  void dispose() {
    _controller.dispose();
    _fingerprintController.dispose();
    super.dispose();
  }

  Future<void> _confirmAndSwitch() async {
    final l10n = AppLocalizations.of(context)!;
    final address = _controller.text.trim();
    if (address.isEmpty) return;

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

    setState(() {
      _submitting = true;
      _error = null;
      _fingerprintError = null;
    });

    await _switchAndHandle(address, pin);
  }

  /// Verifies and, on success, wipes local data and switches to
  /// [address] with [pin] applied. On a certificate failure with no
  /// user-supplied pin, triggers the same trust-on-first-use
  /// confirmation flow as the initial server address screen - local data
  /// is never touched unless the switch fully succeeds.
  Future<void> _switchAndHandle(String address, Uint8List? pin) async {
    final controller = ref.read(sessionControllerProvider.notifier);
    final result = await controller.changeServerAndWipeLocalData(
      address,
      pinnedFingerprint: pin,
    );
    if (!mounted) return;

    final error = result.errorOrNull;
    if (error == null) {
      setState(() => _submitting = false);
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    if (error.kind == AppErrorKind.certificateMismatch && pin == null) {
      final cert = await controller.probePresentedCertificate(address);
      if (!mounted) return;
      if (cert == null) {
        final l10n = AppLocalizations.of(context)!;
        setState(() {
          _submitting = false;
          _error = l10n.onboardingServerUnreachable;
        });
        return;
      }
      final confirmedPin = await confirmCertificateFingerprint(context, cert);
      if (!mounted) return;
      if (confirmedPin == null) {
        setState(() => _submitting = false);
        return;
      }
      _fingerprintController.text = formatFingerprint(confirmedPin);
      await _switchAndHandle(address, confirmedPin);
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _submitting = false;
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
      appBar: AppBar(title: Text(l10n.changeServerTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
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
                  errorText: _error,
                ),
              ),
              const SizedBox(height: 16),
              CertificateFingerprintField(
                controller: _fingerprintController,
                enabled: !_submitting,
                errorText: _fingerprintError,
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
