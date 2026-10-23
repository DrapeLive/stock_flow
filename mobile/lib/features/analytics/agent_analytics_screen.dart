import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/repositories.dart';
import '../../models/models.dart';
import '../../shared/admin_shell.dart';
import '../../shared/widgets.dart';
import 'analytics_date_range_bar.dart';

class AgentAnalyticsScreen extends ConsumerStatefulWidget {
  const AgentAnalyticsScreen({super.key, this.from = '', this.to = ''});

  final String from;
  final String to;

  @override
  ConsumerState<AgentAnalyticsScreen> createState() =>
      _AgentAnalyticsScreenState();
}

class _AgentAnalyticsScreenState extends ConsumerState<AgentAnalyticsScreen> {
  String _from = '';
  String _to = '';

  AgentAnalyticsData? _data;
  String? _error;
  bool _loading = false;
  bool _unlocked = false;
  bool _promptingPin = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateFormat('y-MM-dd').format(now);
    final thirtyDaysAgo = DateFormat('y-MM-dd')
        .format(now.subtract(const Duration(days: 30)));
    _from = widget.from.isNotEmpty ? widget.from : thirtyDaysAgo;
    _to = widget.to.isNotEmpty ? widget.to : today;
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestPin());
  }

  Future<bool> _applyRange(String from, String to) async {
    if (!_unlocked) {
      await _requestPin();
      if (!_unlocked) return false;
    }
    _from = from;
    _to = to;
    await _fetch();
    return mounted && _data != null && _error == null;
  }

  Future<void> _requestPin() async {
    if (!mounted || _unlocked || _promptingPin) return;
    setState(() => _promptingPin = true);
    final pin = await PinDialog.show(
      context,
      title: 'Agent Analytics',
      message: 'Enter your 6-digit PIN to view agent-wise analytics',
    );
    if (!mounted) return;
    setState(() => _promptingPin = false);
    if (pin == null) return;
    try {
      await repos.auth.verifyPin(pin.trim());
      if (!mounted) return;
      setState(() => _unlocked = true);
      await _fetch();
    } catch (e) {
      if (mounted) {
        AppToast.error(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _fetch() async {
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
      if (!data.hasAgentAnalytics) {
        throw Exception(
          'Agent analytics is unavailable from the server. '
          'Deploy the updated backend and retry.',
        );
      }
      if (!mounted) return;
      setState(() {
        _data = data.agentAnalytics;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      activePath: '/admin/analytics',
      body: Column(
        children: [
          const BackHeader(title: 'Agent Analytics'),
          if (_unlocked)
            AnalyticsDateRangeBar(
              from: _from,
              to: _to,
              busy: _loading,
              onApply: _applyRange,
            ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (!_unlocked) {
      return EmptyState(
        icon: Icons.lock_outline,
        title: 'PIN required',
        subtitle: 'Enter your PIN to view agent-wise analytics.',
        action: Align(
          child: StockFlowButton(
            label: 'Enter PIN',
            expand: false,
            onPressed: _requestPin,
          ),
        ),
      );
    }
    if (_loading && _data == null) return const PageLoading();
    if (_error != null && _data == null) {
      return EmptyState(
        icon: Icons.bar_chart,
        title: 'Could not load agent analytics',
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
          const SizedBox(height: 6),
          const Text(
            'Orders without an assigned agent are excluded.',
            style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
          ),
          _agentList(data.agents),
        ],
      ),
    );
  }

  Widget _summaryRow(AgentAnalyticsSummary summary) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _summaryTile(
              value: '${summary.agents}',
              label: 'Agents',
            ),
          ),
          Expanded(
            child: _summaryTile(
              value: '${summary.orders}',
              label: 'Orders',
            ),
          ),
          Expanded(
            child: _summaryTile(
              value: formatInrInt(summary.orderAmount ?? 0),
              label: 'Order Amount',
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

  Widget _agentList(List<AgentAnalyticsRow> agents) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AGENTS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(height: 10),
          if (agents.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No agent activity in range',
                style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
              ),
            )
          else
            for (var i = 0; i < agents.length; i++) ...[
              if (i > 0) const Divider(height: 20),
              _agentRow(agents[i]),
            ],
        ],
      ),
    );
  }

  Widget _agentRow(AgentAnalyticsRow agent) {
    final name = agent.username ?? '';
    return Row(
      children: [
        StockflowAvatar(id: agent.id ?? 0, name: name, radius: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${agent.orders} ${agent.orders == 1 ? 'order' : 'orders'}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          formatInrInt(agent.orderAmount ?? 0),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
      ],
    );
  }
}
