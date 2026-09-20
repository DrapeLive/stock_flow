import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import 'package:stock_flow_admin/features/analytics/analytics_screen.dart';
import 'package:stock_flow_admin/features/auth/login_screen.dart';
import 'package:stock_flow_admin/features/bulk_import/bulk_import_screen.dart';
import 'package:stock_flow_admin/features/dashboard/dashboard_screen.dart';
import 'package:stock_flow_admin/features/items/item_wizard_screen.dart';
import 'package:stock_flow_admin/features/items/items_screen.dart';
import 'package:stock_flow_admin/features/items/ordered_items_screen.dart';
import 'package:stock_flow_admin/features/items/qr_print_select_screen.dart';
import 'package:stock_flow_admin/features/orders/order_create_customer_screen.dart';
import 'package:stock_flow_admin/features/orders/order_create_item_screen.dart';
import 'package:stock_flow_admin/features/orders/order_create_screen.dart';
import 'package:stock_flow_admin/features/orders/order_edit_stub_screen.dart';
import 'package:stock_flow_admin/features/orders/order_flow_utils.dart';
import 'package:stock_flow_admin/features/orders/order_status_screen.dart';
import 'package:stock_flow_admin/features/profile/profile_screen.dart';
import 'package:stock_flow_admin/features/summary/summary_screen.dart';
import 'package:stock_flow_admin/features/users/agent_detail_screen.dart';
import 'package:stock_flow_admin/features/users/customer_detail_screen.dart';
import 'package:stock_flow_admin/features/users/users_screen.dart';
import 'package:stock_flow_admin/providers.dart';

import 'helpers.dart';

