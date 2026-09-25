import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stock_flow_admin/features/items/items_screen.dart';

void main() {
  testWidgets(
      'Ordered-tab card for a still-existing (renamed) item is tappable and '
      'not blocked with "Item no longer available"', (tester) async {
    var tapped = false;

    // Regression: the old gate compared the order row's *order-time* name
    // snapshot against the sync store's *current* item names. A valid item
    // that was renamed after the order matched nothing locally and was
    // rendered non-tappable with "Item no longer available".
    final group = <UnpackedItem>[
      const UnpackedItem(
        id: 42,
        itemName: 'Old Name',
        itemType: 'gents',
        variantDisplayOrder: '1',
        quantity: 2,
        sizeGroup: 'Set-M',
        pieceCount: 3,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrderedGroupCard(group: group, onTap: () => tapped = true),
        ),
      ),
    );

    expect(find.byType(OrderedGroupCard), findsOneWidget);
    expect(find.text('Item no longer available'), findsNothing);

    await tester.tap(find.byType(OrderedGroupCard));
    await tester.pump();
    expect(tapped, isTrue);
  });
}