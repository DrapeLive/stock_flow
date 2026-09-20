import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/cache/app_cache.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/perf.dart';
import '../../data/repositories.dart';
import '../../models/models.dart';
import '../../shared/admin_shell.dart';
import '../../shared/widgets.dart';

enum _UsersTab { customers, agents }

/// Mirrors `app/(admin)/admin/users/page.tsx` — tabbed Customers / Agents
/// lists (Admins tab omitted: superuser-only).
class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  _UsersTab _tab = _UsersTab.customers;

  @override
  void initState() {
    super.initState();
    final saved = AppCache.prefs.get('adminUsersActiveTab') as String?;
    _tab = saved == 'Agents' ? _UsersTab.agents : _UsersTab.customers;
  }

  void _select(_UsersTab t) {
    setState(() => _tab = t);
    AppCache.prefs.put(
        'adminUsersActiveTab', t == _UsersTab.agents ? 'Agents' : 'Customers');
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      activePath: '/admin/users',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 10),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  for (final t in _UsersTab.values)
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => _select(t),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _tab == t ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            t == _UsersTab.customers ? 'Customers' : 'Agents',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _tab == t ? Colors.white : AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _tab == _UsersTab.customers
                ? const _CustomersTab()
                : const _AgentsTab(),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Customers tab — mirrors `CustomersList.tsx`
// ---------------------------------------------------------------------------

class _CustomersTab extends ConsumerStatefulWidget {
  const _CustomersTab();

  @override
  ConsumerState<_CustomersTab> createState() => _CustomersTabState();
}

class _CustomersTabState extends ConsumerState<_CustomersTab> {
  List<Customer> _customers = const [];
  bool _loading = true;
  String _search = '';
  Timer? _debounce;
  int _page = 1;
  int _total = 0;

  static const _pageSize = 50;

  @override
  void initState() {
    super.initState();
    Perf.start('users:customers');
    _fetch();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    try {
      final page = await repos.customer.list(
          page: _page, pageSize: _pageSize, search: _search);
      if (!mounted) return;
      setState(() {
        _customers = page.results;
        _total = page.count;
        _loading = false;
      });
      Perf.end('users:customers', 'TTC');
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearch(String v) {
    setState(() => _search = v);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _page = 1);
      _fetch();
    });
  }

  bool get _hasNext => _total > _page * _pageSize;

  @override
  Widget build(BuildContext context) {
    if (_loading && _customers.isEmpty) return const PageLoading();
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _loading = true);
        await _fetch();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Customers',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827))),
                ),
                StockFlowButton(
                  label: 'Add Customer',
                  expand: false,
                  icon: const Icon(Icons.add, size: 16),
                  onPressed: () => context.push('/admin/users/customers/new'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: 'Search customers...',
                hintStyle: const TextStyle(
                    fontSize: 13, color: Color(0xFF9CA3AF)),
                prefixIcon: const Icon(Icons.search, size: 18),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFFE5E7EB))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFFE5E7EB))),
              ),
            ),
          ),
          if (_customers.isEmpty && !_loading)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(
                child: Text(
                  _search.isNotEmpty ? 'No matching customers' : 'No Customers',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF9CA3AF)),
                ),
              ),
            ),
          for (final c in _customers) _customerTile(c),
          if (_hasNext)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() => _page += 1);
                    _fetch();
                  },
                  child: const Text('Show More'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _customerTile(Customer c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push('/admin/users/customers/${c.id}'),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF3F4F6)),
            ),
            child: Row(
              children: [
                StockflowAvatar(id: c.id, name: c.name),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827))),
                      const SizedBox(height: 2),
                      Text(
                        (c.address?.isNotEmpty ?? false)
                            ? c.address!
                            : 'No address provided',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF9CA3AF)),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(6),
                          border:
                              Border.all(color: const Color(0xFFF3F4F6)),
                        ),
                        child: Text(
                          '${c.agentName ?? '—'}  •  AGENT',
                          style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.info_outline,
                    size: 18, color: Color(0xFFE5E7EB)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Agents tab — mirrors `AgentsList.tsx`
// ---------------------------------------------------------------------------

class _AgentsTab extends ConsumerStatefulWidget {
  const _AgentsTab();

  @override
  ConsumerState<_AgentsTab> createState() => _AgentsTabState();
}

class _AgentsTabState extends ConsumerState<_AgentsTab> {
  List<Agent> _agents = const [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    Perf.start('users:agents');
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final agents = await repos.agent.list();
      if (!mounted) return;
      setState(() {
        _agents = agents;
        _loading = false;
      });
      Perf.end('users:agents', 'TTC');
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Agent> get _filtered {
    final q = _search.toLowerCase();
    if (q.isEmpty) return _agents;
    return _agents
        .where((a) =>
            a.displayName.toLowerCase().contains(q) ||
            a.user.username?.toLowerCase().contains(q) == true)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _agents.isEmpty) return const PageLoading();
    if (_agents.isEmpty) {
      return EmptyState(
        icon: Icons.people_outline,
        title: 'No Agents',
        action: StockFlowButton(
          label: 'Add Agent',
          expand: false,
          icon: const Icon(Icons.add, size: 16),
          onPressed: () => context.push('/admin/users/agents/new'),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _loading = true);
        await _fetch();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          if (_loading)
            const LinearProgressIndicator(minHeight: 2),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Agents',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827))),
                ),
                StockFlowButton(
                  label: 'Add Agent',
                  expand: false,
                  icon: const Icon(Icons.add, size: 16),
                  onPressed: () => context.push('/admin/users/agents/new'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search agents...',
                hintStyle: const TextStyle(
                    fontSize: 13, color: Color(0xFF9CA3AF)),
                prefixIcon: const Icon(Icons.search, size: 18),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFFE5E7EB))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFFE5E7EB))),
              ),
            ),
          ),
          if (_filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(
                child: Text('No matching agents',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF9CA3AF))),
              ),
            ),
          for (final a in _filtered) _agentTile(a),
        ],
      ),
    );
  }

  Widget _agentTile(Agent a) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push('/admin/users/agents/${a.id}'),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF3F4F6)),
            ),
            child: Row(
              children: [
                StockflowAvatar(id: a.id, name: a.displayName),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827))),
                      const SizedBox(height: 2),
                      Text(a.user.email ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF9CA3AF))),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: AppColors.primary
                                  .withValues(alpha: 0.15)),
                        ),
                        child: Text(
                          '+91 ${a.contact ?? ''}',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    children: [
                      const Text('CLIENTS',
                          style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                              color: Color(0xFFE5E7EB))),
                      const SizedBox(height: 2),
                      Text(
                        a.totalCustomers ?? '0',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827)),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.info_outline,
                    size: 18, color: Color(0xFFE5E7EB)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}