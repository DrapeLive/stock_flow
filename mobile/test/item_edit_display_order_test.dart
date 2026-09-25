import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stock_flow_admin/features/items/item_edit_screen.dart';
import 'package:stock_flow_admin/shared/widgets.dart';

import 'helpers.dart';

void main() {
  late ProviderContainer container;

  setUp(() async {
    await resetTestInfra();
    container = makeTestContainer();
    addTearDown(container.dispose);
  });

  Future<void> pumpEditScreen(WidgetTester tester,
      {Object? displayOrder}) async {
    useTallSurface(tester);
    seedAdminSession(business: 'gents');
    mockGet('/api/items/size-ranges', body: sizeRangesJson());
    mockGet('/api/items/1/', body: {
      'id': 1,
      'name': 'Edit Item',
      'type': 'gents',
      'price': '500',
      'description': 'Test item',
      'variants': [
        {
          'id': 100,
          'qr_code': 'QRONE',
          'image': null,
          'display_order': displayOrder,
          'sizes': [
            {'id': 1, 'size': 'S', 'stock': 5},
            {'id': 2, 'size': 'M,L,XL', 'stock': 5},
          ],
        },
      ],
    });
    await pumpScreen(tester, const ItemEditScreen(itemId: 1), container);
    await tester.pumpAndSettle();
  }

  testWidgets('null display_order renders the display-order field at a normal size',
      (tester) async {
    await pumpEditScreen(tester, displayOrder: null);

    // Null display_order falls back to the position in the variant title.
    expect(find.text('Variant #1'), findsOneWidget);

    // Expand the variant so the display-order row is rendered.
    await tester.tap(find.text('Variant #1'));
    await tester.pumpAndSettle();

    // The display-order field is wrapped in an explicit 96x32 box; it must not
    // expand into a long blank bar when the value is empty.
    final orderFieldBox = find.byWidgetPredicate(
      (w) => w is SizedBox && w.width == 96 && w.height == 32,
    );
    expect(orderFieldBox, findsOneWidget);

    final field = find.descendant(
      of: orderFieldBox,
      matching: find.byType(StockFlowTextField),
    );
    expect(field, findsOneWidget);
    expect(tester.widget<StockFlowTextField>(field).initialText, isEmpty);

    final size = tester.getSize(field);
    expect(size.width, closeTo(96, 0.1));
    expect(size.height, closeTo(32, 0.1));

    // Stock fields keep their compact fixed width (unchanged layout).
    final stockWidths = tester
        .widgetList<StockFlowTextField>(find.byType(StockFlowTextField))
        .length;
    expect(stockWidths, greaterThanOrEqualTo(3));
  });

  testWidgets('a stored display_order renders with the same bounded field',
      (tester) async {
    await pumpEditScreen(tester, displayOrder: '7');

    expect(find.text('Variant #7'), findsOneWidget);

    await tester.tap(find.text('Variant #7'));
    await tester.pumpAndSettle();

    final orderFieldBox = find.byWidgetPredicate(
      (w) => w is SizedBox && w.width == 96 && w.height == 32,
    );
    final field = find.descendant(
      of: orderFieldBox,
      matching: find.byType(StockFlowTextField),
    );
    expect(field, findsOneWidget);
    expect(tester.widget<StockFlowTextField>(field).initialText, '7');

    final size = tester.getSize(field);
    expect(size.width, closeTo(96, 0.1));
    expect(size.height, closeTo(32, 0.1));
  });
}