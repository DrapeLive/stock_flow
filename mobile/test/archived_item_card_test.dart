import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stock_flow_admin/features/profile/archived_item_card.dart';
import 'package:stock_flow_admin/models/models.dart';

Item _item({
  String name = 'Denim Shirt',
  String type = 'kids',
  String price = '340.00',
  int? daysUntilPurge,
}) {
  return Item(
    id: 1,
    name: name,
    type: type,
    price: price,
    variants: [
      ItemVariant(
        id: 10,
        sizes: [
          ItemVariantSize(sizeRange: 'Set-S', stock: 0),
          ItemVariantSize(sizeRange: 'Set-M', stock: 4),
        ],
      ),
    ],
    daysUntilPurge: daysUntilPurge,
  );
}

Widget _wrap(Widget card, {double width = 280, double textScale = 1.0}) {
  return MaterialApp(
    home: Scaffold(body: MediaQuery(data: MediaQueryData(textScaler: TextScaler.linear(textScale)), child: SizedBox(width: width, child: card))),
  );
}

void main() {
  testWidgets('archived card price renders via the shared INR formatter',
      (tester) async {
    await tester.pumpWidget(_wrap(ArchivedItemCard(
      item: _item(price: '340.00'),
      expanded: false,
      onToggle: () {},
    )));

    expect(find.text('₹340.00'), findsOneWidget);
    expect(find.textContaining('â‚¹'), findsNothing);
    expect(find.textContaining('â'), findsNothing);
  });

  testWidgets(
      'archived card does not overflow with a long name, 3-digit price and '
      '"Deletes in 20 days" at large text scale', (tester) async {
    await tester.pumpWidget(_wrap(
      ArchivedItemCard(
        item: _item(
          name: 'Premium Extra Long Denim Overcoat Full Sleeve',
          type: 'kids',
          price: '999.99',
          daysUntilPurge: 20,
        ),
        expanded: false,
        onToggle: () {},
      ),
      width: 260,
      textScale: 1.3,
    ));

    expect(tester.takeException(), isNull);
    expect(find.text('Deletes in 20 days'), findsOneWidget);
    expect(find.text('4 stock'), findsOneWidget);
  });

  testWidgets('archived card never overflows even when fully expanded',
      (tester) async {
    await tester.pumpWidget(_wrap(
      ArchivedItemCard(
        item: _item(
          name: 'Premium Extra Long Denim Overcoat Full Sleeve',
          type: 'kids',
          price: '999.99',
          daysUntilPurge: 20,
        ),
        expanded: true,
        onToggle: () {},
      ),
      width: 260,
      textScale: 1.3,
    ));

    expect(tester.takeException(), isNull);
  });

  testWidgets('archived card renders no UTF-8 mojibake in any text',
      (tester) async {
    await tester.pumpWidget(_wrap(
      ArchivedItemCard(item: _item(), expanded: true, onToggle: () {}),
    ));

    final texts = <String>[];
    for (final w in tester.allWidgets) {
      if (w is Text) {
        if (w.data != null) texts.add(w.data!);
        final span = w.textSpan;
        if (span != null) texts.add(span.toPlainText());
      } else if (w is RichText) {
        texts.add(w.text.toPlainText());
      }
    }

    // Variant rows use the shared middle-dot constant, never the corrupted
    // "Â·" sequence.
    for (final t in texts) {
      for (final m in const ['â', 'Â', 'Ã']) {
        expect(t.contains(m), isFalse,
            reason: 'found "$m" mojibake marker in rendered text: "$t"');
      }
    }
  });
}