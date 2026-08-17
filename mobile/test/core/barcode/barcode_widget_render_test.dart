import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/barcode/barcode_formats.dart';

/// A real widget test (not just a unit-level "does the mapping function
/// throw" check) confirming every one of the 13 supported barcode formats
/// actually renders through the real [BarcodeWidget] without an error
/// widget appearing.
void main() {
  const sampleNumbers = {
    CardBarcodeFormat.ean13: '4006381333931',
    CardBarcodeFormat.ean8: '40170725',
    CardBarcodeFormat.upcA: '036000291452',
    CardBarcodeFormat.upcE: '05555567',
    CardBarcodeFormat.code128: 'ABC-12345',
    CardBarcodeFormat.code39: 'ABC-123',
    CardBarcodeFormat.code93: 'ABC-123',
    CardBarcodeFormat.itf: '12345678',
    CardBarcodeFormat.codabar: '123456-789',
    CardBarcodeFormat.qr: 'https://example.com/card/123',
    CardBarcodeFormat.pdf417: 'Some card data',
    CardBarcodeFormat.aztec: 'Some card data',
    CardBarcodeFormat.dataMatrix: 'Some card data',
  };

  for (final format in CardBarcodeFormat.all) {
    testWidgets('renders a $format barcode without an error widget', (
      tester,
    ) async {
      var sawError = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BarcodeWidget(
              data: sampleNumbers[format]!,
              barcode: toRenderBarcode(format),
              errorBuilder: (context, error) {
                sawError = true;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BarcodeWidget), findsOneWidget);
      expect(
        sawError,
        isFalse,
        reason: '$format should render without invoking errorBuilder',
      );
    });
  }
}
