
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../data/repositories.dart';
import '../../models/models.dart';
import '../../shared/widgets.dart';
import 'qr_label_pdf.dart';

/// Mirrors `app/(admin-no-layout)/admin/items/qr/[id]/page.tsx` â€” a single
/// 58mm x 90mm QR label for one variant, auto-printable.
class QrLabelScreen extends ConsumerStatefulWidget {
  const QrLabelScreen({super.key, required this.qr});
  final String qr;

  @override
  ConsumerState<QrLabelScreen> createState() => _QrLabelScreenState();
}

class _QrLabelScreenState extends ConsumerState<QrLabelScreen> {
  bool _loading = true;
  String? _error;
  String _itemName = '';
  String _price = '';
  List<Uint8List> _qrBytes = const [];
  QrLabel _label = const QrLabel(id: 0, qrCode: '');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await repos.item.byqrcode(widget.qr);
      final variants =
          (data['variants'] as List?)?.cast<Map>() ?? const [];
      final qr = widget.qr;
      Map<String, dynamic> variant = const <String, dynamic>{};
      for (final raw in variants) {
        final v = raw.cast<String, dynamic>();
        if (s(v['qr_code']) == qr) {
          variant = v;
          break;
        }
      }
      if (variant.isEmpty && variants.isNotEmpty) {
        variant = variants.first.cast<String, dynamic>();
      }
      final displayOrder = variant['display_order'] as String?;
      final id = asInt(variant['id']) ?? 0;
      final label = QrLabel(
        id: id,
        qrCode: (variant['qr_code'] as String?) ?? qr,
        displayOrder: displayOrder,
      );
      final bytes = await qrPngBytes(label.qrCode);
      if (!mounted) return;
      setState(() {
        _itemName = s(data['name']);
        _price = s(data['price']);
        _label = label;
        _qrBytes = [bytes];
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<Uint8List> _buildPdf(PdfPageFormat format) async {
    final doc = await buildQrLabelsPdf(
      itemName: _itemName,
      price: _price,
      labels: [_label],
      qrBytes: _qrBytes,
    );
    return doc.save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
body: SafeArea(
        child: _loading
            ? const PageLoading()
            : _error != null
                ? EmptyState(
                    icon: Icons.qr_code_2,
                    title: 'Could not load label',
                    subtitle: _error,
                    action: Align(
                      child: StockFlowButton(
                        label: 'Retry',
                        onPressed: _load,
                        expand: false,
                      ),
                    ),
                  )
: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
                        child: Row(
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => context.canPop()
                              ? context.pop()
                              : context.go('/admin/items'),
                              child: const Padding(
                                padding: EdgeInsets.all(6),
                                child: Icon(Icons.arrow_back,
                                    size: 20, color: Color(0xFF9CA3AF)),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(_itemName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF111827))),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: PdfPreview(
                          canChangeOrientation: false,
                          canChangePageFormat: false,
                          canDebug: false,
                          allowSharing: true,
                          build: _buildPdf,
                        ),
                      ),
                    ],
                  ),
        ),
    );
  }
}