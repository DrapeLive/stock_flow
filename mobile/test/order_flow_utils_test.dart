import 'package:flutter_test/flutter_test.dart';

import 'package:stock_flow_admin/features/orders/order_flow_utils.dart';
import 'package:stock_flow_admin/models/models.dart';

/// The picker resolves size groups from the variant's stored size rows, which
/// is what gates whether an Add request can be formed at all. These tests lock
/// that resolution (mirror of the web `getAvailableSizeRanges` /
/// `getAvailableStockForSizeGroup`).
void main() {
  group('availableSizeRanges', () {
    const gentsOrderGroups = [
      'S,M,L,XL,XXL',
      'S,M,L,XL',
      'M,L,XL,XXL',
      'M,L,XL',
    ];

    test('gents variant covering the S + M,L,XL rows resolves to one group',
        () {
      final variant = ItemVariantQR(
        id: 1,
        sizes: const [
          VariantSize(sizeRange: 'S', stock: 4),
          VariantSize(sizeRange: 'M,L,XL', stock: 6),
        ],
        totalStock: 10,
      );

      expect(availableSizeRanges(variant, 'gents', gentsOrderGroups),
          ['S,M,L,XL']);
    });

    test('gents variant with unmatched rows falls back to its own sizes', () {
      final variant = ItemVariantQR(
        id: 1,
        sizes: const [
          VariantSize(sizeRange: 'S', stock: 6),
          VariantSize(sizeRange: 'XXL', stock: 2),
        ],
        totalStock: 8,
      );

      expect(
        availableSizeRanges(variant, 'gents', gentsOrderGroups),
        containsAll(['S', 'XXL']),
      );
    });

    test('kids variant matches each covered range and skips uncovered ones',
        () {
      const kidsGroups = ['20-24', '20-36', '38'];
      final variant = ItemVariantQR(
        id: 1,
        sizes: const [
          VariantSize(sizeRange: '20-24', stock: 5),
          VariantSize(sizeRange: '26-30', stock: 5),
          VariantSize(sizeRange: '32-36', stock: 5),
        ],
        totalStock: 15,
      );

      expect(availableSizeRanges(variant, 'kids', kidsGroups),
          ['20-24', '20-36']);
    });

    test('kids variant with no bucket rows produces no reachable group', () {
      final variant = ItemVariantQR(
        id: 1,
        sizes: const [
          VariantSize(sizeRange: 'S', stock: 5),
        ],
        totalStock: 5,
      );

      expect(availableSizeRanges(variant, 'kids', const ['20-24', '38']),
          isEmpty);
    });

    test('defaults to empty when the variant is missing', () {
      expect(availableSizeRanges(null, 'gents', gentsOrderGroups), isEmpty);
    });
  });

  group('availableStockForSizeGroup', () {
    ItemVariantQR variantWith(int s, int mLXl, int xxl) => ItemVariantQR(
          id: 1,
          sizes: [
            VariantSize(sizeRange: 'S', stock: s),
            VariantSize(sizeRange: 'M,L,XL', stock: mLXl),
            VariantSize(sizeRange: 'XXL', stock: xxl),
          ],
          totalStock: s + mLXl + xxl,
        );

    test('returns the minimum per-size stock for a group', () {
      final variant = variantWith(3, 5, 7);
      expect(availableStockForSizeGroup(variant, 'S,M,L,XL', const []), 3);
      expect(
          availableStockForSizeGroup(variant, 'S,M,L,XL,XXL', const []), 3);
    });

    test('subtracts already-added order items per size', () {
      final variant = variantWith(4, 6, 2);
      const reserved = [
        (sizeGroup: 'S,M,L,XL', quantity: 2),
        (sizeGroup: 'M,L,XL', quantity: 1),
      ];
      // S: 4 - 2 = 2 ; M,L,XL: 6 - (2+1) = 3 -> min is 2.
      expect(availableStockForSizeGroup(variant, 'S,M,L,XL', reserved), 2);
    });

    test('clamps negatives at zero and ignores unknown groups', () {
      final variant = variantWith(1, 1, 1);
      const overReserved = [
        (sizeGroup: 'S,M,L,XL', quantity: 5),
      ];
      expect(
          availableStockForSizeGroup(variant, 'S,M,L,XL', overReserved), 0);
      expect(availableStockForSizeGroup(variant, '20-38', const []), 0);
      expect(availableStockForSizeGroup(null, 'S,M,L,XL', const []), 0);
    });
  });

  group('computeDuplicateGroups', () {
    OrderItem item(int id, int variant, int quantity) => OrderItem(
          id: id,
          item: const Item(
              id: 10,
              name: 'ITEM-A',
              price: '500',
              type: 'gents',
              variants: []),
          variant: variant,
          sizeGroup: 'S,M,L,XL',
          quantity: quantity,
          variantDisplayOrder: '1',
        );

    test('groups rows sharing item+variant+size group', () {
      final groups = computeDuplicateGroups([
        item(1, 100, 2),
        item(2, 100, 3),
        item(3, 101, 1),
      ]);

      expect(groups, hasLength(1));
      expect(groups.single.sizeGroup, 'S,M,L,XL');
      expect(groups.single.total, 5);
      expect(groups.single.items, hasLength(2));
    });

    test('leaves unique rows alone', () {
      expect(computeDuplicateGroups([item(1, 100, 1)]), isEmpty);
    });
  });
}