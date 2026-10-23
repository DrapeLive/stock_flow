import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';

class AnalyticsDateRangeBar extends StatefulWidget {
  const AnalyticsDateRangeBar({
    super.key,
    required this.from,
    required this.to,
    required this.onApply,
    this.busy = false,
  });

  final String from;
  final String to;
  final Future<bool> Function(String from, String to) onApply;
  final bool busy;

  @override
  State<AnalyticsDateRangeBar> createState() => _AnalyticsDateRangeBarState();
}

class _AnalyticsDateRangeBarState extends State<AnalyticsDateRangeBar> {
  late String _appliedFrom;
  late String _appliedTo;
  late String _draftFrom;
  late String _draftTo;
  bool _expanded = true;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    _appliedFrom = widget.from;
    _appliedTo = widget.to;
    _draftFrom = widget.from;
    _draftTo = widget.to;
  }

  @override
  void didUpdateWidget(covariant AnalyticsDateRangeBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.from != widget.from || oldWidget.to != widget.to) {
      _appliedFrom = widget.from;
      _appliedTo = widget.to;
      _draftFrom = widget.from;
      _draftTo = widget.to;
    }
  }

  void _toggleExpanded() {
    if (_applying) return;
    setState(() {
      _expanded = !_expanded;
      _draftFrom = _appliedFrom;
      _draftTo = _appliedTo;
    });
  }

  Future<void> _apply() async {
    if (_applying || widget.busy) return;
    if (_draftFrom.isEmpty || _draftTo.isEmpty) return;
    setState(() => _applying = true);
    final applied = await widget.onApply(_draftFrom, _draftTo);
    if (!mounted) return;
    setState(() {
      _applying = false;
      if (applied) {
        _appliedFrom = _draftFrom;
        _appliedTo = _draftTo;
        _expanded = false;
      }
    });
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final current = isFrom ? _draftFrom : _draftTo;
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(current) ?? now,
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

  @override
  Widget build(BuildContext context) {
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
              onTap: _toggleExpanded,
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
                        _expanded
                            ? 'Date range'
                            : '$_appliedFrom – $_appliedTo',
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
                loading: _applying,
                enabled: !widget.busy,
                onPressed: _apply,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
