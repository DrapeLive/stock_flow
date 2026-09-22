import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/perf.dart';
import '../../core/utils/text_symbols.dart';
import '../../data/repositories.dart';
import '../../models/models.dart';
import '../../shared/admin_shell.dart';
import '../../shared/widgets.dart';

enum _Preset { today, sevenDays, thirtyDays, custom }

const _statusColors = <String, Color>{
  'draft': Color(0xFF9CA3AF),
  'pending': Color(0xFFEAB308),
  'editing': Color(0xFFF97316),
  'packed': Color(0xFFA855F7),
  'dispatched': Color(0xFF22C55E),
};

const _statusLabels = <String, String>{
  'draft': 'Draft',
  'pending': 'Pending',
  'editing': 'Editing',
  'packed': 'Packed',
  'dispatched': 'Dispatched',
};

/// Mirrors `app/(admin)/admin/analytics/page.tsx` plus its chart components.
/// Charts are drawn with plain Flutter widgets (no chart lib) to keep the
/// exact colors/ordering of the recharts versions.
class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  _Preset _preset = _Preset.thirtyDays;
  String _from = '';
  String _to = '';
  String _customFrom = '';
  String _customTo = '';
  AnalyticsData? _data;
  bool _loading = true;
  bool _refetching = false;
  bool _valueUnlocked = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final to = DateFormat('y-MM-dd').format(now);
    final from = DateFormat('y-MM-dd').format(now.subtract(const Duration(days: 30)));
    _from = from;
    _to = to;
    Perf.start('analytics');
    _fetch(from, to);
  }

  void _applyPreset(_Preset p) {
    setState(() => _preset = p);
    if (p == _Preset.custom) return;
    final now = DateTime.now();
    final to = DateFormat('y-MM-dd').format(now);
    String from = to;
    if (p == _Preset.sevenDays) {
      from = DateFormat('y-MM-dd').format(now.subtract(const Duration(days: 7)));
    } else if (p == _Preset.thirtyDays) {
      from = DateFormat('y-MM-dd').format(now.subtract(const Duration(days: 30)));
    }
    _from = from;
    _to = to;
    _fetch(from, to);
  }

  void _applyCustom() {
    if (_customFrom.isEmpty && _customTo.isEmpty) return;
    final todayStr = DateFormat('y-MM-dd').format(DateTime.now());
    final threeMonths = DateFormat('y-MM-dd')
        .format(DateTime.now().subtract(const Duration(days: 90)));
    final finalFrom = _customFrom.isEmpty ? threeMonths : _customFrom;
    final finalTo = _customTo.isEmpty ? todayStr : _customTo;
    _from = finalFrom;
    _to = finalTo;
    _fetch(finalFrom, finalTo);
  }

  Future<void> _fetch(String from, String to) async {
    setState(() {
      _refetching = true;
    });
    try {
      final data = await repos.dashboard.analytics(from, to);
      if (mounted) {
        setState(() {
          _data = data;
          _loading = false;
          _refetching = false;
        });
        Perf.end('analytics', 'TTC');
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _refetching = false;
        });
      }
    }
  }

  Future<void> _unlockValues() async {
    if (_valueUnlocked) return;
    final pin = await PinDialog.show(context,
        title: 'Unlock Analytics',
        message: 'Enter your 6-digit PIN to view the totals');
    if (pin == null) return;
    try {
      await repos.auth.verifyPin(pin.trim());
      if (!mounted) return;
      setState(() => _valueUnlocked = true);
    } catch (e) {
      if (mounted) {
        AppToast.error(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      activePath: '/admin/analytics',
      title: 'Analytics',
      titleTrailing: _refetching
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2))
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _presetBar(),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _presetBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              for (final p in _Preset.values)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => _applyPreset(p),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _preset == p
                              ? AppColors.primary
                              : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          p == _Preset.today
                              ? 'Today'
                              : p == _Preset.sevenDays
                                  ? '7d'
                                  : p == _Preset.thirtyDays
                                      ? '30d'
                                      : 'Custom',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _preset == p
                                ? Colors.white
                                : const Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (_preset == _Preset.custom)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _dateField(
                            label: 'From',
                            value: _customFrom,
                            onPick: () async {
                              final d = await _pickDate(_customFrom);
                              if (d != null) {
                                setState(() => _customFrom = d);
                              }
                            }),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text('to',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF9CA3AF))),
                      ),
                      Expanded(
                        child: _dateField(
                            label: 'To',
                            value: _customTo,
                            onPick: () async {
                              final d = await _pickDate(_customTo);
                              if (d != null) {
                                setState(() => _customTo = d);
                              }
                            }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: StockFlowButton(
                          label: 'Apply',
                          expand: false,
                          enabled: _customFrom.isNotEmpty || _customTo.isNotEmpty,
                          onPressed: _applyCustom,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: StockFlowButton(
                          label: 'Clear',
                          expand: false,
                          enabled: _customFrom.isNotEmpty || _customTo.isNotEmpty,
                          onPressed: () => setState(() {
                            _customFrom = '';
                            _customTo = '';
                          }),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<String?> _pickDate(String current) async {
    final now = DateTime.now();
    final initial = current.isNotEmpty
        ? DateTime.tryParse(current)
        : null;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
    );
    return picked == null ? null : DateFormat('y-MM-dd').format(picked);
  }

  Widget _dateField(
      {required String label,
      required String value,
      required VoidCallback onPick}) {
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
            const Icon(Icons.calendar_today_outlined,
                size: 14, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading && _data == null) return const PageLoading();
    final data = _data;
    if (data == null) {
      return EmptyState(
        icon: Icons.bar_chart,
        title: 'Could not load analytics',
        subtitle: 'Check your connection and retry.',
        action: Align(
          child: StockFlowButton(
            label: 'Retry',
            onPressed: () => _fetch(_from, _to),
            expand: false,
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _fetch(_from, _to),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 40),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _donutCard(data.kpis),
          _valueCards(data.kpis),
          _trendCard(data.trend),
          _timeMetricsCard(data.timeMetrics),
          _topCard('Top Customers',
              rows: data.topCustomers, color: const Color(0xFF3B82F6)),
          _topCard('Top Agents',
              rows: data.topAgents, color: const Color(0xFF3B82F6)),
          _topItemsCard(data.topItems),
        ],
      ),
    );
  }

  // ── Cards ─────────────────────────────────────────────────────────────────

  Widget _donutCard(AnalyticsKpis kpis) {
    final segments = <({String key, int value})>[
      (key: 'draft', value: kpis.draft),
      (key: 'pending', value: kpis.pending),
      (key: 'editing', value: kpis.editing),
      (key: 'packed', value: kpis.packed),
      (key: 'dispatched', value: kpis.dispatched),
    ].where((s) => s.value > 0).toList();
    final total = segments.fold<int>(0, (s, e) => s + e.value);

    return _card(
      title: 'Order Status',
      child: total == 0
          ? const _EmptyCardBody('No data in range')
          : Column(
              children: [
                SizedBox(
                  height: 170,
                  width: double.infinity,
                  child: _DonutPainter(segments: segments, total: total),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final s in segments)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: _statusColors[s.key] ?? const Color(0xFF3B82F6),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${_statusLabels[s.key]}: ${s.value}',
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF6B7280)),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _valueCards(AnalyticsKpis kpis) {
    final value = kpis.totalValue ?? 0;
    final sets = kpis.totalSets ?? 0;
    final pieces = kpis.totalPieces ?? 0;
    final setsFormat = NumberFormat.decimalPattern('en_IN');
    const masked = '$kBullet$kBullet$kBullet$kBullet';
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _KpiTile(
              valueText: _valueUnlocked ? formatInrInt(value) : masked,
              label: 'Total Order Value',
              locked: !_valueUnlocked,
              onUnlock: _unlockValues,
            ),
          ),
          Expanded(
            child: _KpiTile(
              valueText: _valueUnlocked ? setsFormat.format(sets) : masked,
              label: 'Total Sets Ordered',
              subtext: _valueUnlocked ? formatPieces(pieces) : null,
              locked: !_valueUnlocked,
              onUnlock: _unlockValues,
            ),
          ),
        ],
      ),
    );
  }

  Widget _trendCard(List<TrendPoint> trend) {
    return _card(
      title: 'Orders Trend',
      child: trend.isEmpty
          ? const _EmptyCardBody('No order activity in this period')
          : SizedBox(
              // `width: double.infinity` is REQUIRED: a childless CustomPaint
              // with loose width collapses to width 0 (constraints.smallest),
              // so _TrendPainterP.paint bails on `size.width <= 0` and the
              // chart renders as a blank white box. The donut card sets width
              // explicitly; the trend card previously did not.
              width: double.infinity,
              height: 80,
              child: _TrendPainter(points: trend, from: _from, to: _to),
            ),
    );
  }

  Widget _timeMetricsCard(TimeMetrics? metrics) {
    final m = metrics ?? const TimeMetrics();
    final cards = [
      (
        label: 'Avg Dispatch',
        value: m.avgDispatchHours == null
            ? kEmDash
            : m.avgDispatchHours!.toStringAsFixed(1),
        unit: m.avgDispatchHours != null ? 'hrs' : '',
      ),
      (
        label: 'Median Dispatch',
        value: m.medianDispatchHours == null
            ? kEmDash
            : m.medianDispatchHours!.toStringAsFixed(1),
        unit: m.medianDispatchHours != null ? 'hrs' : '',
      ),
      (
        label: 'Within 24h',
        value: m.dispatchedWithin24hPct == null
            ? kEmDash
            : '${m.dispatchedWithin24hPct!.round()}%',
        unit: '',
      ),
    ];
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final c in cards)
            Expanded(
              child: _KpiTile(
                valueText: c.value,
                label: c.label,
                unit: c.unit,
                centered: true,
              ),
            ),
        ],
      ),
    );
  }

  Widget _topCard(String title,
      {required List<LeaderboardEntry> rows, required Color color}) {
    if (rows.isEmpty) {
      return _card(title: title, child: const _EmptyCardBody('No data in range'));
    }
    final max = rows.fold<int>(0, (s, r) => math.max(s, r.count ?? 0));
    return _card(
      title: title,
      child: Column(
        children: [
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 82,
                    child: Text(
                      _truncate(r.name ?? '', 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF4B5563))),
                  ),
                  Expanded(
                    child: Container(
                      height: 16,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: max == 0 ? 0 : (r.count ?? 0) / max,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${r.count}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827))),
                ],
              ),
            ),
          if (title == 'Top Customers' && rows.length >= 3)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Top 3 customers account for ${_topThreePct(rows)}% of all orders',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF9CA3AF)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  int _topThreePct(List<LeaderboardEntry> rows) {
    final total = rows.fold<int>(0, (s, r) => s + (r.count ?? 0));
    if (total == 0) return 0;
    final top3 = rows
        .take(3)
        .fold<int>(0, (s, r) => s + (r.count ?? 0));
    return (top3 * 100 / total).round();
  }

  Widget _topItemsCard(List<LeaderboardEntry> items) {
    if (items.isEmpty) {
      return _card(title: 'Top Items', child: const _EmptyCardBody('No data in range'));
    }
    final max = items.fold<int>(0, (s, r) => math.max(s, r.count ?? 0));
    return _card(
      title: 'Top Items',
      child: SizedBox(
        height: 130,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final r in items)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('${r.count}',
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827))),
                      const SizedBox(height: 4),
                      Container(
                        height: max == 0
                            ? 2
                            : 60 * ((r.count ?? 0) / max).clamp(0.02, 1.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFFA855F7),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _truncate(r.name ?? '', 7),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 9, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
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
          Text(title.toUpperCase(),
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: Color(0xFF9CA3AF))),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  String _truncate(String s, int max) =>
      s.length > max ? '${s.substring(0, max)}...' : s;
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.valueText,
    required this.label,
    this.unit,
    this.subtext,
    this.centered = false,
    this.locked = false,
    this.onUnlock,
  });

  final String valueText;
  final String label;
  final String? unit;
  final String? subtext;
  final bool centered;
  final bool locked;
  final VoidCallback? onUnlock;

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      margin: const EdgeInsets.fromLTRB(2, 0, 2, 12),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: locked ? const Color(0xFFFEF3C7) : AppColors.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: valueText,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: locked
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFF2563EB),
                    ),
                  ),
                  if (unit != null && unit!.isNotEmpty)
                    TextSpan(
                      text: ' $unit',
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF2563EB)),
                    ),
                ],
              ),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: Color(0xFF9CA3AF),
            ),
          ),
          if (locked) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline, size: 12, color: Color(0xFFB45309)),
                  SizedBox(width: 4),
                  Flexible(
                    child: Text('Tap to unlock',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFB45309))),
                  ),
                ],
              ),
            ),
          ] else if (subtext != null)
            Text(
              subtext!,
              style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
            ),
        ],
      ),
    );
    if (locked && onUnlock != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onUnlock,
          child: tile,
        ),
      );
    }
    return tile;
  }
}

