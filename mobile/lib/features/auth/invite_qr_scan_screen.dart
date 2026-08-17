import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../l10n/app_localizations.dart';

/// Full-screen QR scanner for an invite code, so a new member can join by
/// pointing the camera at the code shown on another device's invite
/// screen (see features/settings/invite_screen.dart) instead of typing
/// it. The QR encodes the invite code's plain text, nothing more - see
/// InviteScreen's `QrImageView(data: invite.code, ...)`. Restricted to
/// the QR format only (unlike features/cards/scanner_screen.dart, which
/// deliberately accepts any barcode format) since an invite code is never
/// a 1D barcode. Pops with the decoded text as soon as one QR code is
/// recognized.
class InviteQrScanScreen extends StatefulWidget {
  const InviteQrScanScreen({super.key});

  @override
  State<InviteQrScanScreen> createState() => _InviteQrScanScreenState();
}

class _InviteQrScanScreenState extends State<InviteQrScanScreen> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.isEmpty) continue;
      _handled = true;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(raw);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(l10n.inviteScanQrTitle),
        actions: [
          ValueListenableBuilder(
            valueListenable: _controller,
            builder: (context, state, child) {
              final torch = state.torchState;
              return IconButton(
                icon: Icon(
                  torch == TorchState.on ? Icons.flash_on : Icons.flash_off,
                ),
                onPressed: () => _controller.toggleTorch(),
              );
            },
          ),
        ],
      ),
      body: MobileScanner(
        controller: _controller,
        onDetect: _onDetect,
        overlayBuilder: (context, constraints) => const _ScanFrameOverlay(),
        errorBuilder: (context, error) =>
            _PermissionDeniedView(l10n: l10n, onRetry: _controller.start),
      ),
    );
  }
}

class _ScanFrameOverlay extends StatelessWidget {
  const _ScanFrameOverlay();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 3),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _PermissionDeniedView extends StatelessWidget {
  final AppLocalizations l10n;
  final VoidCallback onRetry;
  const _PermissionDeniedView({required this.l10n, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                color: Colors.white70,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.scannerPermissionDenied,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onRetry,
                child: Text(
                  l10n.scannerOpenSettings,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
