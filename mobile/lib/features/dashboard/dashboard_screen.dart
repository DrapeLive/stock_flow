import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/cache/app_cache.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/order_packing.dart';
import '../../core/utils/perf.dart';
import '../../core/utils/status_maps.dart';
import '../../data/repositories.dart';
import '../../models/models.dart';
import '../../providers.dart';
import '../../shared/admin_shell.dart';
import '../../shared/widgets.dart';

enum AdminTab { all, pending, packed, dispatched }

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  AdminTab _tab = AdminTab.pending;
  final Map<AdminTab, int> _pageByTab = {};
  List<Agent> _agents = const [];
  Set<int> _viewedIds = const {};
  List<({int id, String status})> _allIds = const [];
  bool _showUnreadOnly = false;
  bool _showFilters = false;
  String _search = '';
  String _debouncedSearch = '';
  String _from = '';
  String _to = '';
  int? _agentFilter;
  int? _customerFilter;
  List<SimpleCustomer> _customers = [];
  Timer? _searchDebounce;

  /// One ticker shared by every unread card's [PulsingDot] instead of one
  /// controller per card. Only runs while the list has unread rows, so it
  /// costs nothing (and schedules no frames) otherwise.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  bool _loading = true;
  String? _error;
  int _loadOrdersGen = 0;
  int _loadCountsGen = 0;
  List<Order> _orders = const [];
  int _totalPages = 1;
  final int _pageSize = 50;

  @override
  void initState() {
    super.initState();
    final tabIdx = AppCache.prefs.get('adminOrdersActiveTab') as int? ??
        AdminTab.pending.index;
    _tab = AdminTab.values[tabIdx.clamp(0, AdminTab.values.length - 1)];
    final f = AppCache.prefs.get('admin_filters') as String? ?? '';
    if (f.isNotEmpty) {
      final fields = f.split('&').where((x) => x.isNotEmpty);
      for (final field in fields) {
        final kv = field.split('=');
        if (kv.length != 2) continue;
        if (kv[0] == 'from') _from = kv[1];
        if (kv[0] == 'to') _to = kv[1];
        if (kv[0] == 'agent') _agentFilter = int.tryParse(kv[1]);
        if (kv[0] == 'customer') _customerFilter = int.tryParse(kv[1]);
      }
    }
    _search = AppCache.prefs.get('admin_search') as String? ?? '';
    _debouncedSearch = _search;
    _showUnreadOnly = AppCache.prefs.get('admin_showUnreadOnly') as bool? ?? false;
    Perf.start('dash:counts');
    Perf.start('dash:orders');
    _loadAgents();
    _loadCounts();
    _loadCustomers();
    _loadOrders();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  /// Starts the shared pulse ticker only while some row in the loaded list is
  /// unread and animations are enabled; stops it otherwise.
  void _syncPulse() {
    final disabled = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final anyUnread = _orders.any(
      (o) => o.status != 'DISPATCHED' && !_viewedIds.contains(o.id),
    );
    if (anyUnread && !disabled) {
      if (!_pulse.isAnimating) _pulse.repeat();
    } else if (_pulse.isAnimating) {
      _pulse.stop();
    }
  }

  void _saveTab() => AppCache.prefs.put('adminOrdersActiveTab', _tab.index);

  void _saveSearch(String v) => AppCache.prefs.put('admin_search', v);

  void _saveUnread(bool v) => AppCache.prefs.put('admin_showUnreadOnly', v);

  void _saveFilters() {
    final parts = <String>[
      if (_from.isNotEmpty) 'from=$_from',
      if (_to.isNotEmpty) 'to=$_to',
      if (_agentFilter != null) 'agent=$_agentFilter',
      if (_customerFilter != null) 'customer=$_customerFilter',
    ];
    AppCache.prefs.put('admin_filters', parts.join('&'));
  }

  Future<void> _loadAgents() async {
    try {
      final agents = await repos.agent.list();
      if (mounted) setState(() => _agents = agents);
    } catch (_) {}
  }

  Future<void> _loadCustomers() async {
    try {
      final customers = await repos.customer.list(pageSize: 50);
      final mapped = customers.results
          .map((c) => SimpleCustomer(
              id: c.id, name: c.name, contact: c.contact))
          .toList();
      if (mounted) setState(() => _customers = mapped);
    } catch (_) {}
  }

  Future<void> _loadCounts() async {
    final gen = ++_loadCountsGen;
    try {
      final results = await Future.wait([
        repos.order.getViewedIds(),
        repos.order.allIds(),
      ]);
      final viewed = results[0] as List<int>;
      final allIds = results[1] as List<({int id, String status})>;
      if (mounted && gen == _loadCountsGen) {
        setState(() {
          _viewedIds = viewed.toSet();
          _allIds = allIds;
        });
        Perf.end('dash:counts', 'TTC');
        _syncPulse();
      }
    } catch (_) {}
  }

  List<({int id, String status})> _recordsFor(AdminTab tab) {
    final status = switch (tab) {
      AdminTab.all => null,
      AdminTab.pending => 'PENDING',
      AdminTab.packed => 'PACKED',
      AdminTab.dispatched => 'DISPATCHED',
    };
    return _allIds.where((o) => status == null || o.status == status).toList();
  }

  int _unreadCountFor(AdminTab tab) => _recordsFor(tab)
      .where((o) => o.status != 'DISPATCHED' && !_viewedIds.contains(o.id))
      .length;

  int _countFor(AdminTab tab) {
    if (tab == AdminTab.dispatched) return 0;
    if (_showUnreadOnly) return _unreadCountFor(tab);
    return _recordsFor(tab).length;
  }

  String? get _statusParam {
    switch (_tab) {
      case AdminTab.all:
        return null;
      case AdminTab.pending:
        return 'PENDING';
      case AdminTab.packed:
        return 'PACKED';
      case AdminTab.dispatched:
        return 'DISPATCHED';
    }
  }

  Future<void> _loadOrders() async {
    final gen = ++_loadOrdersGen;
    setState(() {
      _loading = true;
      _error = null;
    });
    final page = _pageByTab[_tab] ?? 1;
    try {
      final res = await repos.order.getAll(OrderFilters(
        page: page,
        pageSize: _pageSize,
        search: _debouncedSearch,
        statuses: [_statusParam].whereType<String>().toList(),
        fromDate: _from.isEmpty ? null : _from,
        toDate: _to.isEmpty ? null : _to,
        agent: _agentFilter,
        customer: _customerFilter,
      ));
      if (mounted && gen == _loadOrdersGen) {
        setState(() {
          _orders =
              res.results.where((o) => o.status != 'DRAFT').toList();
          _totalPages = (res.count / _pageSize).ceil();
          if (_totalPages < 1) _totalPages = 1;
          _loading = false;
        });
        Perf.end('dash:orders', 'TTC');
        _syncPulse();
      }
    } catch (e) {
      if (mounted && gen == _loadOrdersGen) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _switchTab(AdminTab tab) {
    setState(() => _tab = tab);
    _saveTab();
    _loadOrders();
  }

  void _onSearchChanged(String v) {
    setState(() => _search = v);
    _saveSearch(v);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      _debouncedSearch = v;
      _pageByTab[_tab] = 1;
      _loadOrders();
    });
  }

  void _clearFilters() {
    setState(() {
      _showFilters = false;
      _from = '';
      _to = '';
      _agentFilter = null;
      _customerFilter = null;
      _search = '';
      _debouncedSearch = '';
    });
    _pageByTab[_tab] = 1;
    _searchDebounce?.cancel();
    _saveSearch('');
    _saveFilters();
    _loadOrders();
  }

  Future<void> _pickDate(bool isFrom) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = DateFormat('yyyy-MM-dd').format(picked);
      } else {
        _to = DateFormat('yyyy-MM-dd').format(picked);
      }
    });
    _saveFilters();
    _pageByTab[_tab] = 1;
    _loadOrders();
  }

  Future<void> _pickCustomer() async {
    final selected = await showModalBottomSheet<SimpleCustomer>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _CustomerPickerSheet(
        customers: _customers,
        onSearch: (q) async {
          try {
            final res = q.isEmpty
                ? await repos.customer.list(pageSize: 50)
                : await repos.customer.list(pageSize: 50, search: q);
            if (ctx.mounted) {
              return res.results
                  .map((c) => SimpleCustomer(
                      id: c.id, name: c.name, contact: c.contact))
                  .toList();
            }
          } catch (_) {}
          return const <SimpleCustomer>[];
        },
      ),
    );
    if (selected == null) return;
    setState(() => _customerFilter = selected.id);
    _saveFilters();
    _pageByTab[_tab] = 1;
    _loadOrders();
  }

  void _markViewed(Order o) {
    if (o.status == 'DISPATCHED') return;
    repos.order.markViewed(o.id).catchError((_) {});
    setState(() => _viewedIds = {..._viewedIds, o.id});
    AppCache.invalidate('orders');
    _syncPulse();
  }

  @override
  Widget build(BuildContext context) {
    final unread = _countFor(_tab);
    final filteredOrders = _showUnreadOnly
        ? _orders
            .where((o) =>
                o.status != 'DISPATCHED' && !_viewedIds.contains(o.id))
            .toList()
        : _orders;
    final activeTabName = switch (_tab) {
      AdminTab.all => 'All',
      AdminTab.pending => 'Pending',
      AdminTab.packed => 'Packed',
      AdminTab.dispatched => 'Dispatched',
    };
    final bottomPad = 62 + MediaQuery.of(context).padding.bottom + 16;

    return AdminScaffold(
      activePath: '/admin',
      title: 'Orders',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _tabBar(),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$activeTabName${_showUnreadOnly ? ' unread' : ''} orders',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF9CA3AF),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$unread',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.unread,
                  ),
                ),
                const SizedBox(width: 8),
                _UnreadFilterChip(
                  selected: _showUnreadOnly,
                  count: _unreadCountFor(_tab),
                  onTap: () {
                    final v = !_showUnreadOnly;
                    setState(() => _showUnreadOnly = v);
                    _saveUnread(v);
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: _SearchField(
                      value: _search,
                      onChanged: _onSearchChanged,
                      hint: 'Search orders',
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _FilterToggleChip(
                  isOpen: _showFilters,
                  activeCount: activeFilterCount(
                    from: _from,
                    to: _to,
                    agent: _agentFilter,
                    customer: _customerFilter,
                  ),
                  onTap: () {
                    setState(() {
                      if (_showFilters) {
                        _clearFilters();
                      } else {
                        _showFilters = true;
                      }
                    });
                  },
                ),
              ],
            ),
          ),
          if (_showFilters)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _filterPanel(),
            ),
          const SizedBox(height: 4),
          if (_loading && _orders.isNotEmpty)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _loading && _orders.isEmpty
                ? PageLoading(
                    label: 'Loading ${activeTabName.toLowerCase()} orders...')
                : _error != null && _orders.isEmpty
                    ? SingleChildScrollView(
                        child: EmptyState(
                          icon: Icons.cloud_off,
                          title: 'Could not load orders',
                          subtitle: _error,
                          action: Align(
                            child: StockFlowButton(
                              label: 'Retry',
                              onPressed: _loadOrders,
                              expand: false,
                            ),
                          ),
                        ),
                      )
                    : filteredOrders.isEmpty
                        ? EmptyState(
                            icon: Icons.info_outline,
                            title: _showUnreadOnly
                                ? 'No unread orders'
                                : _debouncedSearch.isNotEmpty
                                    ? 'No matching orders'
                                    : switch (_tab) {
                                        AdminTab.all => 'No Data Found',
                                        AdminTab.pending => 'No Pending Orders',
                                        AdminTab.packed => 'No Packed Orders',
                                        AdminTab.dispatched =>
                                          'No Dispatched Orders',
                                      },
                          )
                        : RefreshIndicator(
                            onRefresh: () async => _loadOrders(),
                            child: ListView.builder(
                              padding: EdgeInsets.fromLTRB(8, 8, 8, bottomPad),
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: filteredOrders.length + 1,
                              itemBuilder: (context, i) {
                                if (i == filteredOrders.length) {
                                  return _PaginationBar(
                                    currentPage: _pageByTab[_tab] ?? 1,
                                    totalPages: _totalPages,
                                    onPage: (p) {
                                      setState(() => _pageByTab[_tab] = p);
                                      _loadOrders();
                                    },
                                  );
                                }
                                final o = filteredOrders[i];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _OrderCardView(
                                    order: o,
                                    viewed: o.status == 'DISPATCHED' ||
                                        _viewedIds.contains(o.id),
                                    pulse: _pulse,
                                    onTap: () async {
                                      _markViewed(o);
                                      await context
                                          .push('/admin/order/status/${o.id}');
                                      // Refresh so pack/dispatch changes made on
                                      // the status screen show up on return.
                                      if (!mounted) return;
                                      _loadOrders();
                                      _loadCounts();
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ref.listenManual(connectivityProvider, ((prev, next) {
      if (!_loading && next.valueOrNull == true) {
        _loadOrders();
        _loadCounts();
      }
    }), fireImmediately: false);
  }

  Widget _tabBar() {
    const tabs = [
      AdminTab.all,
      AdminTab.pending,
      AdminTab.packed,
      AdminTab.dispatched
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          for (final t in tabs)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => _switchTab(t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: _tab == t
                          ? AppColors.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        switch (t) {
                          AdminTab.all => 'All',
                          AdminTab.pending => 'Pending',
                          AdminTab.packed => 'Packed',
                          AdminTab.dispatched => 'Dispatched',
                        },
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _tab == t
                              ? Colors.white
                              : const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterPanel() {
    final hasFilters = activeFilterCount(
          from: _from,
          to: _to,
          agent: _agentFilter,
          customer: _customerFilter,
        ) >
        0;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _dateChip(
              label: _from, hint: 'From date', onTap: () => _pickDate(true)),
          const Text('to',
              style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
          _dateChip(label: _to, hint: 'To date', onTap: () => _pickDate(false)),
          const Text('Agent',
              style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
          _agentDropdown(),
          const Text('Customer',
              style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
          _customerChip(),
          if (hasFilters)
            TextButton(
              onPressed: _clearFilters,
              child: const Text('Clear',
                  style: TextStyle(fontSize: 12, color: Color(0xFFEF4444))),
            ),
        ],
      ),
    );
  }

  Widget _dateChip(
      {required String label, required String hint, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 140),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(10),
          color: Colors.white,
        ),
        child: Text(
          label.isEmpty ? hint : label,
          style: TextStyle(
            fontSize: 13,
            color:
                label.isEmpty ? const Color(0xFF9CA3AF) : const Color(0xFF374151),
          ),
        ),
      ),
    );
  }

  Widget _agentDropdown() {
    return Container(
      constraints: const BoxConstraints(minWidth: 140),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(10),
        color: Colors.white,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: _agentFilter,
          isExpanded: true,
          hint: const Text('All Agents',
              style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('All Agents')),
            for (final a in _agents)
              DropdownMenuItem<int?>(
                  value: a.id, child: Text(a.user.username ?? 'Agent ${a.id}')),
          ],
          onChanged: (v) {
            setState(() => _agentFilter = v);
            _saveFilters();
            _pageByTab[_tab] = 1;
            _loadOrders();
          },
        ),
      ),
    );
  }

  Widget _customerChip() {
    final selected = _customers.firstWhere(
      (c) => c.id == _customerFilter,
      orElse: () => const SimpleCustomer(id: 0, name: ''),
    );
    final label = _customerFilter == null
        ? 'All Customers'
        : (selected.id == 0 ? '#$_customerFilter' : selected.name);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: _pickCustomer,
      child: Container(
        constraints: const BoxConstraints(minWidth: 140),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(10),
          color: Colors.white,
        ),
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            color: _customerFilter == null
                ? const Color(0xFF9CA3AF)
                : const Color(0xFF374151),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Search field
// ---------------------------------------------------------------------------

class _SearchField extends StatefulWidget {
  const _SearchField(
      {required this.value, required this.onChanged, required this.hint});
  final String value;
  final ValueChanged<String> onChanged;
  final String hint;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_SearchField old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _controller.text = widget.value;
      if (!_controller.text.isNotEmpty && widget.value.isEmpty) {
        _controller.clear();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
        prefixIcon: const Icon(Icons.search, size: 17, color: Color(0xFF9CA3AF)),
        suffixIcon: widget.value.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close,
                    size: 16, color: Color(0xFF9CA3AF)),
                onPressed: () {
                  _controller.clear();
                  widget.onChanged('');
                },
              ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
              color: AppColors.primary.withValues(alpha: 0.5)),
        ),
      ),
    );
  }
}