class _EmptyCardBody extends StatelessWidget {
  const _EmptyCardBody(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 70,
      child: Center(
        child: Text(text,
            style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
      ),
    );
  }
}

class _DonutPainter extends StatelessWidget {
  const _DonutPainter({required this.segments, required this.total});
  final List<({String key, int value})> segments;
  final int total;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _DonutPainterP(segments, total));
  }
}

class _DonutPainterP extends CustomPainter {
  _DonutPainterP(this.segments, this.total);
  final List<({String key, int value})> segments;
  final int total;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 4;
    if (segments.isEmpty) return;

    final strokeWidth = radius * 0.55;
    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    var startAngle = -math.pi / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    for (final s in segments) {
      final sweep = (s.value / total) * 2 * math.pi;
      paint.color = _statusColors[s.key] ?? const Color(0xFF3B82F6);
      canvas.drawArc(rect, startAngle, sweep - 0.02, false, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainterP oldDelegate) =>
      oldDelegate.segments != segments || oldDelegate.total != total;
}

class _TrendPainter extends StatelessWidget {
  const _TrendPainter({required this.points, required this.from, required this.to});
  final List<TrendPoint> points;
  final String from;
  final String to;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _TrendPainterP(points, from, to));
  }
}

class _TrendPainterP extends CustomPainter {
  _TrendPainterP(this.points, this.from, this.to);
  final List<TrendPoint> points;
  final String from;
  final String to;

