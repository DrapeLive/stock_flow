import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stock_flow_admin/features/items/items_screen.dart';
import 'package:stock_flow_admin/shared/widgets.dart';

import 'helpers.dart';

Map<String, dynamic> itemWithImageJson() {
  final base = stockEntryJson();
  base['image'] = '/media/items/test.jpg';
  return base;
}

Map<String, dynamic> stockEntryWithVariantImageJson() {
  final base = stockEntryJson();
  base['variants'][0]['image'] = '/media/items/variant.jpg';
  return base;
}

void main() {
  late ProviderContainer container;

  setUp(() async {
    await resetTestInfra();
    container = makeTestContainer();
    addTearDown(container.dispose);
  });

  Future<void> pumpItems(WidgetTester tester, dynamic stockBody) async {
    seedAdminSession();
    seedItemStore(stockBody);
    mockItemSync(items: stockBody);
    mockGet('/api/orders/order-items/unpacked/', body: [unpackedJson()]);
    mockGet('/api/items/size-ranges', body: sizeRangesJson());
    await pumpScreen(tester, const ItemsScreen(), container);
    await tester.pumpAndSettle();
  }

  Future<void> openPreview(WidgetTester tester) async {
    await tester.tap(find.byType(AppImage).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('tapping item thumbnail opens full-screen preview',
      (tester) async {
    useTallSurface(tester);
    await pumpItems(tester, [itemWithImageJson()]);

    expect(find.byType(AppImage), findsOneWidget);

    await openPreview(tester);

    expect(find.byTooltip('Close'), findsOneWidget);
  });

  testWidgets('preview closes via close button and Android back',
      (tester) async {
    useTallSurface(tester);
    await pumpItems(tester, [itemWithImageJson()]);

    await openPreview(tester);
    expect(find.byTooltip('Close'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byTooltip('Close'), findsNothing);
    expect(find.byType(ItemsScreen), findsOneWidget);

    await openPreview(tester);
    expect(find.byTooltip('Close'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byTooltip('Close'), findsNothing);
    expect(find.byType(ItemsScreen), findsOneWidget);
  });

  testWidgets('tapping variant image in an expanded item opens the preview',
      (tester) async {
    useTallSurface(tester);
    await pumpItems(tester, [stockEntryWithVariantImageJson()]);

    expect(find.byType(AppImage), findsOneWidget);
    await tester.tap(find.text('ITEM-A'));
    await tester.pumpAndSettle();
    expect(find.byType(AppImage), findsNWidgets(2));

    await tester.tap(find.byType(AppImage).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byTooltip('Close'), findsOneWidget);
  });

  testWidgets('variant without image stays non-tappable while item thumbnail opens preview',
      (tester) async {
    useTallSurface(tester);
    await pumpItems(tester, [itemWithImageJson()]);
    await tester.tap(find.text('ITEM-A'));
    await tester.pumpAndSettle();
    expect(find.byType(AppImage), findsNWidgets(2));

    await tester.tap(find.byType(AppImage).last);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Close'), findsNothing);

    await tester.tap(find.byType(AppImage).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byTooltip('Close'), findsOneWidget);
  });

  testWidgets('placeholder associated with an item without image is not tappable',
      (tester) async {
    useTallSurface(tester);
    await pumpItems(tester, [stockEntryJson()]);

    expect(find.byType(AppImage), findsOneWidget);

    await tester.tap(find.byType(AppImage).first);
    await tester.pumpAndSettle();

    expect(find.byTooltip('Close'), findsNothing);
  });
}