class _FilterToggleChip extends StatelessWidget {
  const _FilterToggleChip(
      {required this.isOpen, required this.activeCount, required this.onTap});
  final bool isOpen;
  final int activeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(10),
            color: Colors.white,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isOpen ? 'Hide filters' : 'Show filters',
                maxLines: 1,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.filter_alt_outlined,
                  size: 16, color: Color(0xFF9CA3AF)),
              if (activeCount > 0) ...[
                const SizedBox(width: 5),
                Container(
                  width: 16,
                  height: 16,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD97706),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$activeCount',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _UnreadFilterChip extends StatelessWidget {
  const _UnreadFilterChip(
      {required this.selected, required this.count, required this.onTap});
  final bool selected;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : const Color(0xFF6B7280);
    const green = AppColors.unread;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? green : Colors.white,
          border: Border.all(color: selected ? green : const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected
                  ? Icons.mark_email_unread
                  : Icons.mark_email_unread_outlined,
              size: 15,
              color: fg,
            ),
            const SizedBox(width: 5),
            Text(
              'Unread',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.25)
                      : AppColors.unreadTint,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : green,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CustomerPickerSheet extends StatefulWidget {
  const _CustomerPickerSheet({required this.customers, required this.onSearch});
  final List<SimpleCustomer> customers;
  final Future<List<SimpleCustomer>> Function(String q) onSearch;

  @override
  State<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<_CustomerPickerSheet> {
  List<SimpleCustomer> _items = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _items = widget.customers;
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        child: SizedBox(
          height: 420,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  autofocus: true,
                  onChanged: (q) async {
                    setState(() => _loading = true);
                    final res = await widget.onSearch(q);
                    if (mounted) {
                      setState(() {
                        _items = res;
                        _loading = false;
                      });
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Search customers...',
                    prefixIcon: const Icon(Icons.search,
                        size: 18, color: Color(0xFF9CA3AF)),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        itemCount: _items.length + 1,
                        itemBuilder: (ctx, i) {
                          if (i == 0) {
                            return ListTile(
                              title: const Text('All Customers',
                                  style: TextStyle(fontSize: 14)),
                              onTap: () => Navigator.pop(ctx, null),
                            );
                          }
                          final c = _items[i - 1];
                          return ListTile(
                            title: Text(c.name,
                                style: const TextStyle(fontSize: 14)),
                            subtitle: c.contact == null
                                ? null
                                : Text(c.contact!,
                                    style: const TextStyle(fontSize: 12)),
                            onTap: () => Navigator.pop(ctx, c),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar(
      {required this.currentPage,
      required this.totalPages,
      required this.onPage});
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PageArrowButton(
            icon: Icons.chevron_left,
            enabled: currentPage > 1,
            onTap: () => onPage(currentPage - 1),
          ),
          const SizedBox(width: 8),
          Text(
            'Page $currentPage of $totalPages',
            style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
          ),
          const SizedBox(width: 8),
          PageArrowButton(
            icon: Icons.chevron_right,
            enabled: currentPage < totalPages,
            onTap: () => onPage(currentPage + 1),
          ),
        ],
      ),
    );
  }
}

class PageArrowButton extends StatelessWidget {
  const PageArrowButton(
      {super.key,
      required this.icon,
      required this.enabled,
      required this.onTap});
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon,
            size: 18,
            color: enabled ? AppColors.primary : const Color(0xFFD1D5DB)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Order card — mirrors components/order/OrderCard.tsx
// ---------------------------------------------------------------------------

class _OrderCardView extends StatelessWidget {
  const _OrderCardView(
      {required this.order,
      required this.viewed,
      required this.pulse,
      required this.onTap});
  final Order order;
  final bool viewed;
  final AnimationController pulse;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = OrderStatus.from(order.status);
    final dateTime = formatDateTime(order.createdAt);
    final value = order.items.fold<num>(
        0,
        (sum, item) =>
            sum +
            (num.tryParse(item.itemPrice ?? '') ?? 0) *
                item.quantity *
                (item.pieceCount ?? 1));
    final unpackedCount = unpackedLineCount(order);

    return Material(
      color: viewed ? Colors.white : AppColors.unreadTint,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: viewed
                  ? const Color(0xFFF3F4F6)
                  : AppColors.unread.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            StockflowAvatar(
                              id: order.customer.id,
                              name: order.customer.name,
                            ),
                            if (!viewed)
                              Positioned(
                                top: -2,
                                right: -2,
                                child: PulsingDot(controller: pulse),
                              ),
                          ],
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.customer.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: viewed
                                      ? const Color(0xFF374151)
                                      : const Color(0xFF111827),
                                ),
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.person_outline,
                                      size: 12, color: Color(0xFF9CA3AF)),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      order.agent.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF9CA3AF)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      StatusBadge(status),
                      const SizedBox(height: 4),
                      Text(
                        'ID #${order.id}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF4B5563),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (unpackedCount > 0) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.inventory_2_outlined,
                                  size: 11, color: Color(0xFFD97706)),
                              const SizedBox(width: 3),
                              Text(
                                '$unpackedCount',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFD97706),
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Text(
                                'Unpacked',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                  color: Color(0xFFD97706),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.only(top: 10),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFF9FAFB))),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dateTime,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF4B5563),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                formatSets(order.totalSets),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              const Text(' • ',
                                  style:
                                      TextStyle(color: Color(0xFFD1D5DB))),
                              Text(
                                formatPieces(order.totalPieces),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF4B5563),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatInrInt(value),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}