  @override
  void paint(Canvas canvas, Size size) {
    final map = <String, int>{
      for (final p in points)
        if (p.day != null && p.count != null) p.day!: p.count!,
    };
    final start = DateTime.tryParse(from);
    final end = DateTime.tryParse(to);
    if (start == null || end == null) return;
    final filled = <({String day, int count})>[];
    for (var d = start;
        !d.isAfter(end);
        d = d.add(const Duration(days: 1))) {
      final key = DateFormat('y-MM-dd').format(d);
      filled.add((day: key, count: map[key] ?? 0));
    }
    if (filled.isEmpty) return;
    if (size.width <= 0 || size.height <= 0) return;

    final max = filled.fold<int>(0, (s, e) => math.max(s, e.count));
    final min = filled.fold<int>(filled.first.count, (s, e) => math.min(s, e.count));
    final range = math.max(1, max - min);

    final offset = 4.0;

    // X axis labels (first / middle / last, "mmm d")
    final labelStyle = const TextStyle(fontSize: 8, color: Color(0xFF9CA3AF));
    void label(int i, double dx) {
      final d = filled[i].day;
      final txt = TextPainter(
        text: TextSpan(
            text: DateFormat('MMM d').format(DateTime.parse(d)), style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      var x = dx - txt.width / 2;
      x = x.clamp(0, math.max(0, size.width - txt.width));
      txt.paint(canvas, Offset(x, size.height - 12));
    }

    double valueY(int count) =>
        offset + (size.height - 2 * offset) * (1 - (count - min) / range);

    // Single-day range (e.g. the "Today" preset): `stepX` would divide by
    // `filled.length - 1 == 0` and produce NaN points; draw a flat line
    // spanning the canvas instead.
    if (filled.length == 1) {
      final y = valueY(filled.first.count);
      final flat = Path()
        ..moveTo(0, y)
        ..lineTo(size.width, y);
      canvas.drawPath(
        Path.from(flat)
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close(),
        Paint()..color = const Color(0xFF3B82F6).withValues(alpha: 0.10),
      );
      canvas.drawPath(
        flat,
        Paint()
          ..color = const Color(0xFF3B82F6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
      label(0, size.width / 2);
      return;
    }

    final stepX = size.width / (filled.length - 1);
    final pts = <Offset>[
      for (var i = 0; i < filled.length; i++)
        Offset(
          i * stepX,
          valueY(filled[i].count),
        ),
    ];

    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      line.lineTo(p.dx, p.dy);
    }

    final area = Path.from(line)
      ..lineTo(pts.last.dx, size.height)
      ..lineTo(pts.first.dx, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()..color = const Color(0xFF3B82F6).withValues(alpha: 0.10),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = const Color(0xFF3B82F6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    final mid = filled.length ~/ 2;
    label(0, pts.first.dx);
    label(mid, pts[mid].dx);
    label(filled.length - 1, pts.last.dx);
  }

  @override
  bool shouldRepaint(covariant _TrendPainterP oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.from != from ||
      oldDelegate.to != to;
}