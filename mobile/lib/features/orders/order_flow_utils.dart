/// Helpers for the admin "create order for a customer" flow, mirroring the
/// web app's `orderFlow.ts` and `[qr]/utils.ts`.
library;

import '../../core/utils/piece_counts.dart';
import '../../models/models.dart';

/// In-memory handle for the draft currently being built. The web app stores
/// the order id in `localStorage` (`orderKey`); mobile passes the customer id
/// in the route and keeps the draft id here. Drafts are short-lived and
/// resuming one is out of scope, so no persistence is needed.
class OrderDraftSession {
  OrderDraftSession._();

  static int? orderId;
  static int? customerId;

  static void start({required int orderId, required int customerId}) {
    OrderDraftSession.orderId = orderId;
    OrderDraftSession.customerId = customerId;
  }

  static void clear() {
    orderId = null;
    customerId = null;
  }
}

/// Size groups (from the order-creation table) the variant fully covers.
List<String> availableSizeRanges(
  ItemVariantQR? variant,
  String? itemType,
  List<String> orderGroups,
) {
  if (variant == null || itemType == null) return const [];
  final variantSizes = variant.sizes
      .map((s) => s.sizeRange)
      .where((s) => s.isNotEmpty)
      .toSet();
  if (variantSizes.isEmpty) return const [];

  if (itemType == 'gents') {
    for (final range in orderGroups) {
      final rangeSizes = kSizeRangeToSizes[range] ?? const <String>[];
      final rangeSet = rangeSizes.toSet();
      if (rangeSet.length == variantSizes.length &&
          rangeSet.every(variantSizes.contains)) {
        return [range];
      }
    }
    return variantSizes.toList();
  }

  return orderGroups.where((range) {
    final required = kSizeRangeToSizes[range] ?? const <String>[];
    return required.isNotEmpty && required.every(variantSizes.contains);
  }).toList();
}

/// Stock available for [sizeGroup] after subtracting already-added items for
/// the same variant (matching the web `getAvailableStockForSizeGroup`).
int availableStockForSizeGroup(
  ItemVariantQR? variant,
  String? sizeGroup,
  List<({String sizeGroup, int quantity})> reserved,
) {
  if (variant == null || sizeGroup == null) return 0;
  final selectedSizes = kSizeRangeToSizes[sizeGroup] ?? const <String>[];
  if (selectedSizes.isEmpty) return 0;

  final remaining = selectedSizes.map((size) {
    final base = variant.sizes
        .firstWhere((s) => s.sizeRange == size,
            orElse: () => VariantSize(sizeRange: size, stock: 0))
        .stock;
    final reservedForSize = reserved
        .where((r) =>
            (kSizeRangeToSizes[r.sizeGroup] ?? const <String>[]).contains(size))
        .fold<int>(0, (sum, r) => sum + r.quantity);
    return base - reservedForSize;
  }).toList();

  final minRemaining = remaining.reduce((a, b) => a < b ? a : b);
  return minRemaining < 0 ? 0 : minRemaining;
}

/// A set of rows that share item+variant+size group and should be merged.
class OrderMergeGroup {
  const OrderMergeGroup({
    required this.itemName,
    required this.sizeGroup,
    required this.items,
    required this.total,
  });

  final String itemName;
  final String sizeGroup;
  final List<({int id, int quantity})> items;
  final int total;
}

List<OrderMergeGroup> computeDuplicateGroups(List<OrderItem> items) {
  final map = <String, List<OrderItem>>{};
  for (final item in items) {
    final key =
        '${item.item?.id ?? 'unknown'}-${item.variant ?? 'none'}-${item.sizeGroup ?? 'none'}';
    (map[key] ??= []).add(item);
  }
  final groups = <OrderMergeGroup>[];
  for (final group in map.values) {
    if (group.length < 2) continue;
    groups.add(OrderMergeGroup(
      itemName: group.first.displayName,
      sizeGroup: group.first.sizeGroup ?? '',
      items: [for (final g in group) (id: g.id, quantity: g.quantity)],
      total: group.fold<int>(0, (sum, g) => sum + g.quantity),
    ));
  }
  return groups;
}
