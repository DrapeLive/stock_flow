import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stock_flow_admin/features/items/item_wizard_screen.dart';
import 'package:stock_flow_admin/shared/widgets.dart';

import 'helpers.dart';

void main() {
  late ProviderContainer container;

  setUp(() async {
    await resetTestInfra();
    container = makeTestContainer();
    addTearDown(container.dispose);
  });

  Future<void> pumpWizard(WidgetTester tester, {String? business}) async {
    useTallSurface(tester);
    seedAdminSession(business: business);
    mockGet('/api/items/size-ranges', body: sizeRangesJson());
    await pumpScreen(tester, const ItemWizardScreen(), container);
    await tester.pumpAndSettle();
  }

  TextField step1Field(WidgetTester tester, int index) =>
      tester.widget<TextField>(find.descendant(
        of: find.byType(StockFlowTextField).at(index),
        matching: find.byType(TextField),
      ));

  Future<void> typeInto(
      WidgetTester tester, int index, String text) async {
    await tester.enterText(
      find.descendant(
        of: find.byType(StockFlowTextField).at(index),
        matching: find.byType(TextField),
      ),
      text,
    );
  }

  testWidgets('business admin has no Type selector', (tester) async {
    await pumpWizard(tester, business: 'kids');

    expect(find.text('Type *'), findsNothing);
    expect(find.text('Gents'), findsNothing);
    expect(find.text('Kids'), findsNothing);

    // Three stable fields: name, description, price.
    expect(find.byType(StockFlowTextField), findsNWidgets(3));
  });

  testWidgets('business admin: Next/Back keeps step-1 text', (tester) async {
    await pumpWizard(tester, business: 'kids');

    await typeInto(tester, 0, 'Classic Round-Neck Tee');
    await typeInto(tester, 2, '499');
    await tester.pump();

    // Rebuilds (focus change) must not scramble the typed text.
    await tester.tap(find.descendant(
      of: find.byType(StockFlowTextField).at(1),
      matching: find.byType(TextField),
    ));
    await tester.pump();
    expect(step1Field(tester, 0).controller!.text, 'Classic Round-Neck Tee');
    expect(step1Field(tester, 2).controller!.text, '499');

    // Next -> variant form, then back -> Step 1 retains entered text.
    await tester.tap(find.byType(StockFlowButton));
    await tester.pumpAndSettle();
    expect(find.text('Variant #1'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(step1Field(tester, 0).controller!.text, 'Classic Round-Neck Tee');
    expect(step1Field(tester, 2).controller!.text, '499');
  });

  testWidgets('no-business admin must explicitly pick a Type',
      (tester) async {
    await pumpWizard(tester, business: null);

    expect(find.text('Type *'), findsOneWidget);
    expect(find.text('Gents'), findsOneWidget);
    expect(find.text('Kids'), findsOneWidget);

    await typeInto(tester, 0, 'Classic Tee');
    await tester.pump();

    // Name alone is not enough: price + type are required too.
    expect(
        tester.widget<StockFlowButton>(find.byType(StockFlowButton)).enabled,
        isFalse);

    // A zero price is rejected with a clear message.
    await typeInto(tester, 2, '0');
    await tester.pump();
    expect(find.text('Enter a price greater than 0'), findsOneWidget);
    expect(
        tester.widget<StockFlowButton>(find.byType(StockFlowButton)).enabled,
        isFalse);

    await typeInto(tester, 2, '499');
    await tester.pump();

    // Still disabled until a Type is chosen.
    expect(
        tester.widget<StockFlowButton>(find.byType(StockFlowButton)).enabled,
        isFalse);

    await tester.tap(find.text('Kids'));
    await tester.pump();
    expect(
        tester.widget<StockFlowButton>(find.byType(StockFlowButton)).enabled,
        isTrue);
  });
}