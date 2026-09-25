/// Mirrors `frontend/lib/utils/orderItemSort.ts`.
///
/// Order-summary lists show not-fully-packed items first and fully packed
/// items last, while keeping the original relative order within each group.
library;

import '../../models/models.dart';

/// Whether an order item has been packed in full. Items whose `packedQuantity`
/// is below `pieceCount * quantity` (including zero) are not fully packed.
bool isOrderItemFullyPacked(OrderItem item) {
  final totalPieces = (item.pieceCount ?? 1) * item.quantity;
  return (item.packedQuantity ?? 0) >= totalPieces;
}

/// Returns a new list with not-fully-packed items first and fully packed items
/// last. Stable: items inside each group keep their original relative order.
/// Never mutates [items].
List<OrderItem> sortOrderItemsUnpackedFirst(List<OrderItem> items) {
  final indexed = <({OrderItem item, int index})>[
    for (var i = 0; i < items.length; i++) (item: items[i], index: i),
  ];
  indexed.sort((a, b) {
    final groupA = isOrderItemFullyPacked(a.item) ? 1 : 0;
    final groupB = isOrderItemFullyPacked(b.item) ? 1 : 0;
    if (groupA != groupB) return groupA.compareTo(groupB);
    return a.index.compareTo(b.index);
  });
  return [for (final entry in indexed) entry.item];
}
