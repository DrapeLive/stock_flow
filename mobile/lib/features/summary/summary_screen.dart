import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/utils/perf.dart';
import '../../core/utils/text_symbols.dart';
import '../../data/repositories.dart';
import '../../models/models.dart';
import '../../providers.dart';
import '../../shared/widgets.dart';

const sizeRangePieceCount = <String, int>{
  '20-38': 10,
  '20-36': 9,
  '26-38': 7,
  '20-30': 6,
  '26-36': 6,
  '32-38': 4,
  '32-36': 3,
  'S,M,L,XL,XXL': 5,
  'S,M,L,XL': 4,
  'M,L,XL,XXL': 4,
  'M,L,XL': 3,
};

const singleSizePieceCount = <String, int>{
  'S': 1,
  'M': 1,
  'L': 1,
  'XL': 1,
  'XXL': 1,
  '38': 1,
  '32-36': 3,
  '26-30': 3,
  '20-24': 3,
};

int getPieceCount(String sizeRange) {
  final ranged = sizeRangePieceCount[sizeRange];
  if (ranged != null) return ranged;
  final single = singleSizePieceCount[sizeRange];
  if (single != null) return single;
  return sizeRange.split(',').length;
}

String formatCurrency(num value) {
  final formatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '\u20B9',
  );
  return formatter.format(value.round());
}

class ItemSummary {
  const ItemSummary({
    required this.id,
    required this.name,
    required this.type,
    required this.price,
    required this.variantCount,
    required this.totalStock,
    required this.totalUnits,
    required this.totalPrice,
  });
  final int id;
  final String name;
  final String type;
  final String price;
  final int variantCount;
  final int totalStock;
  final int totalUnits;
  final double totalPrice;
}

class ComputedSummary {
  const ComputedSummary({
    required this.totalStock,
    required this.totalUnits,
    required this.totalPrice,
    required this.gentsStock,
    required this.gentsUnits,
    required this.gentsPrice,
    required this.kidsStock,
    required this.kidsUnits,
    required this.kidsPrice,
    required this.itemSummaries,
  });
  final int totalStock;
  final int totalUnits;
  final double totalPrice;
  final int gentsStock;
  final int gentsUnits;
  final double gentsPrice;
  final int kidsStock;
  final int kidsUnits;
  final double kidsPrice;
  final List<ItemSummary> itemSummaries;
}

ComputedSummary computeSummary(List<ItemStockEntry> items) {
  var totalStock = 0;
  var totalUnits = 0;
  var totalPrice = 0.0;
  var gentsStock = 0;
  var gentsUnits = 0;
  var gentsPrice = 0.0;
  var kidsStock = 0;
  var kidsUnits = 0;
  var kidsPrice = 0.0;

  final entries = <ItemSummary>[];
  for (final item in items) {
    var itemStock = 0;
    var itemUnits = 0;
    final unitPrice = double.tryParse(item.price) ?? 0;
    for (final variant in item.variants) {
      for (final sizeEntry in variant.sizes) {
        final pieces = getPieceCount(sizeEntry.sizeRange);
        itemStock += sizeEntry.stock;
        itemUnits += sizeEntry.stock * pieces;
      }
    }
    final itemPrice = itemUnits * unitPrice;
    totalStock += itemStock;
    totalUnits += itemUnits;
    totalPrice += itemPrice;
    if (item.type == 'gents') {
      gentsStock += itemStock;
      gentsUnits += itemUnits;
      gentsPrice += itemPrice;
    } else if (item.type == 'kids') {
      kidsStock += itemStock;
      kidsUnits += itemUnits;
      kidsPrice += itemPrice;
    }
    entries.add(ItemSummary(
      id: item.id,
      name: item.name,
      type: item.type ?? '',
      price: item.price,
      variantCount: item.variants.length,
      totalStock: itemStock,
      totalUnits: itemUnits,
      totalPrice: itemPrice,
    ));
  }

  return ComputedSummary(
    totalStock: totalStock,
    totalUnits: totalUnits,
    totalPrice: totalPrice,
    gentsStock: gentsStock,
    gentsUnits: gentsUnits,
    gentsPrice: gentsPrice,
    kidsStock: kidsStock,
    kidsUnits: kidsUnits,
    kidsPrice: kidsPrice,
    itemSummaries: entries,
  );
}

