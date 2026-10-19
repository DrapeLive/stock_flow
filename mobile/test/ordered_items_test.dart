import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:stock_flow_admin/core/api/api_client.dart';
import 'package:stock_flow_admin/core/theme/app_theme.dart';
import 'package:stock_flow_admin/data/repositories.dart';
import 'package:stock_flow_admin/features/items/items_screen.dart';
import 'package:stock_flow_admin/features/items/ordered_items_screen.dart';

import 'helpers.dart';

String? lastOrderedLocation;

Future<void> pumpItemsRouter(
  WidgetTester tester,
  ProviderContainer container, {
  required List<Map<String, dynamic>> stockBody,
  required List<Map<String, dynamic>> unpackedBody,
}) async {
  lastOrderedLocation = null;
  final router = GoRouter(
    initialLocation: '/admin/items',
    routes: [
      GoRoute(path: '/admin/items', builder: (_, __) => const ItemsScreen()),
      GoRoute(
        path: '/admin/items/ordered/:id',
        builder: (_, s) {
          lastOrderedLocation = s.matchedLocation;
          return const Scaffold(body: SizedBox());
        },
      ),
    ],
  );
  seedAdminSession();
  seedItemStore(stockBody);
  mockItemSync(items: stockBody);
  mockGet('/api/orders/order-items/unpacked/', body: unpackedBody);
  mockGet('/api/items/size-ranges', body: sizeRangesJson());
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> pumpOrderedRouter(
  WidgetTester tester,
  ProviderContainer container, {
  int itemId = 21,
}) async {
  final router = GoRouter(
    initialLocation: '/admin/items/ordered/$itemId',
    routes: [
      GoRoute(
        path: '/admin/items/ordered/:id',
        builder: (_, s) => OrderedItemsScreen(
            itemId: int.parse(s.pathParameters['id'] ?? '0')),
      ),
      GoRoute(
        path: '/admin/items',
        builder: (_, __) => const Scaffold(body: SizedBox()),
      ),
    ],
  );
  seedAdminSession();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late ProviderContainer container;

  setUp(() async {
    await resetTestInfra();
    container = makeTestContainer();
    addTearDown(container.dispose);
  });

  group('ItemRepo.customerRequirements error mapping', () {
    test('maps a 404 to ApiException with statusCode and server detail', () async {
      mockGet('/api/items/customer-requirements/',
          query: const {'item_id': 21},
          status: 404,
          body: {
            'detail': 'OrderItem not found.',
          });
      await expectLater(
        repos.item.customerRequirements(21),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 404)
            .having((e) => e.message, 'message', 'OrderItem not found.')),
      );
    });

    test('passes through parsed data on success', () async {
      mockGet('/api/items/customer-requirements/',
          query: const {'item_id': 21}, body: customerRequirementsJson());
      final data = await repos.item.customerRequirements(21);
      expect((data['customers'] as List).length, 1);
      expect(
        ((data['customers'] as List).first as Map)['customer_name'],
        'XL Fashions',
      );
    });
  });

  group('ItemsScreen Ordered tab', () {
    testWidgets('tapping a live item pushes the OrderItem id, not the Item id',
        (tester) async {
      useTallSurface(tester);
      await pumpItemsRouter(tester, container,
          stockBody: [stockEntryJson()], unpackedBody: [unpackedJson()]);

      await tester.tap(find.text('Ordered (1)'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ITEM-A'));
      await tester.pumpAndSettle();

      expect(lastOrderedLocation, '/admin/items/ordered/21');
    });

    testWidgets(
        'deleted-item group stays tappable; the no-longer-available hint is '
        'left to the detail screen', (tester) async {
      useTallSurface(tester);
      await pumpItemsRouter(tester, container,
          stockBody: [stockEntryJson()],
          unpackedBody: [
            unpackedJson(),
            {
              'id': 22,
              'item_name': 'PHANTOM-ITEM',
              'item_type': 'kids',
              'variant_display_order': '2',
              'quantity': 1,
              'size_group': '20-36',
              'variant_image': '',
              'piece_count': 3,
            },
          ]);

      await tester.tap(find.text('Ordered (2)'));
      await tester.pumpAndSettle();

      expect(find.text('Item no longer available'), findsNothing);
      expect(find.text('PHANTOM-ITEM'), findsOneWidget);

      await tester.tap(find.text('PHANTOM-ITEM'));
      await tester.pumpAndSettle();

      expect(lastOrderedLocation, '/admin/items/ordered/22');
    });
  });

  group('OrderedItemsScreen error states', () {
    testWidgets('404 renders a friendly state, not a raw DioException',
        (tester) async {
      useTallSurface(tester);
      mockGet('/api/items/customer-requirements/',
          query: const {'item_id': 21},
          status: 404,
          body: {
            'detail': 'OrderItem not found.',
          });
      await pumpOrderedRouter(tester, container);

      expect(find.text('This item is no longer available'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Go back'), findsOneWidget);
      expect(find.textContaining('DioException'), findsNothing);
    });

    testWidgets('server error surfaces the backend detail with Retry + Go back',
        (tester) async {
      useTallSurface(tester);
      mockGet('/api/items/customer-requirements/',
          query: const {'item_id': 21},
          status: 500,
          body: {
            'detail': 'Server exploded.',
          });
      await pumpOrderedRouter(tester, container);

      expect(find.text('Could not load ordered items'), findsOneWidget);
      expect(find.text('Server exploded.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Go back'), findsOneWidget);
      expect(find.textContaining('DioException'), findsNothing);
    });

    testWidgets('Retry reloads and keeps the friendly error state',
        (tester) async {
      useTallSurface(tester);
      mockGet('/api/items/customer-requirements/',
          query: const {'item_id': 21},
          status: 404,
          body: {
            'detail': 'OrderItem not found.',
          });
      await pumpOrderedRouter(tester, container);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('This item is no longer available'), findsOneWidget);
      expect(find.textContaining('DioException'), findsNothing);
    });

    testWidgets('success renders customers, summary and item title',
        (tester) async {
      useTallSurface(tester);
      mockGet('/api/items/customer-requirements/',
          query: const {'item_id': 21}, body: customerRequirementsJson());
      await pumpOrderedRouter(tester, container);

      expect(find.text('ITEM-A'), findsOneWidget);
      expect(find.text('CUSTOMERS'), findsOneWidget);
      expect(find.text('ORDERED BY'), findsOneWidget);
      expect(find.text('XL Fashions'), findsOneWidget);
    });
  });
}