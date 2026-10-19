import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:stock_flow_admin/core/theme/app_theme.dart';
import 'package:stock_flow_admin/features/items/item_edit_screen.dart';
import 'package:stock_flow_admin/features/summary/summary_screen.dart';

import 'helpers.dart';

/// Builds `count` stock entries with distinct ids + names so the breakdown
/// table is long enough to scroll.
List<Map<String, dynamic>> manyStockEntries(int count) => [
      for (var i = 0; i < count; i++)
        {
          ...stockEntryJson(),
          'id': 1000 + i,
          'name': 'ITEM-${i.toString().padLeft(2, '0')}',
        },
    ];

/// ItemEditScreen keeps `_loading: true` when its fetch fails, so every id the
/// test might land on needs a mock or the screen spins forever.
void mockItemOneFor(int fromId, int count) {
  for (var i = 0; i < count; i++) {
    mockGet('/api/items/${fromId + i}/', body: itemJson());
  }
}

late String lastEditLocation;

Future<GoRouter> pumpSummaryRouter(
  WidgetTester tester,
  ProviderContainer container,
) async {
  lastEditLocation = '';
  final router = GoRouter(
    initialLocation: '/admin/summary',
    routes: [
      GoRoute(path: '/admin/summary', builder: (_, __) => const SummaryScreen()),
      GoRoute(
        path: '/admin/items/edit/:id',
        builder: (_, s) {
          lastEditLocation = s.matchedLocation;
          return ItemEditScreen(itemId: int.parse(s.pathParameters['id'] ?? '0'));
        },
      ),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

/// The breakdown's own scroll controller, read off the ListView so the test
/// asserts the real production controller rather than a stand-in.
ScrollController summaryScrollController(WidgetTester tester) =>
    tester.widget<ListView>(find.byType(ListView).first).controller!;

/// Name text of a breakdown row that is fully inside the viewport right now.
Finder? visibleItemName(WidgetTester tester) {
  final viewport = tester.getRect(find.byType(ListView).first);
  final names = find.byWidgetPredicate(
    (w) => w is Text && (w.data ?? '').startsWith('ITEM-'),
  );
  for (var i = 0; i < names.evaluate().length; i++) {
    final f = names.at(i);
    final r = tester.getRect(f);
    if (r.top > viewport.top && r.bottom < viewport.bottom) return f;
  }
  return null;
}

void main() {
  late ProviderContainer container;

  setUp(() async {
    await resetTestInfra();
    container = makeTestContainer();
    addTearDown(container.dispose);
    seedAdminSession();
  });

  testWidgets('tapping a breakdown row pushes ItemEditScreen with that item id',
      (tester) async {
    mockGet('/api/items/stock-list/', body: [stockEntryJson()]);
    mockGet('/api/items/10/', body: itemJson());
    mockGet('/api/items/size-ranges', body: sizeRangesJson());
    useTallSurface(tester);

    final router = await pumpSummaryRouter(tester, container);
    addTearDown(router.dispose);

    expect(find.text('ITEM-A'), findsOneWidget);

    await tester.tap(find.text('ITEM-A'));
    await tester.pumpAndSettle();

    // Pushed, not replaced: Summary is still in the tree underneath (GoRouter
    // offstages the covered page, hence skipOffstage: false).
    expect(find.byType(ItemEditScreen), findsOneWidget);
    expect(find.byType(SummaryScreen, skipOffstage: false), findsOneWidget);
    expect(lastEditLocation, '/admin/items/edit/10');
    // The edit screen is really rendering the id it was handed.
    expect(find.text('ID #10'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.byType(ItemEditScreen), findsNothing);
    expect(find.text('ITEM-A'), findsOneWidget);
  });

  testWidgets('the tapped row decides the id, not the first row',
      (tester) async {
    mockGet('/api/items/stock-list/', body: manyStockEntries(4));
    mockItemOneFor(1000, 4);
    mockGet('/api/items/size-ranges', body: sizeRangesJson());
    useTallSurface(tester);

    final router = await pumpSummaryRouter(tester, container);
    addTearDown(router.dispose);

    // Rows sort by name descending, so ITEM-03 leads and ITEM-01 is last.
    await tester.tap(find.text('ITEM-01'));
    await tester.pumpAndSettle();

    expect(lastEditLocation, '/admin/items/edit/1001');
    expect(find.text('ID #1001'), findsOneWidget);
  });

  testWidgets('breakdown scroll offset survives a push/pop round trip',
      (tester) async {
    mockGet('/api/items/stock-list/', body: manyStockEntries(60));
    mockGet('/api/items/1002/', body: itemJson());
    mockGet('/api/items/size-ranges', body: sizeRangesJson());
    useTallSurface(tester);

    final router = await pumpSummaryRouter(tester, container);
    addTearDown(router.dispose);

    final controller = summaryScrollController(tester);
    expect(controller.offset, 0);

    await tester.drag(find.byType(ListView).first, const Offset(0, -1200));
    await tester.pumpAndSettle();
    final before = controller.offset;
    expect(before, greaterThan(0));

    router.push('/admin/items/edit/1002');
    await tester.pumpAndSettle();
    expect(find.byType(ItemEditScreen), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();

    expect(find.byType(SummaryScreen), findsOneWidget);
    expect(controller.offset, before);
  });

  testWidgets('tapping a row then returning keeps the scroll offset and refreshes the row',
      (tester) async {
    final before_ = manyStockEntries(60);
    // Item 1002's price and stock change in the edit screen: the fixture row is
    // 5x'S' + 5x'M,L,XL' = 5*1 + 5*3 = 20 pieces at 500 (10,000), which
    // becomes 7x'S' + 7x'M,L,XL' = 28 pieces at 999 (27,972).
    final after_ = manyStockEntries(60)
      ..[2] = {
        ...stockEntryJson(),
        'id': 1002,
        'price': '999',
        'variants': [
          {
            'id': 100,
            'qr_code': 'QRONE',
            'image': '',
            'sizes': [
              {'size_range': 'S', 'stock': 7},
              {'size_range': 'M,L,XL', 'stock': 7},
            ],
            'total_stock': 14,
            'display_order': '1',
            'created_at': '',
          },
        ],
      };
    var stockCalls = 0;
    dioAdapter.onGet('/api/items/stock-list/', (server) {
      stockCalls++;
      return server.reply(200, before_);
    });
    mockItemOneFor(1000, 60);
    mockGet('/api/items/size-ranges', body: sizeRangesJson());
    useTallSurface(tester);

    final router = await pumpSummaryRouter(tester, container);
    addTearDown(router.dispose);

    final controller = summaryScrollController(tester);
    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await tester.pumpAndSettle();
    final offsetBefore = controller.offset;
    expect(offsetBefore, greaterThan(0));
    expect(find.textContaining('10,000.00'), findsWidgets);

    final target = visibleItemName(tester);
    expect(target, isNotNull, reason: 'no fully-visible breakdown row');
    await tester.tap(target!);
    await tester.pumpAndSettle();
    expect(find.byType(ItemEditScreen), findsOneWidget);

    // The edit screen saved a new price/stock for item 1002, and
    // ItemRepo.update invalidated the `items` cache namespace. Re-register the
    // stock-list mock: http_mock_adapter replays a recorded reply for a
    // repeated identical request, so the LAST registration is the one the
    // return-refresh will see.
    mockGet('/api/items/stock-list/', body: after_);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.byType(SummaryScreen), findsOneWidget);
    // Scroll position is untouched by the round trip...
    expect(controller.offset, offsetBefore);
    // ...and the breakdown reflects the price + stock change made in the edit
    // screen: 28 pieces, 28 * 999. `_items` is only ever replaced by `_load()`,
    // so seeing the new figures proves the return-refresh actually happened.
    expect(stockCalls, 1);
    expect(find.textContaining('27,972.00'), findsOneWidget);
    expect(find.text('28'), findsOneWidget);
  });
}