import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stock_flow_admin/features/users/agent_detail_screen.dart';

import 'helpers.dart';

/// An agent whose `assigned_items` expose [itemCount] items, each with a single
/// variant, so every row has a unique name (`Item 0001`, `Item 0002`, ...).
///
/// Each assigned item is created "now", so every variant is inside the
/// section's 1-day "recent" cutoff and shows up in both tabs.
Map<String, dynamic> agentWithAssignedItems(int itemCount) {
  final agent = agentDetailJson();
  agent['assigned_items'] = [
    for (var i = 1; i <= itemCount; i++)
      {
        'id': i,
        'name': _name(i),
        'type': 'kids',
        'price': '200.00',
        'variants': [
          {
            'id': i,
            'image': '',
            'qr_code': 'qr-$i',
            'size_ranges': [
              {'size_range': '38', 'stock': 10},
            ],
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'display_order': '$i',
          },
        ],
      },
  ];
  return agent;
}

String _name(int i) => 'Item ${i.toString().padLeft(4, '0')}';

/// `/api/items/variants/all/` entries matching [agentWithAssignedItems].
List<Map<String, dynamic>> allVariants(int itemCount) => [
      for (var i = 1; i <= itemCount; i++)
        {
          ...variantAllRealJson(),
          'id': i,
          'item_id': i,
          'item_name': _name(i),
          'qr_code': 'qr-$i',
        },
    ];

final RegExp _rowName = RegExp(r'^Item \d{4}$');

void main() {
  // Large enough that eagerly building every row would be visibly wrong, small
  // enough that the HTTP mock layer stays fast.
  const assignedCount = 200;

  late ProviderContainer container;

  setUp(() async {
    await resetTestInfra();
    container = makeTestContainer();
    addTearDown(container.dispose);
    seedAdminSession();
  });

  void mockAgentDetail() {
    mockGet('/api/agents/2/', body: agentWithAssignedItems(assignedCount));
    mockGet('/api/agents/', body: [agentJson()]);
    mockGet('/api/items/variants/all/', body: allVariants(assignedCount));
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
  }

  /// Distinct assigned rows currently realised in the widget tree. A lazily
  /// built list only keeps a viewport-sized window alive.
  int realisedRows(WidgetTester tester) => find
      .byWidgetPredicate(
          (w) => w is Text && w.data != null && _rowName.hasMatch(w.data!))
      .evaluate()
      .length;

  testWidgets('assigned items list is built lazily, not eagerly',
      (tester) async {
    useTallSurface(tester);
    mockAgentDetail();

    await pumpScreen(tester, const AgentDetailScreen(agentId: 2), container);
    await settle(tester);

    expect(find.text('Agent Profile'), findsOneWidget);

    // Every assigned row exists logically...
    expect(find.text('Items'), findsOneWidget);
    expect(find.text('$assignedCount'), findsWidgets);

    // ...but only a small window is actually built. The old eager
    // implementation realised all $assignedCount rows at once, which is what
    // froze scrolling and exhausted memory.
    final realised = realisedRows(tester);
    expect(realised, greaterThan(0));
    expect(
      realised,
      lessThan(assignedCount ~/ 2),
      reason: 'only a lazy (viewport-sized) window should be built, '
          'but $realised of $assignedCount rows were realised',
    );
  });

  testWidgets('switching to the Assigned tab stays lazy and scrolls cleanly',
      (tester) async {
    useTallSurface(tester);
    mockAgentDetail();

    await pumpScreen(tester, const AgentDetailScreen(agentId: 2), container);
    await settle(tester);

    await tester.tap(find.text('Assigned ($assignedCount)'));
    await settle(tester);

    expect(realisedRows(tester), lessThan(assignedCount ~/ 2));

    // Scrolling deep into the list must keep working (this is where the app
    // used to hang and get killed).
    for (var i = 0; i < 15; i++) {
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pump();
    }
    await settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(CustomScrollView), findsOneWidget);
    // Rows keep being built on demand while scrolling.
    expect(realisedRows(tester), greaterThan(0));
  });
}
