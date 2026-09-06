import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/net/certificate_fingerprint.dart';
import '../../l10n/app_localizations.dart';

/// A labeled, optional text field for manually entering a server
/// certificate's SHA-256 fingerprint - shown on both the server address
/// and change-server screens. Accepts case/separator variation (see
/// [tryParseSha256Fingerprint]); the caller validates on submit and
/// passes the result back as [errorText].
class CertificateFingerprintField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final String? errorText;

  const CertificateFingerprintField({
    super.key,
    required this.controller,
    this.enabled = true,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return TextField(
      controller: controller,
      enabled: enabled,
      style: const TextStyle(fontFamily: 'monospace'),
      decoration: InputDecoration(
        labelText: l10n.certificateFingerprintLabel,
        hintText: 'AA:BB:CC:DD:...',
        helperText: l10n.certificateFingerprintHelper,
        helperMaxLines: 3,
        border: const OutlineInputBorder(),
        errorText: errorText,
        errorMaxLines: 3,
      ),
    );
  }
}

/// Shows a modal requiring the user to explicitly confirm that
/// [certificate]'s SHA-256 fingerprint matches what they saw in the
/// server's own startup log, before it is pinned. Returns the raw
/// fingerprint bytes if confirmed, or null if the user backed out -
/// there is deliberately no "continue without checking" option: the
/// dialog cannot be dismissed except by choosing one of the two actions.
Future<Uint8List?> confirmCertificateFingerprint(
  BuildContext context,
  X509Certificate certificate,
) async {
  final l10n = AppLocalizations.of(context)!;
  final fingerprint = sha256OfCertificate(certificate);
  final formatted = formatFingerprint(fingerprint);
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(l10n.certificateConfirmTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.certificateConfirmBody),
            const SizedBox(height: 12),
            SelectableText(
              formatted,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.certificateConfirmButton),
          ),
        ],
      ),
    ),
  );
  return confirmed == true ? fingerprint : null;
}
