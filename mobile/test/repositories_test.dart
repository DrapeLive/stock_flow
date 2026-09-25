import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import 'package:stock_flow_admin/core/api/api_client.dart';
import 'package:stock_flow_admin/core/cache/app_cache.dart';
import 'package:stock_flow_admin/data/repositories.dart';

import 'helpers.dart';

const _pagination = <String, dynamic>{'page': 1, 'page_size': 50};

void main() {
  setUp(() async {
    await resetTestInfra();
  });

  group('AuthRepo', () {
    test('login returns a Session for ADMIN', () async {
      mockPost('/api/auth/login/', body: loginResponseJson());

      final session = await repos.auth.login('admin@xl.in', 'secret');
      expect(session.access, 'mock-access-token');
      expect(session.user.role, 'ADMIN');
      expect(session.user.isSuperuser, isTrue);
    });

    test('login rejects non-ADMIN roles', () async {
      mockPost('/api/auth/login/',
          body: {...loginResponseJson(), 'role': 'AGENT'});

      expect(
        () => repos.auth.login('agent@xl.in', 'secret'),
        throwsA(isA<ApiException>()),
      );
    });

    test('profile parses AuthUser', () async {
      mockGet('/api/auth/profile/',
          body: {...loginResponseJson(), 'id': 1});

      final user = await repos.auth.profile();
      expect(user.role, 'ADMIN');
      expect(user.email, 'admin@xlapparals.in');
    });

    test('forgot/reset password hit the right endpoints', () async {
      mockPost('/api/auth/forgot-password/');
      mockPost('/api/auth/reset-password/');

      await repos.auth.forgotPassword('admin@xl.in');
      await repos.auth.resetPassword('tok', 'newpass123');
    });
  });

  group('OrderRepo', () {
    test('getAll parses a paginated response', () async {
      mockGet('/api/orders/',
          query: const {'page': 1, 'page_size': 50, 'status': ['PENDING']},
          body: paginatedOrderJson());

      final page = await repos.order.getAll(
        const OrderFilters(statuses: ['PENDING']),
      );
      expect(page.count, 1);
      expect(page.results.single.id, 1);
      expect(page.results.single.status, 'PENDING');
    });

    test('getAll caches then serves from network on refetch', () async {
      mockGet('/api/orders/',
          query: const {'page': 1, 'page_size': 50},
          body: paginatedOrderJson());

      await repos.order.getAll(const OrderFilters());
      // Second call within the same adapter still hits the mock (network-first).
      final again = await repos.order.getAll(const OrderFilters());
      expect(again.count, 1);
    });

    test('getOne/archived/byCustomer', () async {
      mockGet('/api/orders/1/', body: orderJson());
      mockGet('/api/orders/archived/',
          query: _pagination, body: paginatedOrderJson());
      mockGet('/api/orders/',
          query: const {'customer': 3, 'page': 1, 'page_size': 50},
          body: paginatedOrderJson());

      final one = await repos.order.getOne(1);
      expect(one.customer.name, 'XL Fashions');

      final archived = await repos.order.archived();
      expect(archived.results.single.id, 1);

      final byCustomer = await repos.order.byCustomer(3);
      expect(byCustomer.count, 1);
    });

    test('getLogs + unpacked parse lists', () async {
      mockGet('/api/orders/1/logs/',
          body: [
            {'id': 9, 'action': 'VIEWED', 'performed_by': 'admin'},
          ]);
      mockGet('/api/orders/order-items/unpacked/', body: [unpackedJson()]);

      final logs = await repos.order.getLogs(1);
      expect(logs.single.action, 'VIEWED');

      final unpacked = await repos.order.unpacked();
      expect(unpacked.single['item_name'], 'ITEM-A');
    });

    test('viewed ids + all ids int helpers', () async {
      mockGet('/api/orders/my-viewed-ids/', body: [1, 2, 3]);
      mockGet('/api/orders/order-ids/',
          body: [
            {'id': 1, 'status': 'PENDING'},
            {'id': 2, 'status': 'PACKED'},
          ]);

      final viewed = await repos.order.getViewedIds();
      expect(viewed, [1, 2, 3]);

      final all = await repos.order.allIds();
      expect(all, hasLength(2));
      expect(all.first.status, 'PENDING');
    });

    test('writes invalidate cached namespaces', () async {
      mockGet('/api/orders/',
          query: const {'page': 1, 'page_size': 50},
          body: paginatedOrderJson());
      mockPatch('/api/orders/1/');

      await repos.order.getAll(const OrderFilters());
      await repos.order.update(1, {'status': 'PACKED'});

      // The cache should now be empty so a refetch goes back to the network.
      final ts = canReadCache('orders');
      expect(ts, isFalse);
    });

    test('markViewed / deleteItem / dispatch / delete', () async {
      mockPost('/api/orders/1/mark-viewed/');
      mockDelete('/api/orders/1/delete-item/11/');
      mockPost('/api/orders/1/dispatch/');
      mockDelete('/api/orders/1/');

      await repos.order.markViewed(1);
      await repos.order.deleteItem(1, 11);
      await repos.order.dispatch(1, transportCompany: 1, lrNumber: 'LR-1');
      await repos.order.delete(1, '123456');
    });

    test('create parses the draft order', () async {
      mockPost('/api/orders/', body: orderJson());

      final order = await repos.order.create(customer: 3, agent: 2);
      expect(order.id, 1);
      expect(order.customer.name, 'XL Fashions');
    });

    test('addItem posts the exact qr/quantity/size_group body', () async {
      dioAdapter.onPost(
        '/api/orders/1/add-item/',
        (server) => server.reply(201, const <String, dynamic>{}),
        data: {'qr_code': 'QRONE', 'quantity': 2, 'size_group': 'S,M,L,XL'},
      );

      await repos.order.addItem(1,
          qrCode: 'QRONE', quantity: 2, sizeGroup: 'S,M,L,XL');
    });

    test('addItem surfaces backend validation errors (400)', () async {
      dioAdapter.onPost(
        '/api/orders/1/add-item/',
        (server) => server.reply(400, {
          'error_message':
              'Order can only contain items of gents type, this is kids',
        }),
        data: Matchers.any,
      );

      expect(
        () => repos.order.addItem(1,
            qrCode: 'QRONE', quantity: 2, sizeGroup: 'S,M,L,XL'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 400)
            .having((e) => e.message, 'message',
                contains('only contain items of gents type'))),
      );
    });

    test('addItem invalidates order/orders/unpacked/dash caches', () async {
      mockGet('/api/orders/1/', body: orderJson());
      mockGet('/api/orders/',
          query: const {'page': 1, 'page_size': 50},
          body: paginatedOrderJson());
      mockGet('/api/orders/order-items/unpacked/', body: [unpackedJson()]);
      dioAdapter.onPost(
        '/api/orders/1/add-item/',
        (server) => server.reply(201, const <String, dynamic>{}),
        data: {'qr_code': 'QRONE', 'quantity': 2, 'size_group': 'S,M,L,XL'},
      );

      await repos.order.getOne(1);
      await repos.order.getAll(const OrderFilters());
      await repos.order.unpacked();
      expect(canReadCache('order'), isTrue);
      expect(canReadCache('orders'), isTrue);
      expect(canReadCache('unpacked'), isTrue);

      await repos.order.addItem(1,
          qrCode: 'QRONE', quantity: 2, sizeGroup: 'S,M,L,XL');

      // A subsequent getOne must refetch from the network instead of serving
      // the stale pre-add snapshot.
      expect(canReadCache('order'), isFalse);
      expect(canReadCache('orders'), isFalse);
      expect(canReadCache('unpacked'), isFalse);
      expect(canReadCache('dash'), isFalse);
    });

    test('place hits the place-order endpoint', () async {
      mockPost('/api/orders/1/place-order/');

      await repos.order.place(1,
          expectedDeliveryDate: '2026-09-01',
          preferredTransport: 1,
          notes: 'rush');
    });

    test('startEdit hits start-edit and invalidates order caches', () async {
      mockGet('/api/orders/1/', body: orderJson());
      await repos.order.getOne(1);
      expect(canReadCache('order'), isTrue);

      mockPost('/api/orders/1/start-edit/');
      await repos.order.startEdit(1);

      expect(canReadCache('order'), isFalse);
      expect(canReadCache('orders'), isFalse);
    });

    test('saveEdit posts the delivery/transport/notes payload', () async {
      dioAdapter.onPost(
        '/api/orders/1/save-edit/',
        (server) => server.reply(200, const <String, dynamic>{}),
        data: {
          'expected_delivery_date': '2026-09-10',
          'preferred_transport': 2,
          'notes': 'revised qty',
        },
      );

      await repos.order.saveEdit(1,
          expectedDeliveryDate: '2026-09-10',
          preferredTransport: 2,
          notes: 'revised qty');
    });

    test('cancelEdit hits cancel-edit', () async {
      mockPost('/api/orders/1/cancel-edit/');

      await repos.order.cancelEdit(1);
    });
  });

  group('ItemRepo', () {
    test('stockList + sizeRanges', () async {
      mockGet('/api/items/stock-list/', body: [stockEntryJson()]);
      mockGet('/api/items/size-ranges', body: sizeRangesJson());

      final stock = await repos.item.stockList();
      expect(stock.single.name, 'ITEM-A');

      final ranges = await repos.item.sizeRanges();
      expect(
        (ranges['order_creation_sizes_by_type']
                as Map<String, dynamic>)['gents'],
        contains('S,M,L,XL'),
      );
    });

    test('archived / getOne / byqrcode / allVariants', () async {
      mockGet('/api/items/archived/', body: [itemJson()]);
      mockGet('/api/items/10/', body: itemJson());
      mockGet('/api/items/by-qr/',
          query: const {'qr_code': 'QRONE'}, body: itemJson());
      mockGet('/api/items/variants/all/', body: [variantAllJson()]);

      final archived = await repos.item.archived();
      expect(archived.single.name, 'ITEM-A');

      final one = await repos.item.getOne(10);
      expect(one.id, 10);

      final byqr = await repos.item.byqrcode('QRONE');
      expect(byqr['name'], 'ITEM-A');

      final variants = await repos.item.allVariants();
      expect(variants.single.itemName, 'ITEM-A');
      expect(variants.single.uniqueSizes, ['S', 'M', 'L', 'XL']);
    });

    test('customer requirements endpoint', () async {
      mockGet('/api/items/customer-requirements/',
          query: const {'item_id': 10}, body: customerRequirementsJson());

      final reqs = await repos.item.customerRequirements(10);
      expect((reqs['customers'] as List).single['customer_name'], 'XL Fashions');
    });

    test('byQr parses matched variant + sizes (admin omits agent_id)', () async {
      mockGet('/api/items/by-qr/',
          query: const {'qr_code': 'QRONE'},
          body: {
            'id': 10,
            'name': 'ITEM-A',
            'type': 'gents',
            'price': '500',
            'description': 'Test item',
            'matched_variant_id': 100,
            'variants': [
              {
                'id': 100,
                'qr_code': 'QRONE',
                'image': '',
                'display_order': '1',
                'sizes': [
                  {'size_range': 'S', 'stock': 5},
                  {'size_range': 'M,L,XL', 'stock': 5},
                ],
              },
            ],
          });

      final result = await repos.item.byQr('QRONE');
      expect(result.name, 'ITEM-A');
      expect(result.matchedVariantId, 100);
      expect(result.variants.single.qrCode, 'QRONE');
      expect(result.variants.single.sizes, hasLength(2));
    });

    test('checkOutOfStock parses the group stock map', () async {
      mockGet('/api/items/by-qr/out-of-stock/',
          query: const {'qr_code': 'QRONE', 'order_id': 1},
          body: {
            'out_of_stock': true,
            'group_stock': {'S,M,L,XL': 0},
          });

      final result = await repos.item.checkOutOfStock('QRONE', orderId: 1);
      expect(result.outOfStock, isTrue);
      expect(result.groupStock['S,M,L,XL'], 0);
    });

    test('checkOutOfStock parses the dev-backend multi-group shape', () async {
      mockGet('/api/items/by-qr/out-of-stock/',
          query: const {'qr_code': 'QRONE', 'order_id': 5},
          body: {
            'out_of_stock': false,
            'group_stock': {
              'S,M,L,XL': 8,
              'M,L,XL': 5,
              '20-36': 3,
            },
          });

      final result = await repos.item.checkOutOfStock('QRONE', orderId: 5);
      expect(result.outOfStock, isFalse);
      expect(result.groupStock, {
        'S,M,L,XL': 8,
        'M,L,XL': 5,
        '20-36': 3,
      });
    });

    test('checkOutOfStock omits order_id when none is given', () async {
      mockGet('/api/items/by-qr/out-of-stock/',
          query: const {'qr_code': 'QRONE'},
          body: {'out_of_stock': false, 'group_stock': <String, int>{}});

      final result = await repos.item.checkOutOfStock('QRONE');
      expect(result.outOfStock, isFalse);
      expect(result.groupStock, isEmpty);
    });

    test('create/update/delete call through and invalidate', () async {
      mockPost('/api/items/', body: itemJson());
      mockPut('/api/items/10/', body: itemJson());
      mockDelete('/api/items/10/');

      final created = await repos.item
          .create({'name': 'ITEM-A', 'price': '500', 'type': 'gents'});
      expect(created.id, 10);
      await repos.item.update(10, {'price': '550'});
      await repos.item.delete(10, '123456');
    });
  });

  group('CustomerRepo', () {
    test('list parses a paginated page', () async {
      mockGet('/api/customers/', query: _pagination,
          body: {
            'count': 1,
            'next': null,
            'previous': null,
            'results': [customerJson()],
          });

      final page = await repos.customer.list();
      expect(page.results.single.name, 'XL Fashions');
      expect(page.results.single.agentName, 'Agent Alpha');
    });

    test('list sends search when provided', () async {
      mockGet('/api/customers/',
          query: const {'page': 1, 'page_size': 50, 'search': 'XL'},
          body: {'count': 0, 'results': <Map<String, dynamic>>[]});

      final page = await repos.customer.list(search: 'XL');
      expect(page.count, 0);
    });

    test('bulkImport returns created + errors', () async {
      mockPost('/api/customers/bulk-import/',
          body: {
            'created': 2,
            'errors': [
              {'row': 3, 'name': 'Bad Row', 'error': 'invalid contact'},
            ],
          });

      final result = await repos.customer.bulkImport([
        {'name': 'A', 'contact': '1'},
        {'name': 'B', 'contact': '2'},
      ]);
      expect(result.created, 2);
      expect(result.errors, hasLength(1));
      expect(result.errors.single.$1, 3);
      expect(result.errors.single.$2, 'Bad Row');
    });

    test('getOne/create/update/delete/deleteInfo', () async {
      mockGet('/api/customers/3/', body: customerJson());
      mockPost('/api/customers/', body: customerJson());
      mockPatch('/api/customers/3/', body: customerJson());
      mockGet('/api/customers/3/delete_info/',
          body: {'orders_count': 4, 'customers_count': 0});
      mockDelete('/api/customers/3/');

      final one = await repos.customer.getOne(3);
      expect(one.name, 'XL Fashions');

      final created = await repos.customer.create({'name': 'X'});
      expect(created.id, 3);

      await repos.customer.update(3, {'name': 'Y'});
      await repos.customer.deleteInfo(3);
      await repos.customer.delete(3, '123456');
    });
  });

  group('AgentRepo', () {
    test('list/getOne', () async {
      mockGet('/api/agents/', body: [agentJson()]);
      mockGet('/api/agents/2/', body: agentJson());

      final agents = await repos.agent.list();
      expect(agents.single.displayName, 'Agent Alpha');

      final one = await repos.agent.getOne(2);
      expect(one.id, 2);
    });

    test('getOne falls back to cached agents list when network fails', () async {
      mockGet('/api/agents/', body: [agentJson()]);

      await repos.agent.list();
      // The detail endpoint is unmocked -> network call throws; the cached
      // agents list entry is used as a fallback instead of rethrowing.
      final one = await repos.agent.getOne(2);
      expect(one.id, 2);
      expect(one.displayName, 'Agent Alpha');
      expect(one.user.email, 'alpha@xlapparals.in');
    });

    test('item assignment + transfer/copy/delete flows', () async {
      mockPost('/api/agents/2/items/');
      mockPost('/api/agents/2/items/transfer/');
      mockPost('/api/agents/2/items/copy/');
      mockDelete('/api/agents/2/items/');
      mockDelete('/api/agents/2/');
      mockGet('/api/agents/2/delete_info/',
          body: {'orders_count': 5, 'customers_count': 3});

      await repos.agent.updateItems(2, [100]);
      await repos.agent.transferItems(2, 3);
      await repos.agent.copyItems(2, 3);
      await repos.agent.deleteAllItems(2);
      await repos.agent.deleteInfo(2);
      await repos.agent.delete(2, '123456');
    });
  });

  group('TransportRepo + DashboardRepo', () {
    test('active transports', () async {
      mockGet('/api/transports/active/', body: [transportJson()]);

      final transports = await repos.transport.active();
      expect(transports.single.name, 'VRL Logistics');
    });

    test('analytics parses date-windowed KPIs', () async {
      mockGet('/api/dashboard/analytics/',
          query: const {'from': '2026-01-01', 'to': '2026-01-31'},
          body: analyticsJson());

      final data =
          await repos.dashboard.analytics('2026-01-01', '2026-01-31');
      expect(data.kpis.total, 10);
      expect(data.kpis.dispatched, 2);
      expect(data.kpis.totalValue, 15000.0);
      expect(data.kpis.totalSets, 32);
      expect(data.kpis.totalPieces, 90);
    });

    test('analytics tolerates KPIs without totals (old cached responses)', () async {
      final response = analyticsJson();
      (response['kpis'] as Map<String, dynamic>).remove('total_value');
      (response['kpis'] as Map<String, dynamic>).remove('total_sets');
      (response['kpis'] as Map<String, dynamic>).remove('total_pieces');
      mockGet('/api/dashboard/analytics/',
          query: const {'from': '2026-01-01', 'to': '2026-01-31'},
          body: response);

      final data =
          await repos.dashboard.analytics('2026-01-01', '2026-01-31');
      expect(data.kpis.totalValue, isNull);
      expect(data.kpis.totalSets, isNull);
      expect(data.kpis.totalPieces, isNull);
    });
  });
}

/// True if there is still a cached entry under the given namespace.
bool canReadCache(String namespace) => AppCache.cacheBox.keys
    .any((k) => k.toString().startsWith('$namespace::'));