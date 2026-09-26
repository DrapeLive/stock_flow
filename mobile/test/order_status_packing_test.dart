import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stock_flow_admin/features/orders/order_status_screen.dart';

import 'helpers.dart';

// ---------------------------------------------------------------------------
// Fixtures: a two-item PENDING order (ITEM-A qty 2 x 4 pcs, ITEM-B qty 1 x 1
// pc) and a fully-packed single-item order.
// ---------------------------------------------------------------------------

Map<String, dynamic> _itemBJson() => {
      'id': 12,
      'name': 'ITEM-B',
      'type': 'gents',
      'price': '300',
      'description': 'Test item 2',
      'variants': [
        {
          'id': 200,
          'qr_code': 'QRTWO',
          'image': '',
          'display_order': '1',
          'sizes': [
            {'id': 3, 'size_range': 'S', 'stock': 5},
            {'id': 4, 'size_range': 'M,L,XL', 'stock': 5},
          ],
        },
      ],
    };

Map<String, dynamic> _itemEntryA({int packed = 0}) => {
      'id': 11,
      'item': itemJson(),
      'variant': 100,
      'size_group': 'S,M,L,XL',
      'size': 'M,L,XL',
      'item_name': 'ITEM-A',
      'item_price': '500',
      'variant_image': '',
      'quantity': 2,
      'original_quantity': 2,
      'packed_quantity': packed,
      'piece_count': 4,
      'variant_display_order': '1',
      'order': 1,
    };

Map<String, dynamic> _itemEntryB() => {
      'id': 12,
      'item': _itemBJson(),
      'variant': 200,
      'size_group': 'S,M,L,XL',
      'size': 'M,L,XL',
      'item_name': 'ITEM-B',
      'item_price': '300',
      'variant_image': '',
      'quantity': 1,
      'original_quantity': 1,
      'packed_quantity': 0,
      'piece_count': 1,
      'variant_display_order': '1',
      'order': 1,
    };

Map<String, dynamic> _twoItemOrderJson({int aPacked = 0}) {
  final order = orderJson();
  order['status'] = 'PENDING';
  order['items'] = [_itemEntryA(packed: aPacked), _itemEntryB()];
  order['total_quantity'] = '3';
  order['total_sets'] = 3;
  order['total_pieces'] = 9;
  return order;
}

Map<String, dynamic> _packedOrderJson() {
  final order = orderJson();
  order['status'] = 'PACKED';
  order['items'] = [_itemEntryA(packed: 8)];
  order['total_quantity'] = '2';
  order['total_sets'] = 2;
  order['total_pieces'] = 8;
  return order;
}

// ---------------------------------------------------------------------------

Future<void> _pumpOrderStatus(
  WidgetTester tester,
  ProviderContainer container,
  Map<String, dynamic> order,
) async {
  mockGet('/api/orders/1/', body: order);
  mockGet('/api/orders/1/logs/', body: const <Map<String, dynamic>>[]);
  mockGet('/api/transports/active/', body: [transportJson()]);
  mockItemSync();
  await pumpScreen(
      tester, const OrderStatusScreen(orderId: 1), container);
  await tester.pumpAndSettle();
}

double _dy(WidgetTester tester, String text) =>
    tester.getTopLeft(find.textContaining(text)).dy;

