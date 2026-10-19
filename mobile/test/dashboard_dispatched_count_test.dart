import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stock_flow_admin/features/dashboard/dashboard_screen.dart';

import 'helpers.dart';

/// A known mix of orders, deliberately including two DISPATCHED.
const List<({int id, String status})> kOrderIds = [
  (id: 1, status: 'PENDING'),
  (id: 2, status: 'PENDING'),
  (id: 3, status: 'PACKED'),
  (id: 4, status: 'DISPATCHED'),
  (id: 5, status: 'DISPATCHED'),
  (id: 6, status: 'PENDING'),
];

/// What the Dispatched tab's own list query (`GET /api/orders/?status=DISPATCHED`)
/// returns for [kOrderIds].
const int kDispatchedInList = 2;

/// The rows `GET /api/orders/?status=<status>` would return for [src].
/// A null [status] means the unfiltered (All tab) request.
List<Map<String, dynamic>> _listRows(
        String? status, List<({int id, String status})> src) =>
    [
      for (final o in src)
        if (status == null || o.status == status) ...[
          {
            ...orderJson(),
            'id': o.id,
            'status': o.status,
          },
        ],
    ];

Map<String, dynamic> _listBody(
        String status, List<({int id, String status})> src) =>
    {
      'count': src.where((o) => o.status == status).length,
      'next': null,
      'previous': null,
      'results': _listRows(status, src),
    };

/// Mocks the dashboard's endpoints for [allIds].
///
/// [includeAllTab] controls whether the unfiltered `/api/orders/` (All tab)
/// mock is registered. It is off by default on purpose: a mock with *fewer*
/// query parameters still matches status-scoped requests, so registering the
/// All catch-all alongside the status-scoped mocks makes every tab render the
/// All body. Tests that need the All request register it explicitly.
void mockOrdersDashboard(
  List<({int id, String status})> allIds, {
  bool includeAllTab = false,
}) {
  mockGet('/api/agents/', body: [agentJson()]);
  mockGet('/api/customers/',
      query: const {'page': 1, 'page_size': 50},
      body: {
        'count': 1,
        'next': null,
        'previous': null,
        'results': [customerJson()],
      });
  // All PENDING/PACKED orders are already viewed. This keeps the screen's
  // unread pulse (`_pulse.repeat()`, an infinite animation) stopped so
  // `pumpAndSettle` can settle, and leaves the total counts untouched because
  // the dashboard defaults to showing all orders, not unread-only.
  mockGet('/api/orders/my-viewed-ids/',
      body: [
        for (final o in allIds)
          if (o.status != 'DISPATCHED') o.id,
      ]);
  mockGet('/api/orders/order-ids/',
      body: [
        for (final o in allIds) {'id': o.id, 'status': o.status},
      ]);

  // `status` must be keyed as a List to match `OrderFilters.toQuery()`, which
  // puts the `statuses` List straight into `queryParameters`.
  for (final status in const ['PENDING', 'PACKED', 'DISPATCHED']) {
    mockGet('/api/orders/',
        query: {'page': 1, 'page_size': 50, 'status': [status]},
        body: _listBody(status, allIds));
  }

  if (includeAllTab) {
    mockGet('/api/orders/', query: const {'page': 1, 'page_size': 50}, body: {
      'count': allIds.length,
      'next': null,
      'previous': null,
      'results': _listRows(null, allIds),
    });
  }
}

