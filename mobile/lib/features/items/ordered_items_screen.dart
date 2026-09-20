import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories.dart';
import '../../models/models.dart';
import '../../shared/admin_shell.dart';
import '../../shared/widgets.dart';

class _ReqCustomer {
  const _ReqCustomer({
    required this.customerName,
    required this.variantDisplayOrder,
    required this.quantity,
    required this.sizeGroup,
    this.variantImage,
  });
  final String customerName;
  final String variantDisplayOrder;
  final int quantity;
  final String sizeGroup;
  final String? variantImage;

  static _ReqCustomer fromJson(Map<String, dynamic> j) => _ReqCustomer(
        customerName: s(j['customer_name']),
        variantDisplayOrder: s(j['variant_display_order']),
        quantity: asInt(j['quantity']) ?? 0,
        sizeGroup: s(j['size_group']),
        variantImage: j['variant_image'] as String?,
      );
}

/// Mirrors `app/(admin)/admin/items/ordered/[id]/page.tsx` — shows which
/// customers have unpacked items for a given item.
class OrderedItemsScreen extends ConsumerStatefulWidget {
  const OrderedItemsScreen({super.key, required this.itemId});
  final int itemId;

  @override
  ConsumerState<OrderedItemsScreen> createState() => _OrderedItemsScreenState();
}

class _OrderedItemsScreenState extends ConsumerState<OrderedItemsScreen> {
  bool _loading = true;
  ApiException? _error;
  String _itemName = '';
  List<_ReqCustomer> _customers = const [];

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
      final data = await repos.item.customerRequirements(widget.itemId);
      if (!mounted) return;
      setState(() {
        final item = (data['item'] as Map?)?.cast<String, dynamic>() ?? const {};
        _itemName = s(item['name']);
        final customers = (data['customers'] as List?) ?? const [];
        _customers = customers
            .map((c) => _ReqCustomer.fromJson((c as Map).cast<String, dynamic>()))
            .toList();
        _loading = false;
        _error = null;
      });
    } catch (e) {
      final error = e is ApiException ? e : ApiException(e.toString());
      if (kDebugMode) {
        debugPrint('customer-requirements ${widget.itemId} failed: '
            '${error.statusCode} ${error.message}');
      }
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalQuantity =
        _customers.fold<int>(0, (sum, c) => sum + c.quantity);
    final uniqueColors =
        _customers.map((c) => c.variantDisplayOrder).toSet().length;

    return AdminScaffold(
      activePath: '/admin/items',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 12),
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
                        size: 20, color: Color(0xFF4B5563)),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _loading ? 'Loading…' : (_itemName.isNotEmpty ? _itemName : 'Ordered items'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const PageLoading(label: 'Loading item details…')
                : _error != null
                    ? _ErrorState(
                        error: _error!,
                        onRetry: _load,
                        onBack: () => context.canPop()
                          ? context.pop()
                          : context.go('/admin/items'),
                      )
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 20),
                        children: [
                          _SummaryCard(
                              customerCount: _customers.length,
                              totalQuantity: totalQuantity,
                              uniqueColors: uniqueColors),
                          const SizedBox(height: 16),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline,
                                    size: 14, color: AppColors.primary),
                                SizedBox(width: 8),
                                Text('ORDERED BY',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.6,
                                        color: Color(0xFF6B7280))),
                              ],
                            ),
                          ),
                          if (_customers.isEmpty)
                            const _NoCustomersBox()
                          else
                            for (final c in _customers)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _CustomerRow(customer: c),
                              ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard(
      {required this.customerCount,
      required this.totalQuantity,
      required this.uniqueColors});
  final int customerCount;
  final int totalQuantity;
  final int uniqueColors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.people_outline,
                  size: 14, color: AppColors.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('CUSTOMERS',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: Color(0xFF6B7280))),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Text('$customerCount',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: Colors.grey.withValues(alpha: 0.15)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatColumn(
                    label: 'Total Quantity', value: '$totalQuantity'),
              ),
              Expanded(
                child: _StatColumn(label: 'Unique Colors', value: '$uniqueColors'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry, required this.onBack});
  final ApiException error;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final String title;
    final String subtitle;
    if (error.statusCode == 404) {
      title = 'This item is no longer available';
      subtitle = 'The item may have been deleted.';
    } else if (error.isNetwork) {
      title = 'You are offline';
      subtitle = 'Check your connection and try again.';
    } else {
      title = 'Could not load ordered items';
      subtitle = error.message;
    }
    return EmptyState(
      icon: Icons.info_outline,
      title: title,
      subtitle: subtitle,
      action: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          StockFlowButton(label: 'Retry', onPressed: onRetry, expand: false),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: onBack,
            child: const Text('Go back'),
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.4,
                color: Color(0xFF9CA3AF))),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
      ],
    );
  }
}

class _NoCustomersBox extends StatelessWidget {
  const _NoCustomersBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: const Column(
        children: [
          Icon(Icons.info_outline, size: 30, color: Color(0xFFD1D5DB)),
          SizedBox(height: 8),
          Text('No customer orders found',
              style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
        ],
      ),
    );
  }
}

class _CustomerRow extends StatelessWidget {
  const _CustomerRow({required this.customer});
  final _ReqCustomer customer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFF3F4F6)),
            ),
            child: AppImage(customer.variantImage, iconSize: 16, previewEnabled: true),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customer.customerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827))),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (customer.variantDisplayOrder.isNotEmpty)
                      Text('Color #${customer.variantDisplayOrder}',
                          style: const TextStyle(
                              fontSize: 10, color: Color(0xFF9CA3AF))),
                    if (customer.sizeGroup.isNotEmpty) ...[
                      const Text(' · ',
                          style: TextStyle(
                              fontSize: 10, color: Color(0xFFE5E7EB))),
                      Text('Size: ${customer.sizeGroup}',
                          style: const TextStyle(
                              fontSize: 10, color: Color(0xFF9CA3AF))),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${customer.quantity}',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827))),
                const SizedBox(width: 4),
                const Text('sets',
                    style: TextStyle(
                        fontSize: 10, color: Color(0xFF6B7280))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}