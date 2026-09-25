import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stock_flow_admin/core/theme/app_theme.dart';
import 'package:stock_flow_admin/features/dashboard/dashboard_screen.dart';

import 'helpers.dart';

void main() {
  late ProviderContainer container;

  setUp(() async {
    await resetTestInfra();
    container = makeTestContainer();
    addTearDown(container.dispose);
  });

  void mockDashboard({List<Map<String, dynamic>>? results}) {
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
    final body = results;
    mockGet('/api/orders/',
        query: const {'page': 1, 'page_size': 50, 'status': ['PENDING']},
        body: body ?? paginatedOrderJson());
    mockGet('/api/orders/',
        query: const {'page': 1, 'page_size': 50, 'status': ['PACKED']},
        body: (results == null)
            ? const {'count': 0, 'next': null, 'previous': null, 'results': []}
            : paginatedOrderJson());
    mockGet('/api/orders/',
        query: const {'page': 1, 'page_size': 50, 'status': ['DISPATCHED']},
        body: (results == null)
            ? const {'count': 0, 'next': null, 'previous': null, 'results': []}
            : paginatedOrderJson());
    mockGet('/api/orders/',
        query: const {'page': 1, 'page_size': 50},
        body: (results == null)
            ? const {'count': 0, 'next': null, 'previous': null, 'results': []}
            : paginatedOrderJson());
  }

  Color? tabColor(WidgetTester tester, String label) {
    final container = tester.widget<AnimatedContainer>(
      find
          .ancestor(
            of: find.text(label),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    return (container.decoration as BoxDecoration?)?.color;
  }

  Color? tabTextColor(WidgetTester tester, String label) {
    final text = tester.widget<Text>(find.text(label));
    return text.style?.color;
  }

  testWidgets('all four tabs always render with equal-width active state',
      (tester) async {
    useTallSurface(tester);
    seedAdminSession();
    mockDashboard();

    await pumpScreen(tester, const DashboardScreen(), container);
    await tester.pumpAndSettle();

    for (final label in ['All', 'Pending', 'Packed', 'Dispatched']) {
      expect(find.text(label), findsOneWidget, reason: '$label tab must exist');
    }

    expect(tabColor(tester, 'Pending'), AppColors.primary);
    expect(tabColor(tester, 'All'), Colors.transparent);
    expect(tabTextColor(tester, 'Pending'), Colors.white);
    expect(tabTextColor(tester, 'All'), const Color(0xFF6B7280));
  });

  testWidgets('each tab becomes active when tapped and switches back',
      (tester) async {
    useTallSurface(tester);
    seedAdminSession();
    mockDashboard();

    await pumpScreen(tester, const DashboardScreen(), container);
    await tester.pumpAndSettle();

    for (final label in ['All', 'Pending', 'Packed', 'Dispatched']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(tabColor(tester, label), AppColors.primary,
          reason: '$label should be active');
      expect(tabTextColor(tester, label), Colors.white);
    }

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(tabColor(tester, 'All'), AppColors.primary);
    expect(tabColor(tester, 'Pending'), Colors.transparent);
    expect(tabColor(tester, 'Packed'), Colors.transparent);
    expect(tabColor(tester, 'Dispatched'), Colors.transparent);
  });

  testWidgets('active tab stays visible even with zero orders for that status',
      (tester) async {
    useTallSurface(tester);
    seedAdminSession();
    mockDashboard();

    await pumpScreen(tester, const DashboardScreen(), container);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Packed'));
    await tester.pumpAndSettle();
    expect(find.text('Packed'), findsOneWidget);
    expect(tabColor(tester, 'Packed'), AppColors.primary);
    expect(find.text('No Packed Orders'), findsOneWidget);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.text('All'), findsOneWidget);
    expect(tabColor(tester, 'All'), AppColors.primary);
  });
}