import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import 'package:stock_flow_admin/core/api/api_client.dart';
import 'package:stock_flow_admin/core/theme/app_theme.dart';
import 'package:stock_flow_admin/data/repositories.dart';
import 'package:stock_flow_admin/features/orders/order_flow_utils.dart';
import 'package:stock_flow_admin/features/orders/order_status_screen.dart';

import 'helpers.dart';

/// Regression tests for the Order Edit transaction.
///
/// The Edit button used to push the edit cart immediately, so the reused
/// scanner/search picker could POST `add-item` to an order the server had never
/// claimed (still PENDING/PACKED). It must now await `start-edit` and verify
/// the order really is EDITING before the cart is reachable.
void main() {
  late ProviderContainer container;
  late GoRouter router;

  const editCartMarker = 'Edit cart opened';

  Map<String, dynamic> pendingOrder() {
    final order = orderJson();
    order['status'] = 'PENDING';
    return order;
  }

  Future<void> pumpStatus(WidgetTester tester) async {
    mockGet('/api/orders/1/', body: pendingOrder());
    mockGet('/api/orders/1/logs/', body: const <Map<String, dynamic>>[]);
    mockGet('/api/transports/active/', body: [transportJson()]);
    mockItemSync();
    router = GoRouter(
      initialLocation: '/admin/order/status/1',
      routes: [
        GoRoute(
          path: '/admin/order/status/:id',
          builder: (_, __) => const OrderStatusScreen(orderId: 1),
        ),
        GoRoute(
          path: '/admin/order/status/:id/edit',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text(editCartMarker))),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() async {
    await resetTestInfra();
    container = makeTestContainer();
    seedAdminSession();
    // The session is a process-wide singleton that is only released when the
    // edit screen pops, so a test that never navigates would leak its order id
    // into the next one.
    OrderDraftSession.clear();
    addTearDown(container.dispose);
  });

  testWidgets(
      'Edit does not navigate until start-edit resolves and confirms EDITING',
      (tester) async {
    useTallSurface(tester);
    await pumpStatus(tester);
    expect(find.text(editCartMarker), findsNothing);

    dioAdapter.onPost(
      '/api/orders/1/start-edit/',
      (server) => server.reply(
        200,
        {'status': 'EDITING'},
        delay: const Duration(seconds: 30),
      ),
      data: Matchers.any,
    );

    await tester.tap(find.text('Edit'));
    await tester.pump();

    expect(find.text(editCartMarker), findsNothing,
        reason: 'the cart stays unreachable while start-edit is in flight');
    expect(find.byType(CircularProgressIndicator), findsOneWidget,
        reason: 'the Edit button shows progress and blocks a double tap');

    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();

    expect(find.text(editCartMarker), findsOneWidget,
        reason: 'navigates once the server confirms EDITING');
    expect(OrderDraftSession.orderId, 1,
        reason: 'add-item from the cart must target the order that was claimed');
  });

  testWidgets('Edit is blocked when the order is not EDITING after start-edit',
      (tester) async {
    useTallSurface(tester);
    await pumpStatus(tester);

    // The endpoint answers 200 but the order never leaves PENDING.
    dioAdapter.onPost(
      '/api/orders/1/start-edit/',
      (server) => server.reply(200, {'message': 'Edit started'}),
      data: Matchers.any,
    );
    mockGet('/api/orders/1/', body: pendingOrder());

    await tester.tap(find.text('Edit'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(editCartMarker), findsNothing,
        reason: 'no navigation without an EDITING order');
    expect(find.textContaining('still PENDING'), findsOneWidget);
    expect(OrderDraftSession.orderId, isNull);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('Edit surfaces the error and stays put when start-edit is rejected',
      (tester) async {
    useTallSurface(tester);
    await pumpStatus(tester);

    dioAdapter.onPost(
      '/api/orders/1/start-edit/',
      (server) => server.reply(403, {
        'error_message': 'You do not have permission to perform this action.',
      }),
      data: Matchers.any,
    );

    await tester.tap(find.text('Edit'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(editCartMarker), findsNothing);
    expect(find.textContaining('do not have permission'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget,
        reason: 'the button is re-enabled after the failure');
    expect(OrderDraftSession.orderId, isNull);
    await tester.pump(const Duration(seconds: 4));
  });

  test('startEdit posts to the order-scoped endpoint', () async {
    dioAdapter.onPost(
      '/api/orders/1/start-edit/',
      (server) => server.reply(200, {'status': 'EDITING'}),
      data: Matchers.any,
    );

    final status = await repos.order.startEdit(1);
    expect(status, 'EDITING');
  });

  /// The backend reads `expected_delivery_date` / `preferred_transport` /
  /// `notes`; the old payload sent `customer` / `lr_number` / `transport`, so
  /// the delivery date and transport were silently dropped on every save.
  test('saveEdit sends the field keys the backend reads', () async {
    dioAdapter.onPost(
      '/api/orders/1/save-edit/',
      (server) => server.reply(200, {'status': 'PENDING', 'order_id': 1}),
      data: const JsonBody({
        'expected_delivery_date': '2026-01-05',
        'preferred_transport': 7,
        'notes': 'call before delivery',
      }),
    );

    await repos.order.saveEdit(
      1,
      notes: 'call before delivery',
      preferredTransport: 7,
      expectedDeliveryDate: '2026-01-05',
    );
  });

  test('saveEdit accepts a packed order reverting to PACKED', () async {
    dioAdapter.onPost(
      '/api/orders/1/save-edit/',
      (server) => server.reply(200, {'status': 'PACKED', 'order_id': 1}),
      data: Matchers.any,
    );

    expect(await repos.order.saveEdit(1, notes: 'x'), 'PACKED');
  });

  test('saveEdit sends a null transport when none is picked', () async {
    dioAdapter.onPost(
      '/api/orders/1/save-edit/',
      (server) => server.reply(200, {'status': 'PENDING', 'order_id': 1}),
      data: const JsonBody({
        'expected_delivery_date': null,
        'preferred_transport': null,
        'notes': null,
      }),
    );

    await repos.order.saveEdit(1);
  });

  test('saveEdit fails when the order did not leave editing', () async {
    dioAdapter.onPost(
      '/api/orders/1/save-edit/',
      (server) => server.reply(200, {'status': 'EDITING', 'order_id': 1}),
      data: Matchers.any,
    );

    await expectLater(
      repos.order.saveEdit(1, notes: 'x'),
      throwsA(isA<ApiException>()),
    );
  });

  test('saveEdit falls back to re-reading the order without a status', () async {
    dioAdapter.onPost(
      '/api/orders/1/save-edit/',
      (server) => server.reply(200, {'message': 'Order saved successfully'}),
      data: Matchers.any,
    );
    mockGet('/api/orders/1/', body: pendingOrder());

    expect(await repos.order.saveEdit(1, notes: 'x'), 'PENDING');
  });

  test('cancelEdit posts to the order-scoped endpoint', () async {
    dioAdapter.onPost(
      '/api/orders/1/cancel-edit/',
      (server) => server.reply(200, {'status': 'PENDING', 'order_id': 1}),
      data: Matchers.any,
    );

    expect(await repos.order.cancelEdit(1), 'PENDING');
  });
}
