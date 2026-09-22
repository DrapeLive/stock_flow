import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:stock_flow_admin/features/items/qr_label_pdf.dart';

void main() {
  const sampleUuid = '123e4567-e89b-12d3-a456-426614174000';

  group('qrLabelCaption', () {
    test('matches the web qr/[id] card using the variant id', () {
      expect(qrLabelCaption(const QrLabel(id: 7, qrCode: 'abc')), 'Variant #7');
    });

    test('ignores display_order', () {
      expect(
        qrLabelCaption(
          const QrLabel(id: 3, qrCode: 'abc', displayOrder: 'M'),
        ),
        'Variant #3',
      );
    });
  });

  group('qrPrintAllCaption', () {
    test('mirrors web QRLabelPdf "Color #<display_order>"', () {
      expect(
        qrPrintAllCaption(const QrLabel(id: 3, qrCode: 'abc', displayOrder: 'M')),
        'Color #M',
      );
    });

    test('omits the caption entirely when display_order is null or blank', () {
      expect(
        qrPrintAllCaption(const QrLabel(id: 3, qrCode: 'abc')),
        '',
      );
      expect(
        qrPrintAllCaption(const QrLabel(id: 3, qrCode: 'abc', displayOrder: '')),
        '',
      );
      expect(
        qrPrintAllCaption(const QrLabel(id: 3, qrCode: 'abc', displayOrder: '  ')),
        '',
      );
    });
  });

  group('errorCorrectionLevelFor', () {
    test('single uses EC L (react-qr-code default)', () {
      expect(errorCorrectionLevelFor(QrLabelKind.single), QrErrorCorrectLevel.L);
    });

    test('printAll uses EC M (qrcode npm default)', () {
      expect(errorCorrectionLevelFor(QrLabelKind.printAll), QrErrorCorrectLevel.M);
    });
  });

  group('formatQrLabelPrice', () {
    test('uses Rs. like the web QRLabelPdf print-all label', () {
      // The pdf package ships only the standard-14 Latin-1 fonts (no U+20B9
      // glyph) and the repo has no font asset for `₹`, so labels print the
      // ASCII-safe "Rs." form used by QRLabelPdf.tsx instead of `₹`.
      expect(formatQrLabelPrice('199.5'), 'Rs. 199.50');
      expect(formatQrLabelPrice('abc'), 'Rs. 0.00');
    });
  });

  group('page formats', () {
    test('single is a 58mm x 90mm page', () {
      expect(qrLabelPageFormat.width, closeTo(58 * 2.834646, 0.01));
      expect(qrLabelPageFormat.height, closeTo(90 * 2.834646, 0.01));
    });

    test('printAll is a 70.87pt x 141.73pt (25mm x 50mm) page like QRLabelPdf', () {
      expect(qrPrintAllPageFormat.width, closeTo(70.87, 0.01));
      expect(qrPrintAllPageFormat.height, closeTo(141.73, 0.01));
      expect(pageFormatFor(QrLabelKind.printAll), qrPrintAllPageFormat);
      expect(pageFormatFor(QrLabelKind.single), qrLabelPageFormat);
    });
  });

  group('buildQrLabelsPdf', () {
    test('produces a non-empty PDF for both kinds', () async {
      final sampleQrBytes = await qrPngBytes(sampleUuid);
      final labels = [const QrLabel(id: 3, qrCode: sampleUuid)];

      final single = await buildQrLabelsPdf(
        itemName: 'Test Shirt',
        price: '299.00',
        labels: labels,
        qrBytes: [sampleQrBytes],
        kind: QrLabelKind.single,
      );
      expect((await single.save()).length, greaterThan(0));

      final printAll = await buildQrLabelsPdf(
        itemName: 'Test Shirt',
        price: '299.00',
        labels: labels,
        qrBytes: [sampleQrBytes],
        kind: QrLabelKind.printAll,
        errorCorrectionLevel: errorCorrectionLevelFor(QrLabelKind.printAll),
      );
      expect((await printAll.save()).length, greaterThan(0));
    });
  });

  group('qr-code parity (Dart encoder)', () {
    // Documented divergence: the Dart `qr` encoder (qr_flutter 4.1.0) renders
    // version 3 (29x29) for this payload at BOTH EC L and EC M, while the web
    // `qrcode` npm encoder renders 25x25 (v2) for L and 29x29 (v3) for M.
    // Payloads are identical and both are scannable. See
    // frontend/tests/lib/qr-label-parity.test.ts for the web side.
    test('fixed UUID is version 3 (29x29) at both EC L and EC M', () {
      for (final ec in [QrErrorCorrectLevel.L, QrErrorCorrectLevel.M]) {
        final code = QrCode.fromData(data: sampleUuid, errorCorrectLevel: ec);
        final img = QrImage(code);
        expect(img.moduleCount, 29);
      }
    });
  });
}