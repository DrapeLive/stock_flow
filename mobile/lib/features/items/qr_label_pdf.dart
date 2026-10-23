/// Builds the QR label PDFs, mirroring the web exactly for both label kinds:
///  - `single`   -> 58mm x 90mm card (`qr/[id]`), `react-qr-code` default EC L,
///                  `Variant #<id>` pill caption.
///  - `printAll` -> 70.87 x 141.73pt sheet (`QRLabelPdf.tsx`, 25mm x 50mm), EC M
///                  (qrcode npm default, no quiet zone), `Color #<display_order>`
///                  plain-black caption (omitted when blank).
/// Both kinds use an ASCII-safe `Rs.` price (see [formatQrLabelPrice]).
/// QR images are rendered via `qr_flutter`'s painter and embedded as PNGs so
/// the `pdf` package can draw them (same approach as `qrcode` -> data URL).
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qr_flutter/qr_flutter.dart';

enum QrLabelKind { single, printAll }

class QrLabel {
  const QrLabel({
    required this.id,
    required this.qrCode,
    this.displayOrder,
  });

  final int id;
  final String qrCode;
  final String? displayOrder;
}

/// Web equivalent error correction levels:
///  - `react-qr-code` (single card) defaults to EC L.
///  - `qrcode` npm (print-all page, `QRCode.toDataURL`) defaults to EC M.
int errorCorrectionLevelFor(QrLabelKind kind) =>
    kind == QrLabelKind.single ? QrErrorCorrectLevel.L : QrErrorCorrectLevel.M;

