/// Unpacked-line counting for the dashboard order card badge.
///
/// Mirrors the "remaining" rows shown on the order status screen's Packing
/// tab. Reuses [isOrderItemFullyPacked] so the partial-packing rule lives in
/// exactly one place.
library;

import '../../models/models.dart';
import 'order_item_sort.dart';

/// Number of order lines that still have unpacked pieces.
///
/// A line is unpacked when [isOrderItemFullyPacked] is false, i.e. its
/// `packedQuantity` is below `quantity * pieceCount`. Partially packed lines
/// therefore count as unpacked. This is the same rule the status screen uses
/// to decide which items still need packing.
///
/// The badge is only shown for PENDING/PACKED orders (unpacked stock has
/// already been returned to the warehouse once DISPATCHED), so every other
/// status returns 0.
int unpackedLineCount(Order order) {
  final status = order.status;
  if (status != 'PENDING' && status != 'PACKED') return 0;
  var count = 0;
  for (final item in order.items) {
    if (!isOrderItemFullyPacked(item)) count++;
  }
  return count;
}
