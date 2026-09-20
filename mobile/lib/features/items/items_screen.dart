import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/perf.dart';
import '../../core/utils/piece_counts.dart';
import '../../core/utils/stock_validators.dart';
import '../../data/item_store.dart';
import '../../data/repositories.dart';
import '../../models/models.dart';
import '../../shared/admin_shell.dart';
import '../../shared/widgets.dart';
import 'item_sync_service.dart';

enum StockTab { inStock, outOfStock, ordered }

class _UnpackedItem {
  const _UnpackedItem({
    required this.id,
    required this.itemName,
    required this.itemType,
    required this.variantDisplayOrder,
    required this.quantity,
    required this.sizeGroup,
    this.variantImage,
    required this.pieceCount,
  });
  final int id;
  final String itemName;
  final String itemType;
  final String variantDisplayOrder;
  final int quantity;
  final String sizeGroup;
  final String? variantImage;
  final int pieceCount;

  static _UnpackedItem fromJson(Map<String, dynamic> j) => _UnpackedItem(
        id: asInt(j['id']) ?? 0,
        itemName: s(j['item_name']),
        itemType: s(j['item_type']),
        variantDisplayOrder: s(j['variant_display_order']),
        quantity: asInt(j['quantity']) ?? 0,
        sizeGroup: s(j['size_group']),
        variantImage: j['variant_image'] as String?,
        pieceCount: asInt(j['piece_count']) ?? 1,
      );
}

class ItemsScreen extends ConsumerStatefulWidget {
  const ItemsScreen({super.key});