void main() {
  late ProviderContainer container;

  setUp(() async {
    await resetTestInfra();
    container = makeTestContainer();
    addTearDown(container.dispose);
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
  }

  group('login', () {
    testWidgets('renders and validates empty fields', (tester) async {
      useTallSurface(tester);
      await pumpScreen(tester, const LoginScreen(), container);
      await settle(tester);

      expect(find.text('XL Apparals'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);

      await tester.tap(find.text('Sign in'));
      await settle(tester);

      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('successful admin login updates the session', (tester) async {
      useTallSurface(tester);
      mockPost('/api/auth/login/', body: loginResponseJson());

      await pumpScreen(tester, const LoginScreen(), container);
      await settle(tester);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'admin@xlapparals.in');
      await tester.enterText(fields.at(1), 'secret');
      await tester.tap(find.text('Sign in'));
      await settle(tester);

      expect(container.read(sessionProvider)?.user.role, 'ADMIN');
      expect(container.read(sessionProvider)?.access, 'mock-access-token');
    });
  });

  group('admin screens render with mocked data', () {
    testWidgets('UsersScreen customers tab', (tester) async {
      useTallSurface(tester);
      seedAdminSession();
      mockGet('/api/customers/',
          query: const {'page': 1, 'page_size': 50},
          body: {
            'count': 1,
            'next': null,
            'previous': null,
            'results': [customerJson()],
          });

      await pumpScreen(tester, const UsersScreen(), container);
      await settle(tester);

      expect(find.text('Customers'), findsWidgets);
      expect(find.text('XL Fashions'), findsOneWidget);
    });

    testWidgets('SummaryScreen computes and renders stats', (tester) async {
      useTallSurface(tester);
      seedAdminSession();
      mockGet('/api/items/stock-list/', body: [stockEntryJson()]);

      await pumpScreen(tester, const SummaryScreen(), container);
      await settle(tester);

      expect(find.text('Inventory Summary'), findsOneWidget);
      expect(find.text('ITEM-A'), findsOneWidget);
    });

    testWidgets('AnalyticsScreen renders KPI cards', (tester) async {
      useTallSurface(tester);
      seedAdminSession();
      mockGet('/api/dashboard/analytics/',
          query: {'from': Matchers.any, 'to': Matchers.any},
          body: analyticsJson());

      await pumpScreen(tester, const AnalyticsScreen(), container);
      await settle(tester);

      expect(find.text('Analytics'), findsOneWidget);
    });

    testWidgets('ItemsScreen renders inventory', (tester) async {
      useTallSurface(tester);
      seedAdminSession();
      seedItemStore([stockEntryJson()]);
      mockItemSync();
      mockGet('/api/orders/order-items/unpacked/', body: [unpackedJson()]);
      mockGet('/api/items/size-ranges', body: sizeRangesJson());

      await pumpScreen(tester, const ItemsScreen(), container);
      await settle(tester);

      expect(find.text('Inventory'), findsOneWidget);
      expect(find.text('ITEM-A'), findsWidgets);
    });

    testWidgets('DashboardScreen loads orders + side lists', (tester) async {
      useTallSurface(tester);
      seedAdminSession();
      _mockDashboard();

      await pumpScreen(tester, const DashboardScreen(), container);
      await settle(tester);

      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(find.text('ORDERS'), findsOneWidget);
      expect(find.text('XL Fashions'), findsWidgets);
      expect(find.text('Unpacked'), findsWidgets);
    });

    testWidgets('OrderStatusScreen loads order + transports', (tester) async {
      useTallSurface(tester);
      seedAdminSession();
      mockGet('/api/orders/1/', body: orderJson());
      mockGet('/api/orders/1/logs/', body: const <Map<String, dynamic>>[]);
      mockGet('/api/transports/active/', body: [transportJson()]);

      await pumpScreen(
          tester, const OrderStatusScreen(orderId: 1), container);
      await settle(tester);

      expect(find.text('Order #1'), findsOneWidget);
      expect(find.text('XL Fashions'), findsWidgets);
    });

    testWidgets('CustomerDetailScreen loads customer + orders', (tester) async {
      useTallSurface(tester);
      seedAdminSession();
      mockGet('/api/customers/3/', body: customerJson());
      mockGet('/api/agents/', body: [agentJson()]);
      mockGet('/api/orders/',
          query: const {'customer': 3, 'page': 1, 'page_size': 50},
          body: paginatedOrderJson());

      await pumpScreen(
          tester, const CustomerDetailScreen(customerId: 3), container);
      await settle(tester);

      expect(find.text('Customer Profile'), findsOneWidget);
      expect(find.text('XL Fashions'), findsWidgets);
    });

    testWidgets('AgentDetailScreen loads agent + variants', (tester) async {
      useTallSurface(tester);
      seedAdminSession();
      mockGet('/api/agents/2/', body: agentJson());
      mockGet('/api/agents/', body: [agentJson()]);
      mockGet('/api/items/variants/all/', body: [variantAllJson()]);

      await pumpScreen(
          tester, const AgentDetailScreen(agentId: 2), container);
      await settle(tester);

      expect(find.text('Agent Profile'), findsOneWidget);
    });

    testWidgets('AgentDetailScreen renders real payloads', (tester) async {
      useTallSurface(tester);
      seedAdminSession();
      mockGet('/api/agents/2/', body: agentDetailJson());
      mockGet('/api/agents/', body: [agentDetailJson()]);
      mockGet('/api/items/variants/all/', body: [variantAllRealJson()]);

      await pumpScreen(
          tester, const AgentDetailScreen(agentId: 2), container);
      await settle(tester);

      expect(find.text('Agent Profile'), findsOneWidget);
      expect(find.textContaining('00001'), findsWidgets);
    });

    testWidgets('ProfileScreen renders from session', (tester) async {
      useTallSurface(tester);
      seedAdminSession();

      await pumpScreen(tester, const ProfileScreen(), container);
      await settle(tester);

      expect(find.text('admin'), findsNWidgets(2));
      expect(find.text('ADMIN'), findsOneWidget);
    });

    testWidgets('BulkImportScreen renders upload UI', (tester) async {
      useTallSurface(tester);
      seedAdminSession();

      await pumpScreen(tester, const BulkImportScreen(), container);
      await settle(tester);

      expect(find.text('Bulk Import'), findsOneWidget);
      expect(find.textContaining('Download Template'), findsOneWidget);
    });

    testWidgets('ItemWizardScreen renders step 1', (tester) async {
      useTallSurface(tester);
      seedAdminSession();
      mockGet('/api/items/size-ranges', body: sizeRangesJson());

      await pumpScreen(tester, const ItemWizardScreen(), container);
      await settle(tester);

      expect(find.text('Item Details'), findsOneWidget);
    });

    testWidgets('OrderedItemsScreen renders item requirements', (tester) async {
      useTallSurface(tester);
      seedAdminSession();
      mockGet('/api/items/customer-requirements/',
          query: const {'item_id': 10}, body: customerRequirementsJson());

      await pumpScreen(
          tester, const OrderedItemsScreen(itemId: 10), container);
      await settle(tester);

      expect(find.text('ITEM-A'), findsWidgets);
    });

    testWidgets('QrPrintSelectScreen renders item picker', (tester) async {
      useTallSurface(tester);
      seedAdminSession();
      mockGet('/api/items/stock-list/', body: [stockEntryJson()]);

      await pumpScreen(tester, const QrPrintSelectScreen(), container);
      await settle(tester);

      expect(find.text('Print QR labels'), findsOneWidget);
      expect(find.text('ITEM-A'), findsWidgets);
    });

    testWidgets('OrderEditStubScreen renders stub', (tester) async {
      useTallSurface(tester);
      seedAdminSession();
      mockGet('/api/orders/1/', body: orderJson());

      await pumpScreen(
          tester, const OrderEditStubScreen(orderId: 1), container);
      await settle(tester);

      expect(find.text('Ordered Items'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
    });
  });

  group('admin create-order flow', () {
    testWidgets('OrderCreateCustomerScreen lists customers', (tester) async {
      useTallSurface(tester);
      seedAdminSession();
      mockGet('/api/customers/',
          query: const {'page': 1, 'page_size': 20},
          body: {
            'count': 1,
            'next': null,
            'previous': null,
            'results': [customerJson()],
          });

      await pumpScreen(
          tester, const OrderCreateCustomerScreen(), container);
      await settle(tester);

      expect(find.text('Create Order'), findsOneWidget);
      expect(find.text('XL Fashions'), findsOneWidget);
    });

    testWidgets('OrderCreateScreen shows draft details + items', (tester) async {
      useTallSurface(tester);
      seedAdminSession();
      OrderDraftSession.start(orderId: 1, customerId: 3);
      addTearDown(OrderDraftSession.clear);
      mockGet('/api/customers/3/', body: customerJson());
      mockGet('/api/orders/1/', body: orderJson());
      mockGet('/api/transports/active/', body: [transportJson()]);

      await pumpScreen(
          tester, const OrderCreateScreen(customerId: 3), container);
      await settle(tester);

      expect(find.text('Order Details'), findsOneWidget);
      expect(find.text('XL Fashions'), findsWidgets);
      expect(find.textContaining('ITEM-A'), findsWidgets);
      expect(find.text('Place Order'), findsOneWidget);
    });

    testWidgets('OrderCreateScreen shows expired state without a session',
        (tester) async {
      useTallSurface(tester);
      seedAdminSession();
      OrderDraftSession.clear();

      await pumpScreen(
          tester, const OrderCreateScreen(customerId: 3), container);
      await settle(tester);

      expect(find.text('Order unavailable'), findsOneWidget);
      expect(find.text('Start new order'), findsOneWidget);
    });

    testWidgets('OrderCreateItemScreen opens in edit mode when item exists',
        (tester) async {
      useTallSurface(tester);
      seedAdminSession();
      OrderDraftSession.start(orderId: 1, customerId: 3);
      addTearDown(OrderDraftSession.clear);
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
      mockGet('/api/orders/1/', body: orderJson());
      mockGet('/api/items/size-ranges', body: sizeRangesJson());

      await pumpScreen(
          tester,
          const OrderCreateItemScreen(customerId: 3, qr: 'QRONE'),
          container);
      await settle(tester);

      expect(find.text('Edit Item'), findsOneWidget);
      expect(find.text('ITEM-A'), findsOneWidget);
      expect(find.text('Update Item'), findsOneWidget);
    });
  });
}

void _mockDashboard() {
  mockGet('/api/agents/', body: [agentJson()]);
  mockGet('/api/customers/',
      query: const {'page': 1, 'page_size': 50},
      body: {
        'count': 1,
        'next': null,
        'previous': null,
        'results': [customerJson()],
      });
  mockGet('/api/orders/my-viewed-ids/', body: [1]);
  mockGet('/api/orders/order-ids/',
      body: [
        {'id': 1, 'status': 'PENDING'},
      ]);
  mockGet('/api/orders/',
      query: const {'page': 1, 'page_size': 50, 'status': ['PENDING']},
      body: paginatedOrderJson());
}