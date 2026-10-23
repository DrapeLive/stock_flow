import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/repositories.dart';
import '../../models/models.dart';
import '../../shared/admin_shell.dart';
import '../../shared/widgets.dart';

enum _SortBy { sales, pieces }

class ItemAnalyticsScreen extends ConsumerStatefulWidget {
  const ItemAnalyticsScreen({super.key, this.from = '', this.to = ''});

  final String from;
  final String to;

  @override
  ConsumerState<ItemAnalyticsScreen> createState() =>
      _ItemAnalyticsScreenState();
}

class _ItemAnalyticsScreenState extends ConsumerState<ItemAnalyticsScreen> {
  late String _from;
  late String _to;
  late String _draftFrom;
  late String _draftTo;

  ItemAnalyticsData? _data;
  String? _error;
  bool _loading = true;
  bool _fetching = false;
  bool _expanded = true;
  _SortBy _sortBy = _SortBy.sales;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _to = widget.to.isNotEmpty ? widget.to : DateFormat('y-MM-dd').format(now);
    _from = widget.from.isNotEmpty
        ? widget.from
        : DateFormat('y-MM-dd').format(now.subtract(const Duration(days: 30)));
    _draftFrom = _from;
    _draftTo = _to;
    _fetch();
  }

  Future<void> _fetch() async {
    if (_fetching) return;
    _fetching = true;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await repos.dashboard.analytics(
        _from,
        _to,
        forceRefresh: true,
      );
      if (!data.hasItemAnalytics) {
        throw Exception(
          'Item analytics is unavailable from the server. '
          'Deploy the updated backend and retry.',
        );
      }
      if (!mounted) return;
      setState(() {
        _data = data.itemAnalytics;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      _fetching = false;
    }
  }

  void _toggleDateFilter() {
    setState(() {
      _expanded = !_expanded;
      _draftFrom = _from;
      _draftTo = _to;
    });
  }

  void _applyRange() {
    if (_loading || _draftFrom.isEmpty || _draftTo.isEmpty) return;
    setState(() {
      _from = _draftFrom;
      _to = _draftTo;
      _data = null;
      _expanded = false;
    });
    _fetch();
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final current = isFrom ? _draftFrom : _draftTo;
    final initial = DateTime.tryParse(current);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    final value = DateFormat('y-MM-dd').format(picked);
    setState(() {
      if (isFrom) {
        _draftFrom = value;
      } else {
        _draftTo = value;
      }
    });
  }

  Widget _dateField({
    required String label,
    required String value,
    required VoidCallback onPick,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onPick,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Text(
              value.isEmpty ? label : value,
              style: TextStyle(
                fontSize: 12,
                color: value.isEmpty
                    ? const Color(0xFF9CA3AF)
                    : const Color(0xFF111827),
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.calendar_today_outlined,
              size: 14,
              color: Color(0xFF9CA3AF),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: _toggleDateFilter,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _expanded ? 'Date range' : '$_from – $_to',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: _expanded ? 11 : 13,
                          fontWeight:
                              _expanded ? FontWeight.w600 : FontWeight.w700,
                          color: _expanded
                              ? const Color(0xFF9CA3AF)
                              : const Color(0xFF111827),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _dateField(
                      label: 'From',
                      value: _draftFrom,
                      onPick: () => _pickDate(isFrom: true),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      'to',
                      style:
                          TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                    ),
                  ),
                  Expanded(
                    child: _dateField(
                      label: 'To',
                      value: _draftTo,
                      onPick: () => _pickDate(isFrom: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              StockFlowButton(
                label: 'Apply',
                loading: _loading,
                onPressed: _applyRange,
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      activePath: '/admin/analytics',
      body: Column(
        children: [
          const BackHeader(title: 'Item-wise Analytics'),
          _dateFilterBar(),
          if (_loading && _data != null)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading && _data == null) {
      return const PageLoading(label: 'Loading item analytics...');
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Could not load item analytics',
        subtitle: _error,
        action: Align(
          child: StockFlowButton(
            label: 'Retry',
            expand: false,
            onPressed: _fetch,
          ),
        ),
      );
    }
    final data = _data;
    if (data == null) return const PageLoading();

    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 40),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Text(
            'From $_from to $_to',
            style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
          ),
          const SizedBox(height: 10),
          _summaryRow(data.summary),
          const SizedBox(height: 8),
          _sortBar(),
          const SizedBox(height: 4),
          _reportCard(
            title: 'Sales by Category',
            firstColumn: 'CATEGORY',
            rows: _sorted(data.categories),
            totalPieces: data.summary.totalPieces,
            totalSales: data.summary.totalSales ?? 0,
            emptyText: 'No category sales in range',
          ),
          _reportCard(
            title: 'Sales by Fabric',
            firstColumn: 'FABRIC',
            rows: _sorted(data.fabrics),
            totalPieces: data.summary.totalPieces,
            totalSales: data.summary.totalSales ?? 0,
            emptyText: 'No fabric sales in range',
          ),
        ],
      ),
    );
  }

  List<ItemSalesRow> _sorted(List<ItemSalesRow> rows) {
    final sorted = [...rows];
    sorted.sort((a, b) {
      final aValue =
          _sortBy == _SortBy.sales ? (a.sales ?? 0) : a.pieces;
      final bValue =
          _sortBy == _SortBy.sales ? (b.sales ?? 0) : b.pieces;
      final byMetric = bValue.compareTo(aValue);
      if (byMetric != 0) return byMetric;
      return a.name.compareTo(b.name);
    });
    return sorted;
  }

  Widget _summaryRow(ItemSalesSummary summary) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _summaryTile(
              value: NumberFormat.decimalPattern('en_IN')
                  .format(summary.totalPieces),
              label: 'Total Pieces',
            ),
          ),
          Expanded(
            child: _summaryTile(
              value: formatInrInt(summary.totalSales ?? 0),
              label: 'Total Sales',
            ),
          ),
          Expanded(
            child: _summaryTile(
              value: '${summary.distinctItems}',
              label: 'Items Sold',
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryTile({required String value, required String label}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2563EB),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sortBar() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.end,
      children: [
        const Text(
          'Sort by',
          style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
        ),
        for (final option in _SortBy.values)
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => setState(() => _sortBy = option),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _sortBy == option
                    ? AppColors.primary
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                option == _SortBy.sales ? 'Sales amount' : 'Pieces sold',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _sortBy == option
                      ? Colors.white
                      : const Color(0xFF6B7280),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _reportCard({
    required String title,
    required String firstColumn,
    required List<ItemSalesRow> rows,
    required int totalPieces,
    required double totalSales,
    required String emptyText,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            SizedBox(
              height: 70,
              child: Center(
                child: Text(
                  emptyText,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ),
            )
          else ...[
            _tableHeader(firstColumn),
            const SizedBox(height: 2),
            for (final row in rows)
              _tableRow(
                name: row.name,
                pieces: row.pieces,
                sales: row.sales ?? 0,
              ),
            const Divider(height: 20),
            _tableRow(
              name: 'Total',
              pieces: totalPieces,
              sales: totalSales,
              bold: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _tableHeader(String firstColumn) {
    const style = TextStyle(
      fontSize: 9,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
      color: Color(0xFF9CA3AF),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(firstColumn, style: style),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 3,
            child: Text(
              'PIECES',
              textAlign: TextAlign.right,
              style: style,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 4,
            child: Text(
              'SALES',
              textAlign: TextAlign.right,
              style: style,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableRow({
    required String name,
    required int pieces,
    required double sales,
    bool bold = false,
  }) {
    final style = TextStyle(
      fontSize: 12,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
      color: bold ? const Color(0xFF111827) : const Color(0xFF374151),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 3,
            child: FittedBox(
              alignment: Alignment.centerRight,
              fit: BoxFit.scaleDown,
              child: Text(
                NumberFormat.decimalPattern('en_IN').format(pieces),
                style: style,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 4,
            child: FittedBox(
              alignment: Alignment.centerRight,
              fit: BoxFit.scaleDown,
              child: Text(formatInrInt(sales), style: style),
            ),
          ),
        ],
      ),
    );
  }
}
