import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_flow_admin/features/items/qr_label_pdf.dart';

const _longName =
    'Premium Heavyweight Oversized Drop Shoulder Cotton Crew Neck T-Shirt';

/// Extracts the (inflated) content streams of a generated PDF.
List<String> _contentStreams(Uint8List bytes) {
  final raw = latin1.decode(bytes, allowInvalid: true);
  final out = <String>[];
  final re = RegExp(r'/Length\s+(\d+)[^>]*>>\s*stream\r?\n');
  for (final m in re.allMatches(raw)) {
    final length = int.parse(m.group(1)!);
    final start = m.end;
    if (start + length > bytes.length) continue;
    final chunk = bytes.sublist(start, start + length);
    try {
      out.add(latin1.decode(ZLibDecoder().convert(chunk), allowInvalid: true));
    } catch (_) {
      out.add(latin1.decode(chunk, allowInvalid: true));
    }
  }
  return out;
}

/// A PDF transformation matrix. `concat` applies `this` first, then `other`.
class _Matrix {
  double a = 1, b = 0, c = 0, d = 1, e = 0, f = 0;

  _Matrix concat(_Matrix m) => _Matrix()
    ..a = m.a * a + m.c * b
    ..b = m.b * a + m.d * b
    ..c = m.a * c + m.c * d
    ..d = m.b * c + m.d * d
    ..e = m.a * e + m.c * f + m.e
    ..f = m.b * e + m.d * f + m.f;

  double mapX(double x, double y) => a * x + c * y + e;

  double mapY(double x, double y) => b * x + d * y + f;
}

/// Joined (inflated) content streams, used to check which strings survived.
String _streamText(Uint8List bytes) => _contentStreams(bytes).join('\n');

/// Absolute geometry of everything drawn on the page.
class _Drawn {
  final List<({double x, double y, String text})> texts = [];
  final List<({double x, double y, double width, double height})> images = [];
}

/// Interprets the content streams of a PDF and reports absolute coordinates.
_Drawn _draw(Uint8List bytes) {
  final drawn = _Drawn();
  final tokenRe = RegExp(r'(-?[\d.]+)|(\[)|(\])|(/[^\s\[\]]+)|([A-Za-z]+)');

  for (final stream in _contentStreams(bytes)) {
    var ctm = _Matrix();
    var lineMatrix = _Matrix();
    final stack = <_Matrix>[];
    final operands = <double>[];
    var inArray = false;
    var array = '';

    for (final m in tokenRe.allMatches(stream)) {
      final token = m.group(0)!;
      if (inArray) {
        if (token == ']') {
          inArray = false;
        } else {
          array += token;
        }
        continue;
      }
      if (token == '[') {
        inArray = true;
        array = '';
        continue;
      }
      if (m.group(4) != null) continue;
      if (m.group(1) != null) {
        operands.add(double.parse(m.group(1)!));
        continue;
      }

      switch (token) {
        case 'q':
          stack.add(ctm);
        case 'Q':
          if (stack.isNotEmpty) ctm = stack.removeLast();
        case 'cm':
          if (operands.length >= 6) {
            final n = operands.sublist(operands.length - 6);
            ctm = (_Matrix()
                  ..a = n[0]
                  ..b = n[1]
                  ..c = n[2]
                  ..d = n[3]
                  ..e = n[4]
                  ..f = n[5])
                .concat(ctm);
          }
        case 'BT':
          lineMatrix = _Matrix();
        case 'Td':
          if (operands.length >= 2) {
            final n = operands.sublist(operands.length - 2);
            lineMatrix = (_Matrix()
                  ..e = n[0]
                  ..f = n[1])
                .concat(lineMatrix);
            drawn.texts.add((
              x: ctm.mapX(lineMatrix.e, lineMatrix.f),
              y: ctm.mapY(lineMatrix.e, lineMatrix.f),
              text: '',
            ));
          }
        case 'TJ':
          if (drawn.texts.isNotEmpty) {
            final last = drawn.texts.removeLast();
            drawn.texts.add((x: last.x, y: last.y, text: array));
          }
        case 'Do':
          final x0 = ctm.mapX(0, 0);
          final y0 = ctm.mapY(0, 0);
          final x1 = ctm.mapX(1, 1);
          final y1 = ctm.mapY(1, 1);
          drawn.images.add((
            x: x0 < x1 ? x0 : x1,
            y: y0 < y1 ? y0 : y1,
            width: (x1 - x0).abs(),
            height: (y1 - y0).abs(),
          ));
      }
      operands.clear();
    }
  }
  return drawn;
}

