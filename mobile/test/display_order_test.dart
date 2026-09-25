import 'package:flutter_test/flutter_test.dart';

import 'package:stock_flow_admin/features/items/display_order.dart';

void main() {
  group('colorNumberLabel', () {
    test('shows the stored display_order when present', () {
      expect(colorNumberLabel('2', 3), 'Color #2');
      expect(colorNumberLabel('04', 3), 'Color #04');
    });

    test('falls back to position for null', () {
      expect(colorNumberLabel(null, 3), 'Color #3');
      expect(colorNumberLabel(null, 1), 'Color #1');
    });

    test('falls back to position for blank', () {
      expect(colorNumberLabel('', 3), 'Color #3');
      expect(colorNumberLabel('  ', 2), 'Color #2');
    });
  });

  group('variantOrderValue', () {
    test('parses numeric display_order as-is', () {
      expect(variantOrderValue('2'), 2);
      expect(variantOrderValue('10'), 10);
    });

    test('maps null/blank/non-numeric to a large sentinel (sorted last)', () {
      expect(variantOrderValue(null), 1 << 30);
      expect(variantOrderValue(''), 1 << 30);
      expect(variantOrderValue('abc'), 1 << 30);
    });
  });

  group('compareItemNamesAsc', () {
    test('sorts numerically inside names', () {
      final names = ['T-Shirt 10', 'T-Shirt 2', 'T-Shirt 1'];
      names.sort(compareItemNamesAsc);
      expect(names, ['T-Shirt 1', 'T-Shirt 2', 'T-Shirt 10']);
    });

    test('sorts case-insensitively', () {
      final names = ['banana', 'Apple', 'cherry'];
      names.sort(compareItemNamesAsc);
      expect(names, ['Apple', 'banana', 'cherry']);
    });
  });

  group('compareItemNamesDesc', () {
    test('mirrors the web numeric-aware DESC order', () {
      final names = ['T-Shirt 10', 'T-Shirt 2', 'T-Shirt 1'];
      names.sort(compareItemNamesDesc);
      expect(names, ['T-Shirt 10', 'T-Shirt 2', 'T-Shirt 1']);
    });
  });
}