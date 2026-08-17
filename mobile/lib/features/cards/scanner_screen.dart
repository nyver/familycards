import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/barcode/barcode_formats.dart';
import '../../l10n/app_localizations.dart';

/// A scanned card number and its recognized barcode format, handed back
/// to the caller (typically the card editor) when the user pops this
/// screen after a successful scan.
class ScanResult {
  final String number;
  final String format;
  const ScanResult({required this.number, required this.format});
}

/// Full-screen barcode scanner: live camera preview, a framing overlay,
/// a flashlight toggle, and haptic feedback on the first successful
/// detection. Pops with a [ScanResult] as soon as one barcode is
/// recognized. If the camera permission is denied, shows an explanatory
/// message instead of a blank/frozen preview.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final _controller = MobileScannerController();
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
      final format =
          fromScannerFormat(barcode.format) ?? suggestBarcodeFormat(raw);
      _handled = true;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(ScanResult(number: raw, format: format));
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
        title: Text(l10n.scannerTitle),
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
        width: 260,
        height: 160,
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
