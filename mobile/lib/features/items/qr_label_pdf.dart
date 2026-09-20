/// Builds the 58mm x 90mm QR label PDFs. Mirrors the web `qr/[id]` card and
/// `QRPageContent`/`QRLabelPdf` (single label -> one page per variant).
/// QR images are rendered via `qr_flutter`'s painter and embedded as PNGs so
/// the `pdf` package can draw them (same approach as `qrcode` -> data URL).
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qr_flutter/qr_flutter.dart';

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

/// Renders [data] as a PNG byte array using [QrPainter] (same as
/// `QRCode.toDataURL` in the web app).
Future<Uint8List> qrPngBytes(String data) async {
  const size = 480.0;
  final painter = QrPainter(data: data, version: QrVersions.auto, gapless: true);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  painter.paint(canvas, const Size(size, size));
  final image = await recorder.endRecording().toImage(size.toInt(), size.toInt());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

/// 58mm x 90mm label page.
const PdfPageFormat _labelFormat =
    PdfPageFormat(58 * 2.834646, 90 * 2.834646);

/// Builds one label page per [labels] entry (each has its own QR).
/// Item price uses `₹` like the web `qr/[id]` page.
Future<pw.Document> buildQrLabelsPdf({
  required String itemName,
  required String price,
  required List<QrLabel> labels,
  List<Uint8List>? qrBytes,
}) async {
  final doc = pw.Document();
  for (var i = 0; i < labels.length; i++) {
    final label = labels[i];
    final bytes = qrBytes != null
        ? qrBytes[i]
        : await qrPngBytes(label.qrCode);
    doc.addPage(
      pw.Page(
        pageFormat: _labelFormat,
        margin: pw.EdgeInsets.zero,
        build: (context) {
          return pw.Center(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    itemName,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(4),
                    color: PdfColors.white,
                    child: pw.Image(
                      pw.MemoryImage(bytes),
                      width: 130,
                      height: 130,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFF0F0F0),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text(
                      'Variant #${label.displayOrder ?? label.id}',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromInt(0xFF555555),
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    _formatPrice(price),
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  return doc;
}

String _formatPrice(String price) {
  final parsed = double.tryParse(price);
  return '₹${(parsed ?? 0).toStringAsFixed(2)}';
}