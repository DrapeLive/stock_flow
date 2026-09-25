
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../core/theme/app_theme.dart';
import '../../data/repositories.dart';
import '../../models/models.dart';
import '../../shared/widgets.dart';
import 'qr_label_pdf.dart';

/// Mirrors `app/(admin-no-layout)/admin/items/qr-print/page.tsx` (SE page).
/// When reached with `?item=<id>` it shows all variants of that item as
/// printable 70.87x141.73pt (25mm x 50mm) EC M labels (web `QRLabelPdf.tsx`);
/// without it, lists items to choose from first.
class QrPrintSelectScreen extends ConsumerStatefulWidget {
  const QrPrintSelectScreen({super.key, this.itemId});
  final int? itemId;

  @override
  ConsumerState<QrPrintSelectScreen> createState() => _QrPrintSelectScreenState();
}

class _QrPrintSelectScreenState extends ConsumerState<QrPrintSelectScreen> {
  bool _loading = true;
  String? _error;
  String _itemName = '';
  String _price = '';
  List<QrLabel> _labels = const [];
  List<Uint8List> _qrBytes = const [];
  List<ItemStockEntry> _items = const [];

  @override
  void initState() {
    super.initState();
    if (widget.itemId != null) {
      _loadItem();
    } else {
      _loadItems();
    }
  }

  Future<void> _loadItem() async {
    try {
      final data = await repos.item.getOne(widget.itemId!);
      final labels = <QrLabel>[];
      for (final v in data.variants) {
        labels.add(QrLabel(
          id: v.id,
          qrCode: v.qrCode ?? '${widget.itemId!}-${v.id}',
          displayOrder: v.displayOrder,
        ));
      }
final bytes = await Future.wait(
          labels.map((l) => qrPngBytes(
                l.qrCode,
                errorCorrectionLevel: errorCorrectionLevelFor(QrLabelKind.printAll),
              )));
      if (!mounted) return;
      setState(() {
        _itemName = data.name;
        _price = data.price;
        _labels = labels;
        _qrBytes = bytes;
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

  Future<void> _loadItems() async {
    try {
      final items = await repos.item.stockList();
      if (!mounted) return;
      setState(() {
        _items = items;
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
      labels: _labels,
      qrBytes: _qrBytes,
      kind: QrLabelKind.printAll,
      errorCorrectionLevel: errorCorrectionLevelFor(QrLabelKind.printAll),
    );
    return doc.save();
  }

  @override
  Widget build(BuildContext context) {
final hasItem = widget.itemId != null;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
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
                    child: Text(
                      hasItem ? _itemName : 'Print QR labels',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827)),
                    ),
                  ),
                  if (hasItem)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.15)),
                      ),
                      child: Text('${_labels.length} label${_labels.length != 1 ? 's' : ''}',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: _loading
                  ? const PageLoading()
                  : _error != null
                      ? EmptyState(
                          icon: Icons.print,
                          title: 'Could not load labels',
                          subtitle: _error,
                          action: Align(
                            child: StockFlowButton(
                              label: 'Retry',
                              onPressed: () => hasItem
                                  ? _loadItem()
                                  : _loadItems(),
                              expand: false,
                            ),
                          ),
                        )
                      : hasItem
                          ? PdfPreview(
                              canChangeOrientation: false,
                              canChangePageFormat: false,
                              canDebug: false,
                              allowSharing: true,
                              build: _buildPdf,
                            )
                          : _itemPicker(),
),
          ],
        ),
      ),
    );
  }

  Widget _itemPicker() {
    if (_items.isEmpty) {
      return const EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'No items available',
        subtitle: 'Add items first to print their QR labels',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 20),
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text('Select an item to print its QR labels',
              style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
        ),
        for (final item in _items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () =>
                  context.push('/admin/items/qr-print?item=${item.id}'),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: AppImage(item.image, iconSize: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827))),
                    ),
                    Text('${item.variants.length}',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF9CA3AF))),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right,
                        size: 16, color: Color(0xFFD1D5DB)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}