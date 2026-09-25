import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/perf.dart';
import '../../core/utils/piece_counts.dart';
import '../../data/repositories.dart';
import '../../models/models.dart';
import '../../shared/widgets.dart';
import 'order_flow_utils.dart';

/// Step 4 - choose variant + size group + quantity, then add or update the
/// order item. Mirrors `agent/order/new/[id]/[qr]/page.tsx`.
class OrderCreateItemScreen extends ConsumerStatefulWidget {
  const OrderCreateItemScreen({
    super.key,
    required this.customerId,
    this.qr = '',
    this.itemId,
  });

  final int customerId;
  final String qr;

  /// When set, the item is resolved from the stock list by [itemId] instead of
  /// a scanned QR (the "search by name" flow).
  final int? itemId;

  @override
  ConsumerState<OrderCreateItemScreen> createState() =>
      _OrderCreateItemScreenState();
}

class _OrderCreateItemScreenState
    extends ConsumerState<OrderCreateItemScreen> {
  ItemQR? _data;
  Order? _order;
  List<String> _orderGroups = const [];
  ItemVariantQR? _selectedVariant;
  String? _selectedSizeGroup;
  int _quantity = 1;
  bool _loading = true;
  bool _submitting = false;
  bool _notAssigned = false;
  String? _error;
  String? _validationError;

@override
  void initState() {
    super.initState();
    Perf.start('oitem');
    _load();
  }

  Future<void> _load() async {
    final orderId = OrderDraftSession.orderId;
    if (orderId == null) {
      setState(() {
        _loading = false;
        _error = 'Order session not found. Please restart the order.';
      });
return;
    }

    try {
      final hasQr = widget.qr.isNotEmpty;
      final results = await Future.wait<Object?>([
        hasQr ? repos.item.byQr(widget.qr) : Future<ItemQR?>.value(null),
        repos.order.getOne(orderId),
        repos.item.sizeRanges(),
        hasQr ? Future<List<ItemStockEntry>>.value(const []) : repos.item.stockList(),
      ]);
      if (!mounted) return;
      final resolved = results[0] as ItemQR?;
      final order = results[1] as Order;
      final sizeRanges = results[2] as Map<String, dynamic>;
      final stockItems = results[3] as List<ItemStockEntry>;

      ItemQR? data = resolved;
      ItemVariantQR? variant;

      if (widget.itemId != null) {
        final matches = [
          for (final entry in stockItems)
            if (entry.id == widget.itemId) entry,
        ];
        if (matches.isEmpty) {
          throw Exception('Item not found in stock. Please try again.');
        }
        final entry = matches.first;
        data = ItemQR(
          id: entry.id,
          name: entry.name,
          type: entry.type,
          price: entry.price,
          variants: entry.variants,
          matchedVariantId: entry.variants.isNotEmpty
              ? entry.variants.first.id
              : null,
        );
        if (entry.variants.isNotEmpty) {
          variant = entry.variants.first;
        }
      } else if (data != null && data.variants.isNotEmpty) {
        final item = data;
        final matched = item.matchedVariantId ?? 0;
        variant = item.variants.firstWhere(
          (v) => v.id == matched,
          orElse: () => item.variants.first,
        );
      }

      if (data == null) throw Exception('No item found.');

      final type = (data.type ?? 'gents').toLowerCase();
      final validType = (type == 'kids' || type == 'gents') ? type : 'gents';
final byType =
          (sizeRanges['order_creation_sizes_by_type'] as Map<String, dynamic>?) ??
              const {};
      final groups =
          List<String>.from(byType[validType] as List<dynamic>? ?? const []);

      setState(() {
        _data = data;
        _order = order;
        _orderGroups = groups;
        _selectedVariant = variant;
        _loading = false;
        _error = null;
      });
      Perf.end('oitem', 'TTC');
      _autoSelectSizeGroup();
    } catch (e) {
      if (!mounted) return;
      final api = ApiClient.mapError(e);
      setState(() {
        _loading = false;
        if (api.message.toLowerCase().contains('not assigned to you')) {
          _notAssigned = true;
        } else {
          _error = api.message;
        }
      });
    }
  }

  List<OrderItem> get _items => _order?.items ?? const [];

  OrderItem? _existingItem(int variantId, String sizeGroup) {
    for (final item in _items) {
      if (item.variant == variantId && item.sizeGroup == sizeGroup) return item;
    }
    return null;
  }

  OrderItem? get _editingItem {
    final variant = _selectedVariant;
    final group = _selectedSizeGroup;
    if (variant == null || group == null) return null;
    return _existingItem(variant.id, group);
  }

  List<({String sizeGroup, int quantity})> _reservedFor(int variantId) {
    final editing = _editingItem;
    return [
      for (final item in _items)
        if (item.variant == variantId && item.id != editing?.id)
          (sizeGroup: item.sizeGroup ?? '', quantity: item.quantity),
    ];
  }

  List<String> get _sizeGroups => availableSizeRanges(
        _selectedVariant,
        _data?.type,
        _orderGroups,
      );

  int _availableStock(String group) => availableStockForSizeGroup(
        _selectedVariant,
        group,
        _reservedFor(_selectedVariant?.id ?? -1),
);

  void _autoSelectSizeGroup() {
    final variant = _selectedVariant;
    if (variant == null) return;
    final groups = _sizeGroups;
    if (groups.isEmpty) return;

    final reserved = _reservedFor(variant.id);
    int stockFor(String group) =>
        availableStockForSizeGroup(variant, group, reserved);
    bool available(String group) =>
        groups.contains(group) && stockFor(group) > 0;

    String? pick;
    if (_data?.type == 'kids') {
      if (available('20-36')) {
        pick = '20-36';
      } else if (!available('20-24') && available('26-36')) {
        pick = '26-36';
      } else if (!available('32-36') && available('20-30')) {
        pick = '20-30';
      } else if (available('20-24')) {
        pick = '20-24';
      } else if (available('32-36')) {
        pick = '32-36';
      }
    } else {
      pick = groups.firstWhere((g) => stockFor(g) > 0, orElse: () => groups[0]);
    }
    pick ??= groups.first;
    final stock = stockFor(pick);
    setState(() {
      _selectedSizeGroup = pick;
      _quantity = (_existingItem(variant.id, pick!)?.quantity ?? 1)
          .clamp(1, stock < 1 ? 1 : stock)
          .toInt();
    });
  }

  void _selectVariant(ItemVariantQR variant) {
    setState(() {
      _selectedVariant = variant;
      _selectedSizeGroup = null;
      _validationError = null;
    });
    _autoSelectSizeGroup();
  }

  void _selectSizeGroup(String group) {
    setState(() {
      _selectedSizeGroup = group;
      final existing = _existingItem(_selectedVariant?.id ?? -1, group);
      final stock = _availableStock(group);
      _quantity =
          (existing?.quantity ?? 1).clamp(1, stock < 1 ? 1 : stock).toInt();
      _validationError = null;
    });
  }

  void _setQuantity(int value) {
    final stock = _selectedSizeGroup == null
        ? 1
        : _availableStock(_selectedSizeGroup!);
    final max = stock < 1 ? 1 : stock;
    setState(() {
      _quantity = value.clamp(1, max).toInt();
      _validationError =
          _quantity > stock ? 'Only $stock items available for selected size group' : null;
    });
  }

  Future<void> _submit() async {
    final orderId = OrderDraftSession.orderId;
    final variant = _selectedVariant;
    final group = _selectedSizeGroup;

    if (orderId == null) {
      setState(() =>
          _validationError = 'Order session not found. Please restart the order.');
      return;
    }
    if (variant == null) {
      setState(() => _validationError = 'Please select a color/variant');
      return;
    }
    if (group == null) {
      setState(() => _validationError = 'Please select a size group');
      return;
    }
    if (_quantity < 1) {
      setState(() => _validationError = 'Quantity must be at least 1');
      return;
    }
    final stock = _availableStock(group);
    if (_quantity > stock) {
      setState(() =>
          _validationError = 'Only $stock items available for selected size group');
      return;
    }
    if (variant.qrCode == null || variant.qrCode!.isEmpty) {
      setState(() => _validationError = 'This color has no QR code.');
      return;
    }

    setState(() {
      _validationError = null;
      _submitting = true;
    });
    try {
      final existing = _existingItem(variant.id, group);
      if (existing != null) {
        await repos.order.updateItem(existing.id, {'quantity': _quantity});
        if (mounted) AppToast.success(context, 'Item Updated');
      } else {
        await repos.order.addItem(
          orderId,
          qrCode: variant.qrCode!,
          quantity: _quantity,
          sizeGroup: group,
        );
        if (mounted) AppToast.success(context, 'Item Added');
      }
      if (mounted) _back();
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, e.toString().replaceFirst('Exception: ', ''));
      setState(() => _submitting = false);
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/admin/order/new/${widget.customerId}');
    }
  }

  Widget _guard(Widget child) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          _back();
        },
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _guard(const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: PageLoading(label: 'Loading item...')),
      ));
    }
    if (_notAssigned) return _guard(_messageScaffold(true));
    if (_error != null) return _guard(_messageScaffold(false));
    return _guard(_content());
  }

  Widget _messageScaffold(bool notAssigned) {
return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFBFBFA),
        elevation: 0,
        leading: IconButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/admin'),
          icon: const Icon(Icons.arrow_back, color: Color(0xFF9CA3AF)),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: notAssigned
                      ? const Color(0xFFFEF3C7)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  notAssigned
                      ? Icons.warning_amber_rounded
                      : Icons.error_outline,
                  color: notAssigned
                      ? const Color(0xFFD97706)
                      : AppColors.textMuted,
                  size: 26,
                ),
              ),
              const SizedBox(height: 14),
              Text(notAssigned ? 'Color Not Assigned!' : 'Item unavailable',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827))),
              const SizedBox(height: 6),
              Text(
                notAssigned
                    ? 'This color is not assigned to you.'
                    : (_error ?? 'Something went wrong'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 20),
              StockFlowButton(
                label: 'Scan another QR',
                onPressed: () => context.pushReplacement(
                    '/admin/order/new/${widget.customerId}/scan'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _back,
                child: const Text('Back to Orders'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content() {
    final data = _data!;
    final variant = _selectedVariant;
    final isEdit = _editingItem != null;
return Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        body: Column(
          children: [
            _header(isEdit),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: AspectRatio(
                    aspectRatio: 16 / 11,
                    child: AppImage(variant?.image, iconSize: 40),
                  ),
                ),
                const SizedBox(height: 16),
                Text(data.name,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827))),
                if ((data.description ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('DESCRIPTION',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.3,
                          color: Color(0xFF9CA3AF))),
                  const SizedBox(height: 4),
                  Text(data.description!,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF4B5563))),
                ],
                const SizedBox(height: 22),
                _label('COLOR / VARIANT'),
                const SizedBox(height: 10),
_variantRow(data),
                const SizedBox(height: 22),
                _label('SIZE GROUP'),
                const SizedBox(height: 10),
                _sizeGroupDropdown(),
                const SizedBox(height: 22),
                _quantitySection(),
                if (_validationError != null) ...[
                  const SizedBox(height: 16),
                  _validationBox(_validationError!),
                ],
                const SizedBox(height: 22),
                StockFlowButton(
                  label: isEdit ? 'Update Item' : 'Add to Order',
                  loading: _submitting,
                  icon: const Icon(Icons.check, size: 18, color: Colors.white),
                  onPressed: _submitting ? null : _submit,
                ),
              ],
              ),
            ),
          ],
),
    );
  }

  Widget _header(bool isEdit) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(6, 14, 16, 16),
      child: Row(
        children: [
          IconButton(
            onPressed: _back,
            icon: const Icon(Icons.arrow_back, color: Color(0xFF9CA3AF)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isEdit ? 'Edit Item' : 'Add Item',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827))),
              const Text('STEP 4: ITEM DETAILS',
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

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.3,
          color: Color(0xFF9CA3AF)));

  Widget _variantRow(ItemQR data) {
    if (data.variants.isEmpty) {
      return const Text('No colors available',
          style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)));
    }
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: data.variants.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final v = data.variants[i];
          final selected = v.id == _selectedVariant?.id;
          final hasItems =
              _items.any((item) => item.variant == v.id);
          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _selectVariant(v),
            child: Container(
              width: 76,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected
                      ? AppColors.primary
                      : const Color(0xFFE5E7EB),
                  width: selected ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          AppImage(v.image, iconSize: 16),
                          if (hasItems)
                            const Positioned(
                              top: 2,
                              right: 2,
                              child: Icon(Icons.check_circle,
                                  size: 12, color: Color(0xFF16A34A)),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text('Color ${(v.displayOrder?.trim().isNotEmpty ?? false) ? v.displayOrder : v.id}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? AppColors.primary
                              : const Color(0xFF6B7280))),
                ],
              ),
            ),
          );
        },
      ),
);
  }

  Widget _sizeGroupDropdown() {
    final groups = _sizeGroups;
    if (groups.isEmpty) {
      return const Text('No size groups available for this color',
          style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)));
    }
    final selected = _selectedSizeGroup;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected != null
                  ? AppColors.primary
                  : const Color(0xFFE5E7EB),
              width: selected != null ? 2 : 1,
            ),
          ),
          child: DropdownButton<String>(
            value: selected,
            isExpanded: true,
            isDense: true,
            underline: const SizedBox.shrink(),
            borderRadius: BorderRadius.circular(14),
            hint: const Text('Select size group',
                style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
            icon:
                const Icon(Icons.keyboard_arrow_down, color: AppColors.primary),
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827)),
            items: [
              for (final group in groups)
                DropdownMenuItem(
                  value: group,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(group,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _sizeGroupAvailabilityLabel(group),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _isSizeGroupOutOfStock(group)
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF16A34A),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            onChanged: (v) {
              if (v == null) return;
              if (_isSizeGroupOutOfStock(v)) {
                setState(
                    () => _validationError = '$v is out of stock, please pick another size group.');
                return;
              }
              _selectSizeGroup(v);
            },
          ),
        ),
        if (selected != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Text('${pieceCountFor(selected)} pcs per set',
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
              const Spacer(),
              Text('${_availableStock(selected)} available',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF16A34A))),
            ],
          ),
        ],
      ],
    );
  }

  bool _isSizeGroupOutOfStock(String group) => _availableStock(group) < 1;

  String _sizeGroupAvailabilityLabel(String group) =>
      _isSizeGroupOutOfStock(group)
          ? 'Out of stock'
          : '${_availableStock(group)} available';

  Widget _quantitySection() {
    final stock = _selectedSizeGroup == null
        ? 0
        : _availableStock(_selectedSizeGroup!);
    final max = stock < 1 ? 1 : stock;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('QUANTITY (SETS)',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.3,
                      color: Color(0xFF9CA3AF))),
              Text('Max $max',
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF9CA3AF))),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: _quantity > 1 ? () => _setQuantity(_quantity - 1) : null,
            icon: const Icon(Icons.remove_circle_outline),
            color: AppColors.primary,
          ),
          SizedBox(
            width: 36,
            child: Text('$_quantity',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827))),
          ),
          IconButton(
            onPressed:
                _quantity < max ? () => _setQuantity(_quantity + 1) : null,
            icon: const Icon(Icons.add_circle_outline),
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _validationBox(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECDD3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: Color(0xFFE11D48)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFE11D48))),
          ),
        ],
      ),
    );
  }
}