void main() {
  late ProviderContainer container;

  setUp(() async {
    await resetTestInfra();
    container = makeTestContainer();
    seedAdminSession();
    addTearDown(container.dispose);
  });

  testWidgets(
      'Bug 1: packed item stays in place during the session; only the saved '
      'server state re-sorts the list', (tester) async {
    useTallSurface(tester);
    await _pumpOrderStatus(tester, container, _twoItemOrderJson());

    await tester.tap(find.text('Update Packing'));
    await tester.pumpAndSettle();
    expect(find.text('Done Selecting'), findsOneWidget);

    expect(_dy(tester, 'ITEM-A') < _dy(tester, 'ITEM-B'), isTrue,
        reason: 'ITEM-A starts above ITEM-B');

    mockPatch('/api/orders/order-items/11/');
    await tester.tap(find.byIcon(Icons.radio_button_unchecked).first);
    await tester.pump();
    expect(find.byIcon(Icons.check_circle), findsOneWidget,
        reason: 'ITEM-A checkbox flipped instantly (optimistic)');
    expect(_dy(tester, 'ITEM-A') < _dy(tester, 'ITEM-B'), isTrue,
        reason: 'ITEM-A must NOT jump below ITEM-B while still ticking');

    await tester.pumpAndSettle();
    expect(_dy(tester, 'ITEM-A') < _dy(tester, 'ITEM-B'), isTrue,
        reason: 'still stable after the save round-trip completes');

    mockGet('/api/orders/1/', body: _twoItemOrderJson(aPacked: 8));
    await tester.tap(find.text('Done Selecting'));
    await tester.pumpAndSettle();
    expect(_dy(tester, 'ITEM-B') < _dy(tester, 'ITEM-A'), isTrue,
        reason: 're-sort only happens from saved server state, so unpacked '
            'ITEM-B rises after the packing session is saved/reloaded');
  });

  testWidgets(
      'Bug 2: a fully-packed order can still re-enter packing and unpack',
      (tester) async {
    useTallSurface(tester);
    await _pumpOrderStatus(tester, container, _packedOrderJson());

    expect(find.textContaining('Items to Dispatching'), findsOneWidget,
        reason: 'PACKED orders auto-open on the Dispatching tab');

    await tester.tap(find.text('Packing'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Items to Packing'), findsOneWidget);

    mockPatch('/api/orders/order-items/11/');
    mockPatch('/api/orders/1/');
    await tester.tap(find.text('Update Packing'));
    await tester.pumpAndSettle();

    expect(find.text('Done Selecting'), findsOneWidget,
        reason: 'entering packing mode must keep the Packing tab for a PACKED '
            'order, otherwise the checkbox could never be reached');
    expect(find.byIcon(Icons.check_circle), findsWidgets,
        reason: 'checkbox must be visible on the fully-packed PACKED order');

    await tester.tap(find.byIcon(Icons.check_circle).first);
    await tester.pumpAndSettle();
    expect(find.text('Unpack Items?'), findsOneWidget);

    await tester.tap(find.text('Unpack'));
    await tester.pumpAndSettle();

    expect(find.text('PENDING'), findsWidgets,
        reason: 'unpacking flips a PACKED order back to PENDING');
    expect(find.text('PACKED'), findsNothing);
    expect(find.byIcon(Icons.radio_button_unchecked), findsWidgets,
        reason: 'row shows the unpacked checkbox again');
    expect(find.textContaining('status changed to PENDING'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

<<<<<<< HEAD
  testWidgets('Bug 3: the Edit button is removed from the order item rows',
      (tester) async {
    useTallSurface(tester);
    await _pumpOrderStatus(tester, container, _twoItemOrderJson());

    expect(find.byIcon(Icons.edit_outlined), findsNothing,
        reason: 'pencil Edit button must no longer exist on the summary rows');
=======
  testWidgets('Bug 3: per-row Edit buttons stay removed; Edit lives only on '
        'the Order Summary header', (tester) async {
    useTallSurface(tester);
    await _pumpOrderStatus(tester, container, _twoItemOrderJson());

    expect(find.byIcon(Icons.edit_outlined), findsOneWidget,
        reason: 'exactly one pencil Edit button, on the summary header '
            '(next to Delete) - never on the item rows');
>>>>>>> dev
    expect(find.byIcon(Icons.delete_outline), findsWidgets,
        reason: 'delete stays available for pending/packed rows');
  });

  testWidgets(
      'Bug 4: Update Packing gives instant feedback (spinner + disabled) '
      'instead of a dead button', (tester) async {
    useTallSurface(tester);
    await _pumpOrderStatus(tester, container, _twoItemOrderJson());
    expect(find.text('Update Packing'), findsOneWidget);

    dioAdapter.onGet(
      '/api/orders/1/',
      (server) => server.reply(200, _twoItemOrderJson(),
          delay: const Duration(seconds: 30)),
    );

    await tester.tap(find.text('Update Packing'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget,
        reason: 'header button shows a spinner immediately');
    expect(find.text('Update Packing'), findsOneWidget,
        reason: 'still shows the pending action while the reload is in flight');

    await tester.tap(find.text('Update Packing'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget,
        reason: 'double-tap is a no-op while busy (button disabled)');

    await tester.pump(const Duration(seconds: 31));
    await tester.pump();
    expect(find.text('Done Selecting'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pumpAndSettle();

    mockGet('/api/orders/1/', body: _twoItemOrderJson());
    await tester.tap(find.text('Done Selecting'));
    await tester.pumpAndSettle();
    expect(find.text('Update Packing'), findsOneWidget);
  });
}