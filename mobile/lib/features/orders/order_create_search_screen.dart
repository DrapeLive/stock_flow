import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories.dart';
import '../../models/models.dart';
import '../../shared/widgets.dart';

/// Step 3 (alt) - find an item by name instead of scanning a QR.
/// Mirrors the "search by name" fallback offered to admin order creation.
class OrderCreateSearchScreen extends ConsumerStatefulWidget {
  const OrderCreateSearchScreen({super.key, required this.customerId});

  final int customerId;

  @override
  ConsumerState<OrderCreateSearchScreen> createState() =>
      _OrderCreateSearchScreenState();
}

class _OrderCreateSearchScreenState
    extends ConsumerState<OrderCreateSearchScreen> {
  List<ItemStockEntry> _entries = const [];
  List<ItemStockEntry> _filtered = const [];
  String _query = '';
  bool _loading = true;
  String? _error;

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
      final entries = await repos.item.stockList();
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _filtered = _applyQuery(entries, _query);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ApiClient.mapError(e).message;
      });
    }
  }

  List<ItemStockEntry> _applyQuery(List<ItemStockEntry> entries, String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) return entries;
    return [
      for (final entry in entries)
        if (entry.name.toLowerCase().contains(query)) entry,
    ];
  }

  void _onQueryChanged(String value) => setState(() {
        _query = value;
        _filtered = _applyQuery(_entries, value);
      });

  void _openItem(ItemStockEntry entry) => context.push(
      '/admin/order/new/${widget.customerId}/pick/${entry.id}');

  void _backToOrder() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/admin/order/new/${widget.customerId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _backToOrder();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        body: Column(
          children: [
            _header(),
            _searchField(),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(6, 14, 16, 16),
      child: Row(
        children: [
          IconButton(
            onPressed: _backToOrder,
            icon: const Icon(Icons.arrow_back, color: Color(0xFF9CA3AF)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Search Item',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827))),
              Text('STEP 3: BY NAME',
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

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: TextField(
        autofocus: true,
        onChanged: _onQueryChanged,
        decoration: InputDecoration(
          hintText: 'Search items by name...',
          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
          prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF9CA3AF)),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.6)),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: PageLoading(label: 'Loading items...'));
    }
    if (_error != null) {
      return _stateBox(
        icon: Icons.error_outline,
        title: 'Could not load items',
        message: _error!,
        action: StockFlowButton(
          label: 'Retry',
          onPressed: _load,
        ),
      );
    }
    if (_filtered.isEmpty) {
      return _stateBox(
        icon: Icons.search_off,
        title: _query.trim().isEmpty ? 'No items yet' : 'No matches found',
        message: _query.trim().isEmpty
            ? 'Add items from the admin page first.'
            : 'No item named "$_query". Try a different name.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      itemCount: _filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _itemTile(_filtered[i]),
    );
  }

  Widget _stateBox({
    required IconData icon,
    required String title,
    required String message,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 26, color: AppColors.textMuted),
            ),
            const SizedBox(height: 14),
            Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827))),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
            if (action != null) ...[
              const SizedBox(height: 18),
              action,
            ],
          ],
        ),
      ),
    );
  }

  Widget _itemTile(ItemStockEntry entry) {
    final variantCount = entry.variants.length;
    final stock = entry.totalStock;
    final out = stock < 1;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openItem(entry),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF3F4F6)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 60,
                  height: 60,
                  child: AppImage(entry.image, iconSize: 24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827))),
                    const SizedBox(height: 3),
                    Text(
                      '${entry.price} • $variantCount color${variantCount == 1 ? '' : 's'} • ${out ? 'Out of stock' : '$stock in stock'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: out
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, size: 20, color: Color(0xFF9CA3AF)),
            ],
          ),
        ),
      ),
    );
  }
}