void main() {
  final kinds = <String, QrLabelKind>{
    'single': QrLabelKind.single,
    'printAll': QrLabelKind.printAll,
  };

  kinds.forEach((name, kind) {
    group('qr label fit ($name)', () {
      Future<Uint8List> renderBytes(String itemName,
          {String category = 'Shirts',
          String fabric = 'Cotton',
          String price = '1999.00'}) async {
        final doc = await buildQrLabelsPdf(
          itemName: itemName,
          price: price,
          category: category,
          fabric: fabric,
          labels: [const QrLabel(id: 3, qrCode: 'abc', displayOrder: 'M')],
          kind: kind,
        );
        return doc.save();
      }

      Future<_Drawn> render(String itemName,
              {String category = 'Shirts',
              String fabric = 'Cotton',
              String price = '1999.00'}) async =>
          _draw(await renderBytes(itemName,
              category: category, fabric: fabric, price: price));

      test('short item name stays inside the page', () async {
        final format = pageFormatFor(kind);
        final drawn = await render('Test Shirt', price: '199.50');

        expect(drawn.texts, isNotEmpty, reason: 'no text was drawn');
        expect(drawn.images, isNotEmpty, reason: 'the qr image was not drawn');

        for (final text in drawn.texts) {
          expect(text.y, greaterThanOrEqualTo(0),
              reason: 'text "${text.text}" is above the page');
          expect(text.y, lessThanOrEqualTo(format.height),
              reason: 'text "${text.text}" is below the page');
        }
        for (final image in drawn.images) {
          expect(image.x, greaterThanOrEqualTo(0),
              reason: 'the qr image is outside the page');
          expect(image.y, greaterThanOrEqualTo(0),
              reason: 'the qr image is outside the page');
          expect(image.x + image.width, lessThanOrEqualTo(format.width),
              reason: 'the qr image is outside the page');
          expect(image.y + image.height, lessThanOrEqualTo(format.height),
              reason: 'the qr image is outside the page');
        }
      });

      test('long item name is clipped to two lines', () async {
        final drawn = await render(_longName);
        final words = drawn.texts.map((t) => t.text).toList();

        expect(words, contains('Premium'));
        expect(words, isNot(contains('T-Shirt')),
            reason: 'the item name was not clipped to two lines');
      });

      test('long content keeps every field and the QR inside the page',
          () async {
        final format = pageFormatFor(kind);
        final bytes = await renderBytes(
          _longName,
          category: 'Premium Heavyweight Oversized T-Shirts',
          fabric: '100% Combed Cotton Fabric',
        );
        final drawn = _draw(bytes);
        final stream = _streamText(bytes);

        expect(stream, contains('Premium'),
            reason: 'the item name was dropped');
        expect(stream, contains('Rs.'), reason: 'the price was dropped');
        expect(stream, contains('1999.00'), reason: 'the price was dropped');
        expect(
            stream, contains(kind == QrLabelKind.single ? 'Variant' : 'Color'),
            reason: 'the variant caption was dropped');

        final qr = drawn.images.single;
        final qrSide = kind == QrLabelKind.single ? 130.0 : 60.0;
        expect(qr.width, closeTo(qrSide, 0.01));
        expect(qr.height, closeTo(qrSide, 0.01));
        expect(qr.x + qr.width / 2, closeTo(format.width / 2, 0.01),
            reason: 'the QR code is not horizontally centered');
        expect(qr.y, greaterThanOrEqualTo(0));
        expect(qr.y + qr.height, lessThanOrEqualTo(format.height));

        final price = drawn.texts.firstWhere((t) => t.text.contains('Rs.'));
        expect(price.y, lessThan(qr.y),
            reason: 'the price must sit below the QR code');
        expect(price.y, greaterThan(0),
            reason: 'the price is below the printable area');

        final nameLine =
            drawn.texts.firstWhere((t) => t.text.contains('Premium'));
        expect(nameLine.y, greaterThan(qr.y + qr.height),
            reason: 'the item name must sit above the QR code');

        for (final text in drawn.texts) {
          expect(text.x, greaterThanOrEqualTo(0),
              reason: 'text "${text.text}" starts left of the page');
          expect(text.x, lessThanOrEqualTo(format.width),
              reason: 'text "${text.text}" starts right of the page');
          expect(text.y, greaterThanOrEqualTo(0),
              reason: 'text "${text.text}" is above the page');
          expect(text.y, lessThanOrEqualTo(format.height),
              reason: 'text "${text.text}" is below the page');
        }
      });

      test('very long unbroken name still prints the price', () async {
        final format = pageFormatFor(kind);
        final bytes = await renderBytes(
          List.filled(3, 'SUPERCALIFRAGILISTICEXPIALIDOCIOUS').join(),
          category: 'Premium Heavyweight Oversized Extra Long Category Label',
          fabric: '100% Combed Cotton Fabric',
        );
        final drawn = _draw(bytes);
        final stream = _streamText(bytes);

        expect(stream, contains('Rs.'), reason: 'the price was dropped');
        expect(stream, contains('1999.00'), reason: 'the price was dropped');

        final qr = drawn.images.single;
        final price = drawn.texts.firstWhere((t) => t.text.contains('Rs.'));
        expect(price.y, lessThan(qr.y),
            reason: 'the price must sit below the QR code');

        for (final text in drawn.texts) {
          expect(text.y, greaterThanOrEqualTo(0));
          expect(text.y, lessThanOrEqualTo(format.height));
        }
      });
    });
  });
}
