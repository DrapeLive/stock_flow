import 'package:flutter_test/flutter_test.dart';

import 'package:stock_flow_admin/models/models.dart';

void main() {
  group('OrderItem.displayNameWithColor', () {
    test('appends the color suffix when display_order is present', () {
      final o = OrderItem(
        id: 1,
        quantity: 2,
        variantDisplayOrder: 'M',
      );
      expect(o.displayNameWithColor, 'Item ( Color #M )');
    });

    test('omits the suffix when display_order is null or blank', () {
      final o = OrderItem(
        id: 1,
        quantity: 2,
        variantDisplayOrder: '',
      );
      expect(o.displayNameWithColor, 'Item');
    });
  });

  group('OrderItem.fromJson display_order parsing', () {
    test('null variant_display_order parses to empty string, not zero', () {
      final o = OrderItem.fromJson({
        'id': 1,
        'quantity': 1,
        'variant_display_order': null,
      });
      expect(o.variantDisplayOrder, '');
      expect(o.displayNameWithColor, 'Item');
    });

    test('numeric variant_display_order is preserved as text', () {
      final o = OrderItem.fromJson({
        'id': 1,
        'quantity': 1,
        'variant_display_order': 4,
      });
      expect(o.variantDisplayOrder, '4');
      expect(o.displayNameWithColor, 'Item ( Color #4 )');
    });

    test('blank variant_display_order never renders ( Color # )', () {
      final o = OrderItem.fromJson({
        'id': 1,
        'quantity': 1,
        'variant_display_order': '',
      });
      expect(o.displayNameWithColor, 'Item');
    });
  });
}