  @override
  ConsumerState<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends ConsumerState<ItemsScreen> {
  StockTab _tab = StockTab.inStock;
  String _search = '';
  String? _qrFilter;
  final Set<int> _expanded = {};
  int _visibleCount = 40;
  bool _loading = true;
  String? _error;

  List<ItemStockEntry> _items = const [];
  List<_UnpackedItem> _unpacked = const [];
  Map<String, List<String>> _orderGroups = const {};

  @override
  void initState() {
    super.initState();
    Perf.start('items');
    ItemSyncService.instance.attach();
    ItemSyncService.instance.revision.addListener(_onStoreChanged);
    ItemSyncService.instance.lastError.addListener(_onSyncMetaChanged);
    ItemSyncService.instance.syncing.addListener(_onSyncMetaChanged);
    _load();
  }

  @override
  void dispose() {
    ItemSyncService.instance.revision.removeListener(_onStoreChanged);
    ItemSyncService.instance.lastError.removeListener(_onSyncMetaChanged);
    ItemSyncService.instance.syncing.removeListener(_onSyncMetaChanged);
    super.dispose();
  }

  /// Re-reads the synced store whenever a sync round mutates it.
  void _onStoreChanged() {
    if (!mounted) return;
    setState(() {
      _items = ItemStore.instance.entries();
      _loading = false;
      _error = null;
    });
  }

  void _onSyncMetaChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    // Items render instantly from the synced store (offline-safe); the network
    // round only brightens detail in the background.
    _items = ItemStore.instance.entries();
    Perf.end('items', 'TTC');
    ItemSyncService.instance.trigger();
    try {
      final results = await Future.wait([
        repos.order.unpacked(),
        repos.item.sizeRanges(),
      ]);
      final u = (results[0] as List)
          .map((e) => _UnpackedItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      final byType = (results[1] as Map<String, dynamic>)[
              'order_creation_sizes_by_type'] as Map<String, dynamic>? ??
          const <String, dynamic>{};
      final groups = <String, List<String>>{
        for (final entry in byType.entries)
          entry.key: List<String>.from(entry.value as List? ?? const []),
      };
      if (mounted) {
        setState(() {
          _unpacked = u;
          _orderGroups = groups;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  /// Pull-to-refresh / retry: re-reads live data and forces a sync round.
  Future<void> _refresh() async {
    await _load();
    ItemSyncService.instance.trigger(force: true);
  }

  List<String> _groupsFor(String itemType) =>
      _orderGroups[(itemType == 'kids' || itemType == 'gents') ? itemType : 'gents'] ??
      const [];

  bool _isVariantOut(ItemVariantQR v, String itemType) =>
      variantOutOfStock(
          sizes: v.sizes, itemType: itemType, orderGroups: _groupsFor(itemType));

  bool _isItemOut(ItemStockEntry item) => itemOutOfStock(
        variantSizes: item.variants.map((v) => v.sizes).toList(),
        itemType: item.type ?? 'gents',
        orderGroups: _groupsFor(item.type ?? 'gents'),
      );

  List<ItemStockEntry> get _filteredItems {
    var filtered = _items.where((i) => i.name.isNotEmpty).toList();
    if (_tab == StockTab.inStock) {
      filtered = filtered.where((i) => !_isItemOut(i)).toList();
      filtered = filtered
          .map((i) => ItemStockEntry(
                id: i.id,
                name: i.name,
                type: i.type,
                price: i.price,
                image: i.image,
                variants: [
                  for (final v in i.variants)
                    if (!_isVariantOut(v, i.type ?? 'gents'))
                      ItemVariantQR(
                        id: v.id,
                        qrCode: v.qrCode,
                        image: v.image,
                        sizes: v.sizes,
                        totalStock: v.totalStock,
                        displayOrder: v.displayOrder,
                      ),
                ],
              ))
          .toList();
    } else if (_tab == StockTab.outOfStock) {
      filtered = filtered
          .where((i) =>
              _isItemOut(i) ||
              i.variants.any((v) => _isVariantOut(v, i.type ?? 'gents')))
          .toList();
      filtered = filtered
          .map((i) => ItemStockEntry(
                id: i.id,
                name: i.name,
                type: i.type,
                price: i.price,
                image: i.image,
                variants: [
                  for (final v in i.variants)
                    if (_isVariantOut(v, i.type ?? 'gents'))
                      ItemVariantQR(
                        id: v.id,
                        qrCode: v.qrCode,
                        image: v.image,
                        sizes: v.sizes,
                        totalStock: v.totalStock,
                        displayOrder: v.displayOrder,
                      ),
                ],
              ))
          .toList();
    }
    if (_search.trim().isNotEmpty) {
      final q = _search.trim().toLowerCase();
      filtered = filtered.where((i) => i.name.toLowerCase().contains(q)).toList();
    }
    if (_qrFilter != null && _qrFilter!.isNotEmpty) {
      final qr = _qrFilter!.toLowerCase();
      filtered = filtered
          .where((i) =>
              i.variants.any((v) => (v.qrCode ?? '').toLowerCase().contains(qr)))
          .toList();
    }
    return filtered;
  }

  List<_UnpackedItem> get _filteredOrdered {
    if (_search.trim().isEmpty) return _unpacked;
    final q = _search.trim().toLowerCase();
    return _unpacked.where((i) => i.itemName.toLowerCase().contains(q)).toList();
  }

  int get _inStockCount =>
      _items.where((i) => !_isItemOut(i)).length;

  int get _outOfStockCount => _items.where((i) {
        final groups = _groupsFor(i.type ?? 'gents');
        return itemOutOfStock(
                variantSizes: i.variants.map((v) => v.sizes).toList(),
                itemType: i.type ?? 'gents',
                orderGroups: groups) ||
            itemPartiallyOutOfStock(
                variantSizes: i.variants.map((v) => v.sizes).toList(),
                itemType: i.type ?? 'gents',
                orderGroups: groups);
      }).length;

  bool get _hasActiveFilters =>
      _search.trim().isNotEmpty || (_qrFilter?.isNotEmpty ?? false);

  void _clearFilters() => setState(() {
        _search = '';
        _qrFilter = null;
      });

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredItems;
    final ordered = _filteredOrdered;

    return AdminScaffold(
      activePath: '/admin/items',
      title: 'Inventory',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
            child: Row(
              children: [
                const Text('Total Items',
                    style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Text('${_items.length}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                ),
                const Spacer(),
                StockFlowButton(
                  label: 'Add',
                  icon: const Icon(Icons.add, size: 16, color: Colors.white),
                  onPressed: () => context.push('/admin/items/new'),
                  expand: false,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Expanded(
                  child: _ItemsSearchField(
                    hint: _tab == StockTab.ordered
                        ? 'Search ordered items...'
                        : 'Search items...',
                    value: _search,
                    onChanged: (v) => setState(() => _search = v),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _openScanner(),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.qr_code_scanner,
                        size: 17, color: Color(0xFF6B7280)),
                  ),
                ),
              ],
            ),
          ),
          if (_hasActiveFilters)
            Container(
              margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_qrFilter != null ? 'QR: ${_qrFilter!.length > 12 ? _qrFilter!.substring(0, 12) : _qrFilter!}...' : ''}${_qrFilter != null && _search.isNotEmpty ? ' • ' : ''}${_search.isNotEmpty ? 'Name: $_search' : ''}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary),
                    ),
                  ),
                  InkWell(
                    onTap: _clearFilters,
                    child: const Icon(Icons.close,
                        size: 14, color: AppColors.primary),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _TabChip(
                    label: 'Stock In ($_inStockCount)',
                    active: _tab == StockTab.inStock,
                    onTap: () => setState(() => _tab = StockTab.inStock),
                  ),
                  _TabChip(
                    label: 'Stock Out ($_outOfStockCount)',
                    active: _tab == StockTab.outOfStock,
                    onTap: () => setState(() => _tab = StockTab.outOfStock),
                  ),
                  _TabChip(
                    label: 'Ordered (${ordered.length})',
                    active: _tab == StockTab.ordered,
                    onTap: () => setState(() => _tab = StockTab.ordered),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          if (_loading && _items.isNotEmpty ||
              ItemSyncService.instance.syncing.value)
            const LinearProgressIndicator(minHeight: 2),
          if (ItemSyncService.instance.lastError.value != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off,
                      size: 13, color: Color(0xFFB45309)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      ItemSyncService.instance.lastError.value!,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFFB45309)),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        ItemSyncService.instance.trigger(force: true),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                    ),
                    child: const Text('Retry',
                        style:
                            TextStyle(fontSize: 11, color: Color(0xFFB45309))),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _loading && _items.isEmpty
                ? const PageLoading()
                : _error != null && _items.isEmpty
                    ? EmptyState(
                        icon: Icons.cloud_off,
                        title: 'Could not load items',
                        subtitle: _error,
                        action: Align(
                          child: StockFlowButton(
                            label: 'Retry',
                            onPressed: _refresh,
                            expand: false,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _refresh,
                        child: CartListChildren(
                          children: _tab == StockTab.ordered
                              ? _orderedContent(ordered)
                              : _stockContent(filtered),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  List<Widget> _orderedContent(List<_UnpackedItem> ordered) {
    return [if (ordered.isEmpty) _emptyBox('No ordered items', 'No unpacked items found') else _orderedList(ordered)];
  }

  List<Widget> _stockContent(List<ItemStockEntry> filtered) {
    if (filtered.isEmpty) {
      return [_emptyBox('No items found', _hasActiveFilters ? 'Try a different search' : 'No items in this category')];
    }
    final result = <Widget>[];
    for (final item in filtered.take(_visibleCount)) {
      result.add(_ItemCardView(
        item: item,
        orderGroups: _groupsFor(item.type ?? 'gents'),
        expanded: _expanded.contains(item.id),
        onToggle: () => setState(() {
          if (_expanded.contains(item.id)) {
            _expanded.remove(item.id);
          } else {
            _expanded.add(item.id);
          }
        }),
        onEdit: () => context.push('/admin/items/edit/${item.id}'),
        onPrintAll: () => context.push('/admin/items/qr-print?item=${item.id}'),
        onPrintQR: (qr) => context.push('/admin/items/qr/${Uri.encodeComponent(qr)}'),
      ));
      result.add(const SizedBox(height: 8));
    }
    if (_visibleCount < filtered.length) {
      result.add(StockFlowButton(
        label: 'Show More (${filtered.length - _visibleCount} remaining)',
        onPressed: () => setState(() => _visibleCount += 40),
        expand: false,
      ));
    }
    return result;
  }

  Widget _orderedList(List<_UnpackedItem> ordered) {
    final groups = <String, List<_UnpackedItem>>{};
    for (final item in ordered) {
      (groups[item.itemName] ??= []).add(item);
    }
    final names = groups.keys.toList()..sort();
    return Column(
      children: [
        for (final name in names)
          _OrderedGroupCard(
            group: groups[name]!,
            unavailable: !_items.any((i) => i.name == name),
            onTap: () =>
                context.push('/admin/items/ordered/${groups[name]!.first.id}'),
          ),
      ],
    );
  }

  Widget _emptyBox(String title, String subtitle) => EmptyState(
        icon: Icons.shopping_bag_outlined,
        title: title,
        subtitle: subtitle,
        action: _hasActiveFilters
            ? Align(
                child: TextButton(
                  onPressed: _clearFilters,
                  child: const Text('Clear filters',
                      style: TextStyle(
                          fontSize: 13,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500)),
                ),
              )
            : null,
      );

  void _openScanner() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _QrScanSheet(
        onScanned: (qr) {
          Navigator.pop(ctx);
          setState(() => _qrFilter = qr);
        },
      ),
    );
  }
}

/// Wraps ListView children for RefreshIndicator (mirrors a simple list).
class CartListChildren extends StatelessWidget {
  const CartListChildren({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 96),
      physics: const AlwaysScrollableScrollPhysics(),
      children: children,
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip(
      {required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: active
                ? const [BoxShadow(color: Colors.black12, blurRadius: 3)]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: active
                  ? const Color(0xFF111827)
                  : const Color(0xFF6B7280),
            ),
          ),
        ),
      ),
    );
  }
}

class _ItemsSearchField extends StatelessWidget {
  const _ItemsSearchField(
      {required this.hint, required this.value, required this.onChanged});
  final String hint;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
              fontSize: 12, color: Color(0xFF9CA3AF)),
          prefixIcon: const Icon(Icons.search,
              size: 16, color: Color(0xFF9CA3AF)),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Item card (mirrors components/items/ItemCard.tsx)
// ---------------------------------------------------------------------------

class _ItemCardView extends StatelessWidget {
  const _ItemCardView({
    required this.item,
    required this.orderGroups,
    required this.expanded,
    required this.onToggle,
    required this.onEdit,
    required this.onPrintAll,
    required this.onPrintQR,
  });
  final ItemStockEntry item;
  final List<String> orderGroups;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onPrintAll;
  final void Function(String qr) onPrintQR;

  bool get _itemOut => itemOutOfStock(
        variantSizes: item.variants.map((v) => v.sizes).toList(),
        itemType: item.type ?? 'gents',
        orderGroups: orderGroups,
      );

  @override
  Widget build(BuildContext context) {
    final variants = [...item.variants]
      ..sort((a, b) {
        final oa = int.tryParse(a.displayOrder ?? '') ?? 1 << 30;
        final ob = int.tryParse(b.displayOrder ?? '') ?? 1 << 30;
        return oa.compareTo(ob);
      });

    return Container(
      decoration: BoxDecoration(
        color: _itemOut
            ? const Color(0xFFFEF2F2)
            : expanded
                ? const Color(0xFFF9FAFB)
                : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: _itemOut
                ? const Color(0xFFFECACA)
                : const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: (item.image?.isNotEmpty ?? false)
                        ? () => showImagePreview(context, item.image)
                        : null,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFF3F4F6)),
                      ),
                      child: AppImage(item.image, iconSize: 20),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF111827)),
                              ),
                            ),
                            if ((item.type ?? '').isNotEmpty) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: const Color(0xFFE5E7EB)),
                                ),
                                child: Text(
                                  item.type!.toUpperCase(),
                                  style: const TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF6B7280)),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${item.variants.length} variant${item.variants.length != 1 ? 's' : ''}',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF9CA3AF)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onEdit,
                    visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF3F4F6),
                      foregroundColor: const Color(0xFF6B7280),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 15),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed: onPrintAll,
                    visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF3F4F6),
                      foregroundColor: const Color(0xFF6B7280),
                    ),
                    icon: const Icon(Icons.qr_code, size: 15),
                  ),
                  Icon(
                    expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 18,
                    color: const Color(0xFF6B7280),
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Column(
                children: [
                  for (var i = 0; i < variants.length; i++)
                    _VariantCardView(
                      variant: variants[i],
                      index: i,
                      itemType: item.type ?? 'gents',
                      orderGroups: orderGroups,
                      onPrintQR: onPrintQR,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _VariantCardView extends StatelessWidget {
  const _VariantCardView({
    required this.variant,
    required this.index,
    required this.itemType,
    required this.orderGroups,
    required this.onPrintQR,
  });
  final ItemVariantQR variant;
  final int index;
  final String itemType;
  final List<String> orderGroups;
  final void Function(String qr) onPrintQR;

  @override
  Widget build(BuildContext context) {
    final out = variantOutOfStock(
        sizes: variant.sizes, itemType: itemType, orderGroups: orderGroups);
    final ranges = sizeRangesWithStock(
        sizes: variant.sizes, itemType: itemType, orderGroups: orderGroups);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: out ? const Color(0xFFFEE2E2) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: out ? const Color(0xFFFECACA) : const Color(0xFFF3F4F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                    width: 32,
                    height: 32,
                    child: AppImage(variant.image, previewEnabled: true)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Color #${variant.displayOrder ?? '${index + 1}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151)),
                    ),
                    if ((variant.qrCode ?? '').isNotEmpty)
                      Text(
                        variant.qrCode!.length > 10
                            ? '${variant.qrCode!.substring(0, 10)}...'
                            : variant.qrCode!,
                        style: const TextStyle(
                            fontSize: 9, color: Color(0xFF9CA3AF)),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 64,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final r in ranges)
                  _SizeStockChip(
                      sizeRange: r.sizeRange,
                      stock: r.stock,
                      disabled: out),
              ],
            ),
          ),
          if ((variant.qrCode ?? '').isNotEmpty && variant.displayOrder != null)
            Align(
              alignment: Alignment.bottomRight,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => onPrintQR(variant.qrCode!),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.qr_code, size: 12, color: Color(0xFF4B5563)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SizeStockChip extends StatelessWidget {
  const _SizeStockChip(
      {required this.sizeRange, required this.stock, required this.disabled});
  final String sizeRange;
  final int stock;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final piecesPerSet = pieceCountFor(sizeRange);
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      constraints: const BoxConstraints(minWidth: 80),
      decoration: BoxDecoration(
        color: disabled ? const Color(0xFFFEE2E2) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sizeRange,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: disabled ? const Color(0xFF9CA3AF) : const Color(0xFF374151),
            ),
          ),
          Text(
            '$stock Sets',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: disabled ? const Color(0xFFF87171) : const Color(0xFF111827),
            ),
          ),
          Text(
            '$piecesPerSet pcs/set',
            style: const TextStyle(fontSize: 9, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }
}

class _OrderedGroupCard extends StatelessWidget {
  const _OrderedGroupCard(
      {required this.group, required this.onTap, this.unavailable = false});
  final List<_UnpackedItem> group;
  final VoidCallback onTap;
  final bool unavailable;

  @override
  Widget build(BuildContext context) {
    final first = group.first;
    final variantOrders = {
      for (final i in group)
        if (i.variantDisplayOrder.isNotEmpty) i.variantDisplayOrder
    }.toList()
      ..sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));
    final totalQty = group.fold<int>(0, (s, i) => s + i.quantity);
    final pieceCount = first.pieceCount;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: unavailable ? null : onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: AppImage(first.variantImage, iconSize: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(first.itemName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827))),
                      ),
                      if (first.itemType.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(first.itemType.toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF6B7280))),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (variantOrders.isNotEmpty)
                        Text('Color #${variantOrders.join(', #')}',
                            style: const TextStyle(
                                fontSize: 10, color: Color(0xFF9CA3AF))),
                      if (first.sizeGroup.isNotEmpty) ...[
                        const Text('·',
                            style: TextStyle(
                                fontSize: 10, color: Color(0xFFE5E7EB))),
                        Text('Size: ${first.sizeGroup}',
                            style: const TextStyle(
                                fontSize: 10, color: Color(0xFF9CA3AF))),
                      ],
                      const Text('·',
                          style: TextStyle(
                              fontSize: 10, color: Color(0xFFE5E7EB))),
Text('$totalQty × $pieceCount pcs',
                            style: const TextStyle(
                                fontSize: 10, color: Color(0xFF9CA3AF))),
                    ],
                  ),
                ],
              ),
            ),
            if (unavailable)
              const Text('Item no longer available',
                  style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)))
            else
              const Icon(Icons.chevron_right,
                  size: 16, color: Color(0xFFD1D5DB)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// QR scanner sheet
// ---------------------------------------------------------------------------

class _QrScanSheet extends StatefulWidget {
  const _QrScanSheet({required this.onScanned});
  final void Function(String qr) onScanned;

  @override
  State<_QrScanSheet> createState() => _QrScanSheetState();
}

class _QrScanSheetState extends State<_QrScanSheet> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: 420,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Scan QR code',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: MobileScanner(
                    onDetect: (capture) {
                      if (_done) return;
                      final barcode = capture.barcodes.isNotEmpty
                          ? capture.barcodes.first
                          : null;
                      final raw = barcode?.rawValue;
                      if (raw != null && raw.isNotEmpty) {
                        _done = true;
                        widget.onScanned(raw);
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}