enum _SortKey { name, totalUnits, totalPrice }

/// Mirrors `app/(admin-no-layout)/admin/summary/page.tsx`.
class SummaryScreen extends ConsumerStatefulWidget {
  const SummaryScreen({super.key});

  @override
  ConsumerState<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends ConsumerState<SummaryScreen> {
  List<ItemStockEntry> _items = const [];
  bool _loading = true;
  _SortKey _sortKey = _SortKey.name;
  bool _sortAsc = false;
  String _typeFilter = 'all';

  String? get _business {
    final session = ref.read(sessionProvider);
    final b = session?.user.business;
    if (b == null || b.isEmpty) return null;
    return b;
  }

@override
  void initState() {
    super.initState();
    Perf.start('summary');
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await repos.item.stockList();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
      Perf.end('summary', 'TTC');
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _handleSort(_SortKey key) {
    setState(() {
      if (_sortKey == key) {
        _sortAsc = !_sortAsc;
      } else {
        _sortKey = key;
        _sortAsc = false;
      }
    });
  }

  void _toggleUnitsAsc() {
    setState(() {
      if (_sortKey == _SortKey.totalUnits && _sortAsc) {
        _sortKey = _SortKey.name;
        _sortAsc = false;
      } else {
        _sortKey = _SortKey.totalUnits;
        _sortAsc = true;
      }
    });
  }

  bool get _unitsAscActive => _sortKey == _SortKey.totalUnits && _sortAsc;

@override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFBFBFA),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF9CA3AF)),
          onPressed: () => context.canPop()
            ? context.pop()
            : context.go('/admin/profile'),
        ),
        title: const Text('Summary',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Colors.black)),
        centerTitle: true,
      ),
      body: _loading && _items.isEmpty
          ? const PageLoading(label: 'Loading inventory...')
          : _content(),
    );
  }

  Widget _content() {
    final summary = computeSummary(_items);
    final business = _business;

    final showAll = business != 'kids' && business != 'gents';
    final showGents = business != 'kids';
    final showKids = business != 'gents';

    final filtered = summary.itemSummaries
        .where((i) => _typeFilter == 'all' || i.type == _typeFilter)
        .where((i) => i.totalStock != 0)
        .toList();

    filtered.sort((a, b) {
      if (_sortKey == _SortKey.name) {
        final an = _sortName(a.name);
        final bn = _sortName(b.name);
        final cmp = _compareNumeric(an, bn);
        return _sortAsc ? cmp : -cmp;
      }
final int cmp;
      switch (_sortKey) {
        case _SortKey.totalUnits:
          cmp = a.totalUnits - b.totalUnits;
          break;
        case _SortKey.totalPrice:
          cmp = a.totalPrice
              .compareTo(b.totalPrice);
          break;
        default:
          cmp = 0;
      }
      return _sortAsc ? cmp : -cmp;
    });

    final totals = filtered.fold<_RowTotals>(
      _RowTotals(stock: 0, units: 0, price: 0),
      (s, i) => _RowTotals(
          stock: s.stock + i.totalStock,
          units: s.units + i.totalUnits,
          price: s.price + i.totalPrice),
    );

return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
      children: [
        const Text('Inventory Summary',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black)),
        const SizedBox(height: 20),
        if (showAll) ...[
          _statCard(
              'All Items',
              _RowTotals(
                  stock: summary.totalStock,
                  units: summary.totalUnits,
                  price: summary.totalPrice)),
          const SizedBox(height: 10),
        ],
        if (showGents) ...[
          _statCard(
              'Gents',
              _RowTotals(
                  stock: summary.gentsStock,
                  units: summary.gentsUnits,
                  price: summary.gentsPrice)),
          const SizedBox(height: 10),
        ],
        if (showKids) ...[
          _statCard(
              'Kids',
              _RowTotals(
                  stock: summary.kidsStock,
                  units: summary.kidsUnits,
                  price: summary.kidsPrice)),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            const Expanded(
              child: Text('PER-ITEM BREAKDOWN',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: Color(0xFF6B7280))),
            ),
            _pill(
              'Total Pieces: Low $kArrow High',
              active: _unitsAscActive,
              onTap: _toggleUnitsAsc,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (showAll)
          Row(
            children: [
              for (final t in ['all', 'gents', 'kids'])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _pill(t, active: _typeFilter == t, onTap: () {
                    setState(() => _typeFilter = t);
                  }),
                ),
            ],
          ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFF3F4F6)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
child: Table(
              columnWidths: const {
                0: FlexColumnWidth(2.4),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1),
                3: FlexColumnWidth(1.6),
              },
              children: [
                TableRow(
                  decoration: const BoxDecoration(
                      color: Color(0xFFF9FAFB)),
                  children: [
                    _th('Item', onTap: () => _handleSort(_SortKey.name)),
                    _th('Total Pieces', right: true,
                        onTap: () => _handleSort(_SortKey.totalUnits)),
                    _th('Variants', center: true),
                    _th('Total Value', right: true,
                        onTap: () => _handleSort(_SortKey.totalPrice)),
                  ],
                ),
                for (var idx = 0; idx < filtered.length; idx++)
                  TableRow(
                    decoration: BoxDecoration(
                      color: idx.isEven
                          ? Colors.white
                          : const Color(0xFFF9FAFB),
                    ),
                    children: [
                      _td(filtered[idx].name, mono: true, bold: true),
                      _td(_fmt(filtered[idx].totalUnits), right: true),
                      _td('${filtered[idx].variantCount}', center: true),
                      _td(formatCurrency(filtered[idx].totalPrice),
                          right: true, bold: true),
                    ],
                  ),
                TableRow(
                  decoration: const BoxDecoration(
                      color: Color(0xFFF9FAFB)),
                  children: [
                    _td('Total (${filtered.length} items)',
                        bold: true),
                    _td(_fmt(totals.units), right: true, bold: true),
                    _td('', center: true),
                    _td(formatCurrency(totals.price), right: true, bold: true),
                  ],
                ),
              ],
            ),
),
        ),
      ],
    );
  }

  static String _sortName(String name) {
    final dash = name.indexOf('-');
    return dash > 0 ? name.substring(0, dash) : name;
  }

  static int _compareNumeric(String a, String b) {
    // Simple numeric-aware comparison on the leading number.
    final na = _leadingNumber(a);
    final nb = _leadingNumber(b);
    if (na != null && nb != null) return na.compareTo(nb);
    return a.compareTo(b);
  }

  static double? _leadingNumber(String s) {
    final m = RegExp(r'^\d+').firstMatch(s.trim());
    return m == null ? null : double.parse(m.group(0)!);
  }

  static String _fmt(int v) => NumberFormat.decimalPattern('en_IN').format(v);

  Widget _statCard(String label, _RowTotals total) {
    final avg = total.stock > 0 ? total.units / total.stock : 0.0;
    final avgStr = total.stock > 0 ? avg.toStringAsFixed(1) : '0';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: Color(0xFF9CA3AF))),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_fmt(total.stock),
                        style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827))),
                    const Text('stock sets',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFF6B7280))),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_fmt(total.units),
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827))),
                  const Text('total units',
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFF6B7280))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Text('Total Value',
                    style: TextStyle(
                        fontSize: 12, color: Color(0xFF9CA3AF))),
                const Spacer(),
                Text(formatCurrency(total.price),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937))),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: (double.tryParse(avgStr) ?? 0) / 10,
                    minHeight: 5,
                    backgroundColor: const Color(0xFFF3F4F6),
                    color: Colors.black.withValues(alpha: 0.35),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('$kMultiply$avgStr avg pcs/set',
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF9CA3AF))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, {required bool active, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color:
                active ? Colors.black : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : const Color(0xFF6B7280),
            )),
      ),
    );
  }

  Widget _th(String text, {bool right = false, bool center = false, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: InkWell(
        onTap: onTap,
        child: Text(text,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: Color(0xFF9CA3AF))),
      ),
    );
  }

  Widget _td(String text,
      {bool right = false, bool center = false, bool mono = false, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Text(
        text,
        textAlign: right
            ? TextAlign.right
            : center
                ? TextAlign.center
                : TextAlign.left,
        style: TextStyle(
          fontSize: 12,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          color: const Color(0xFF1F2937),
          fontFamily: mono ? 'monospace' : null,
        ),
      ),
);
  }
}

class _RowTotals {
  const _RowTotals(
      {required this.stock, required this.units, required this.price});
  final int stock;
  final int units;
  final double price;
}