void main() {
  group('orderCountForTab', () {
    test('Dispatched tab counts the DISPATCHED records, not zero', () {
      expect(orderCountForTab(kOrderIds, AdminTab.dispatched), kDispatchedInList);
    });

    test('Dispatched count matches what the list query returns', () {
      // The list query is the source of truth for "correct" here.
      final fromList = kOrderIds.where((o) => o.status == 'DISPATCHED').length;
      expect(fromList, kDispatchedInList);
      expect(
        orderCountForTab(kOrderIds, AdminTab.dispatched, unreadOnly: false),
        fromList,
      );
    });

    test('All/Pending/Packed counts are unaffected', () {
      expect(orderCountForTab(kOrderIds, AdminTab.all), 6);
      expect(orderCountForTab(kOrderIds, AdminTab.pending), 3);
      expect(orderCountForTab(kOrderIds, AdminTab.packed), 1);
      expect(orderCountForTab(kOrderIds, AdminTab.dispatched), 2);
    });

    test('counts derive from the same status the list queries with', () {
      for (final tab in AdminTab.values) {
        final status = orderStatusForTab(tab);
        final counted = orderRecordsForTab(kOrderIds, tab).length;
        final inList = status == null
            ? kOrderIds.length
            : kOrderIds.where((o) => o.status == status).length;
        expect(counted, inList, reason: '${tab.name} count must match its list');
      }
    });

    test('unread-only narrows non-dispatched tabs but Dispatched stays 0', () {
      // Nothing is viewed in this fixture, so unread == total for PENDING/PACKED.
      expect(
        orderCountForTab(kOrderIds, AdminTab.pending, unreadOnly: true),
        3,
      );
      expect(
        orderCountForTab(kOrderIds, AdminTab.packed, unreadOnly: true),
        1,
      );
      // Dispatched orders are always viewed, so they are never unread.
      expect(
        orderCountForTab(kOrderIds, AdminTab.dispatched, unreadOnly: true),
        0,
      );
    });

    test('a viewed PENDING order drops out of the unread count only', () {
      final viewed = {1};
      expect(orderCountForTab(kOrderIds, AdminTab.pending), 3,
          reason: 'total count ignores viewed state');
      expect(
        orderCountForTab(kOrderIds, AdminTab.pending,
            unreadOnly: true, viewedIds: viewed),
        2,
      );
      expect(
        orderCountForTab(kOrderIds, AdminTab.dispatched,
            unreadOnly: true, viewedIds: viewed),
        0,
      );
    });

    test('DRAFT is never present in order-ids, and a 0-order snapshot is 0', () {
      expect(orderCountForTab(const [], AdminTab.dispatched), 0);
      expect(
        orderCountForTab(
          const [(id: 9, status: 'DRAFT')],
          AdminTab.all,
        ),
        1,
        reason: 'All counts whatever the snapshot contains',
      );
    });
  });

  group('DashboardScreen Dispatched tab', () {
    late ProviderContainer container;

    setUp(() async {
      await resetTestInfra();
      container = makeTestContainer();
      addTearDown(container.dispose);
      seedAdminSession();
    });

    /// The count rendered next to the "<Tab> orders" header.
    ///
    /// Read from the header Row's *direct* `Text` children: the row also hosts
    /// the "Unread" chip, whose label is a nested Text and would otherwise be
    /// picked up by a plain descendant search.
    String headerCount(WidgetTester tester, String tabName) {
      final label = find.text('$tabName orders');
      expect(label, findsOneWidget, reason: '$tabName header must render');
      final row = tester.widget<Row>(
        find.ancestor(of: label, matching: find.byType(Row)).first,
      );
      final counts = [
        for (final child in row.children)
          if (child is Text && child.data != '$tabName orders') child.data,
      ];
      expect(counts, hasLength(1),
          reason: 'expected exactly one count Text in the $tabName header');
      return counts.single!;
    }

  testWidgets('shows the dispatched count, not 0, with a matching list',
      (tester) async {
    useTallSurface(tester);
    mockOrdersDashboard(kOrderIds);

    await pumpScreen(tester, const DashboardScreen(), container);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dispatched'));
    await tester.pumpAndSettle();

    expect(headerCount(tester, 'Dispatched'), '$kDispatchedInList');

    // ...and the list underneath really has that many orders.
    expect(find.text('ID #4'), findsOneWidget);
    expect(find.text('ID #5'), findsOneWidget);
    expect(find.text('ID #1'), findsNothing);
  });

    testWidgets('Pending count still reflects only PENDING orders',
        (tester) async {
      useTallSurface(tester);
      mockOrdersDashboard(kOrderIds);

      await pumpScreen(tester, const DashboardScreen(), container);
      await tester.pumpAndSettle();

      expect(headerCount(tester, 'Pending'), '3');
    });

    testWidgets('All and Packed counts are unaffected', (tester) async {
      useTallSurface(tester);
      mockOrdersDashboard(kOrderIds, includeAllTab: true);

      await pumpScreen(tester, const DashboardScreen(), container);
      await tester.pumpAndSettle();

      // The screen restores the tab from prefs; tap explicitly rather than
      // assuming which one is selected on a cold start.
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      expect(headerCount(tester, 'All'), '6');

      await tester.tap(find.text('Packed'));
      await tester.pumpAndSettle();
      expect(headerCount(tester, 'Packed'), '1');
    });
  });
}