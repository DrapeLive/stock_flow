/// Mirrors `frontend/util/stockValidators.ts`. These helpers decide what
/// counts as "in stock" vs "out of stock" using the backend order-creation
/// size groups (`order_creation_sizes_by_type` from `/api/items/size-ranges`).
library;

import '../../models/models.dart';
import 'piece_counts.dart';

List<({String sizeRange, int stock})> sizeRangesWithStock({
  required List<VariantSize> sizes,
  required String itemType,
  required List<String> orderGroups,
}) {
  final sizeMap = <String, int>{
    for (final s in sizes) s.sizeRange: s.stock,
  };
  final result = <({String sizeRange, int stock})>[];

  for (final range in orderGroups) {
    final grouped = kSizeRangeToSizes[range];
    if (grouped == null) continue;
    final matched = grouped.where((g) => sizeMap.containsKey(g)).toList();
    if (matched.isEmpty) continue;
    if (matched.length != grouped.length) continue;
    final stocks = grouped.map((g) => sizeMap[g]!).toList();
    final minStock = stocks.reduce((a, b) => a < b ? a : b);
    result.add((sizeRange: range, stock: minStock));
  }

  if (itemType == 'gents') {
    if (result.isEmpty) return const [];
    return [
      result.reduce((a, b) =>
          (kSizeRangeToSizes[b.sizeRange]?.length ?? 0) >
                  (kSizeRangeToSizes[a.sizeRange]?.length ?? 0)
              ? b
              : a),
    ];
  }
  return result;
}

bool variantOutOfStock({
  required List<VariantSize> sizes,
  required String itemType,
  required List<String> orderGroups,
}) {
  final ranges = sizeRangesWithStock(
      sizes: sizes, itemType: itemType, orderGroups: orderGroups);
  if (ranges.isEmpty) return true;
  return ranges.every((r) => r.stock == 0);
}

bool itemOutOfStock({
  required List<List<VariantSize>> variantSizes,
  required String itemType,
  required List<String> orderGroups,
}) {
  if (variantSizes.isEmpty) return true;
  return variantSizes.every((sizes) =>
      variantOutOfStock(sizes: sizes, itemType: itemType, orderGroups: orderGroups));
}

bool itemPartiallyOutOfStock({
  required List<List<VariantSize>> variantSizes,
  required String itemType,
  required List<String> orderGroups,
}) {
  final out = variantSizes
      .where((sizes) =>
          variantOutOfStock(sizes: sizes, itemType: itemType, orderGroups: orderGroups))
      .length;
  return out > 0 && out < variantSizes.length;
}