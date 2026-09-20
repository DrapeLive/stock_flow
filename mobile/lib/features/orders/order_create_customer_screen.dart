import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/perf.dart';
import '../../data/repositories.dart';
import '../../models/models.dart';
import '../../shared/widgets.dart';
import 'order_flow_utils.dart';

/// Step 1 â€” pick the customer to create a draft order for. Mirrors
/// `components/pages/admin/AdminCustomerSelect.tsx`.
class OrderCreateCustomerScreen extends ConsumerStatefulWidget {
  const OrderCreateCustomerScreen({super.key, this.presetCustomerId});

  final int? presetCustomerId;

  @override
  ConsumerState<OrderCreateCustomerScreen> createState() =>
      _OrderCreateCustomerScreenState();
}

class _OrderCreateCustomerScreenState
    extends ConsumerState<OrderCreateCustomerScreen> {
  static const int _pageSize = 20;

  final _searchController = TextEditingController();
  Timer? _debounce;

  List<Customer> _customers = const [];
  Customer? _preset;
  String _search = '';
  int _page = 1;
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _creating = false;
  String? _error;

@override
  void initState() {
    super.initState();
    Perf.start('ocust');
    _load();
    final presetId = widget.presetCustomerId;
    if (presetId != null) _loadPreset(presetId);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPreset(int id) async {
    try {
      final customer = await repos.customer.getOne(id);
      if (mounted) setState(() => _preset = customer);
    } catch (_) {}
  }

  Future<void> _load({bool append = false}) async {
    if (append) {
      setState(() => _loadingMore = true);
    } else {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final page = await repos.customer.list(
        page: _page,
        pageSize: _pageSize,
        search: _search,
      );
if (!mounted) return;
      setState(() {
        _customers = append ? [..._customers, ...page.results] : page.results;
        _total = page.count;
        _loading = false;
        _loadingMore = false;
      });
      Perf.end('ocust', 'TTC');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      setState(() {
        _search = value;
        _page = 1;
      });
      _load();
    });
  }

  Future<void> _select(Customer customer) async {
    if (_creating) return;
    setState(() => _creating = true);
    try {
      final order =
          await repos.order.create(customer: customer.id, agent: customer.agent);
      OrderDraftSession.start(orderId: order.id, customerId: customer.id);
      if (mounted) context.pushReplacement('/admin/order/new/${customer.id}');
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, e.toString().replaceFirst('Exception: ', ''));
      setState(() => _creating = false);
    }
  }

  bool get _hasMore => _customers.length < _total;

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/admin');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _goBack();
      },
child: Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        body: Column(
          children: [
            _header(),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(6, 14, 16, 14),
      child: Row(
        children: [
          IconButton(
            onPressed: _goBack,
            icon: const Icon(Icons.arrow_back, color: Color(0xFF9CA3AF)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Create Order',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827))),
              Text('STEP 1: SELECT CUSTOMER',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                      color: Color(0xFF9CA3AF))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const PageLoading(label: 'Loading customers...');
    if (_error != null) {
      return EmptyState(
        icon: Icons.cloud_off,
        title: 'Could not load customers',
        subtitle: _error,
        action: Align(
          child: StockFlowButton(
            label: 'Retry',
            onPressed: () => _load(),
            expand: false,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        _searchField(),
        const SizedBox(height: 16),
        if (_preset != null) ...[
          _presetCard(_preset!),
          const SizedBox(height: 12),
        ],
        if (_customers.isEmpty)
          const SizedBox(
            height: 200,
            child: EmptyState(
              icon: Icons.person_search_outlined,
              title: 'No customers found',
              subtitle: 'Try a different search',
            ),
          )
        else
          for (final customer in _customers) ...[
            _customerTile(customer),
            const SizedBox(height: 10),
          ],
        if (_hasMore && _customers.isNotEmpty)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _loadingMore
                  ? null
                  : () {
                      setState(() => _page += 1);
                      _load(append: true);
                    },
              child: Text(_loadingMore ? 'Loading...' : 'Show more'),
            ),
          ),
      ],
    );
  }

  Widget _searchField() {
    return SizedBox(
      height: 44,
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search customer...',
          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
          prefixIcon:
              const Icon(Icons.search, size: 18, color: Color(0xFF9CA3AF)),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
        ),
      ),
    );
  }

  Widget _presetCard(Customer customer) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _creating ? null : () => _select(customer),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            StockflowAvatar(id: customer.id, name: customer.name),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('CONTINUE WITH',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                          color: AppColors.primary)),
                  Text(customer.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827))),
                  Text('Agent: ${customer.agentName ?? 'â€”'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF6B7280))),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward, size: 18, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _customerTile(Customer customer) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _creating ? null : () => _select(customer),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF3F4F6)),
        ),
        child: Row(
          children: [
            StockflowAvatar(id: customer.id, name: customer.name),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(customer.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827))),
                  const SizedBox(height: 2),
                  Text('Agent: ${customer.agentName ?? 'â€”'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF6B7280))),
                  if ((customer.address ?? '').isNotEmpty)
                    Text(customer.address!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF9CA3AF))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 18, color: Color(0xFFD1D5DB)),
          ],
        ),
      ),
    );
  }
}