/// Renders [data] as a PNG byte array using [QrPainter] (same as
/// `QRCode.toDataURL` in the web app). The raster is generated large (1024px)
/// so it stays crisp at print size.
Future<Uint8List> qrPngBytes(
  String data, {
  int errorCorrectionLevel = QrErrorCorrectLevel.L,
}) async {
  const size = 1024.0;
  final painter = QrPainter(
    data: data,
    version: QrVersions.auto,
    gapless: true,
    errorCorrectionLevel: errorCorrectionLevel,
  );
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  painter.paint(canvas, const Size(size, size));
  final image =
      await recorder.endRecording().toImage(size.toInt(), size.toInt());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

/// Extra leading (in PDF points) applied between wrapped lines.
///
/// The `pdf` package's standard-14 Helvetica fonts use a ~1.19em line box,
/// while the web labels use `lineHeight: 1.05`. Subtracting the difference per
/// font size keeps wrapped lines the same distance apart on both platforms.
double qrLabelLineSpacing(double fontSize) => fontSize * (1.05 - 1.19);

/// 58mm x 90mm label page (web `qr/[id]` card).
final PdfPageFormat qrLabelPageFormat =
    PdfPageFormat(58 * 2.834646, 90 * 2.834646);

/// 25mm x 50mm = 70.87pt x 141.73pt (web `QRLabelPdf.tsx`).
final PdfPageFormat qrPrintAllPageFormat = PdfPageFormat(70.87, 141.73);

PdfPageFormat pageFormatFor(QrLabelKind kind) =>
    kind == QrLabelKind.single ? qrLabelPageFormat : qrPrintAllPageFormat;

/// Caption matching the web `qr/[id]` card (`Variant #<id>`).
String qrLabelCaption(QrLabel label) => 'Variant #${label.id}';

/// Caption matching the web print-all page (`Color #<display_order>`), omitted
/// entirely when the variant has no display_order.
String qrPrintAllCaption(QrLabel label) {
  final displayOrder = label.displayOrder?.trim() ?? '';
  return displayOrder.isEmpty ? '' : 'Color #$displayOrder';
}

/// Formats the price for the printed label as `Rs. X.XX`.
///
/// The web single `qr/[id]` card and on-screen money helpers use the `₹`
/// glyph, but the `pdf` package only ships the standard-14 PostScript fonts
/// (Latin-1), so U+20B9 has no glyph and would print as a box/blank. The repo
/// has no font asset carrying `₹`, and `PdfGoogleFonts` needs a network fetch
/// at runtime. `Rs.` is ASCII-safe and already used by the web print-all
/// label (`QRLabelPdf.tsx`), so both mobile kinds and the web batch sheet now
/// share one unambiguous price format.
String formatQrLabelPrice(String price) {
  final parsed = double.tryParse(price);
  final value = (parsed ?? 0).toStringAsFixed(2);
  return 'Rs. $value';
}

/// Builds one label page per [labels] entry (each has its own QR).
/// `kind == printAll` mirrors `QRLabelPdf.tsx` (padding 4, gap 1.5, name
/// 11/800, caption 10/600 plain black, QR 60x60, price 10/800).
Future<pw.Document> buildQrLabelsPdf({
  required String itemName,
  required String price,
  String category = '',
  String fabric = '',
  required List<QrLabel> labels,
  List<Uint8List>? qrBytes,
  QrLabelKind kind = QrLabelKind.single,
  int errorCorrectionLevel = QrErrorCorrectLevel.L,
}) async {
  final doc = pw.Document();
  for (var i = 0; i < labels.length; i++) {
    final label = labels[i];
    final bytes = qrBytes != null
        ? qrBytes[i]
        : await qrPngBytes(
            label.qrCode,
            errorCorrectionLevel: errorCorrectionLevel,
          );
    doc.addPage(
      pw.Page(
        pageFormat: pageFormatFor(kind),
        margin: pw.EdgeInsets.zero,
        build: (context) => kind == QrLabelKind.single
            ? _buildSinglePage(itemName, price, category, fabric, label, bytes)
            : _buildPrintAllPage(
                itemName, price, category, fabric, label, bytes),
      ),
    );
  }
  return doc;
}

pw.Widget _buildSinglePage(String itemName, String price, String category,
    String fabric, QrLabel label, Uint8List bytes) {
  return pw.Center(
    child: pw.Container(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            itemName,
            textAlign: pw.TextAlign.center,
            maxLines: 3,
            overflow: pw.TextOverflow.clip,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              lineSpacing: qrLabelLineSpacing(11),
            ),
          ),
          if (category.trim().isNotEmpty || fabric.trim().isNotEmpty) ...[
            pw.SizedBox(height: 2),
            pw.Text(
              [
                if (category.trim().isNotEmpty) category.trim(),
                if (fabric.trim().isNotEmpty) fabric.trim()
              ].join('\n'),
              textAlign: pw.TextAlign.center,
              maxLines: 2,
              overflow: pw.TextOverflow.clip,
              style: pw.TextStyle(
                fontSize: 8,
                lineSpacing: qrLabelLineSpacing(8),
              ),
            ),
          ],
          pw.SizedBox(height: 4),
          pw.Container(
            padding: const pw.EdgeInsets.all(4),
            color: PdfColors.white,
            child: pw.Image(
              pw.MemoryImage(bytes),
              width: 130,
              height: 130,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Container(
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 1.5),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF0F0F0),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              qrLabelCaption(label),
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromInt(0xFF555555),
              ),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            formatQrLabelPrice(price),
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Mirrors `QRLabelPdf.tsx`: flex column, alignItems/justifyContent center,
/// padding 4, background white, with a 1.5pt gap between sections.
///
/// The item name/details block is wrapped in a [pw.Flexible] so the QR and
/// price are always laid out: `pdf`'s flex implementation stops laying out
/// fixed children as soon as their summed height overflows the page, which
/// previously dropped the price on long two-line names.
pw.Widget _buildPrintAllPage(String itemName, String price, String category,
    String fabric, QrLabel label, Uint8List bytes) {
  final caption = qrPrintAllCaption(label);
  const gap = 1.5;
  return pw.Container(
    padding: const pw.EdgeInsets.all(4),
    color: PdfColors.white,
    child: pw.Column(
      mainAxisAlignment: pw.MainAxisAlignment.center,
      children: [
        pw.Flexible(
          child: pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text(
                itemName,
                textAlign: pw.TextAlign.center,
                maxLines: 2,
                overflow: pw.TextOverflow.clip,
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  lineSpacing: qrLabelLineSpacing(11),
                ),
              ),
              if (category.trim().isNotEmpty || fabric.trim().isNotEmpty) ...[
                pw.SizedBox(height: gap),
                pw.Text(
                  [
                    if (category.trim().isNotEmpty) category.trim(),
                    if (fabric.trim().isNotEmpty) fabric.trim()
                  ].join('\n'),
                  textAlign: pw.TextAlign.center,
                  maxLines: 2,
                  overflow: pw.TextOverflow.clip,
                  style: pw.TextStyle(
                    fontSize: 6.5,
                    lineSpacing: qrLabelLineSpacing(6.5),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (caption.isNotEmpty) ...[
          pw.SizedBox(height: gap),
          pw.Container(
            padding: const pw.EdgeInsets.all(1.5),
            child: pw.Text(
              caption,
              textAlign: pw.TextAlign.center,
              maxLines: 1,
              overflow: pw.TextOverflow.clip,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
        pw.SizedBox(height: gap),
        pw.Image(
          pw.MemoryImage(bytes),
          width: 60,
          height: 60,
        ),
        pw.SizedBox(height: gap),
        pw.Text(
          formatQrLabelPrice(price),
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}
