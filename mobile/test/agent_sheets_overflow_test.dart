import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_flow_admin/core/theme/app_theme.dart';
import 'package:stock_flow_admin/features/users/agent_detail_screen.dart';
import 'package:stock_flow_admin/models/models.dart';
import 'package:stock_flow_admin/shared/widgets.dart';

void useSmallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget testApp(Widget home) =>
    MaterialApp(theme: AppTheme.light(), home: home);

void main() {
  testWidgets('agent picker sheet caps its height and scrolls to the last agent',
      (tester) async {
    useSmallSurface(tester);
    final agents = [
      for (var i = 1; i <= 30; i++)
        Agent(id: i, user: AgentUser(id: i, displayName: 'Agent $i')),
    ];

    await tester.pumpWidget(testApp(
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAgentPickerSheet(
              context,
              title: 'Transfer Items',
              agents: agents,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Transfer Items'), findsOneWidget);
    expect(find.text('Agent 1'), findsOneWidget);
    expect(find.text('Agent 30'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Agent 30'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Agent 30'), findsOneWidget);
  });

  testWidgets('delete dialog does not overflow when the keyboard opens',
      (tester) async {
    useSmallSurface(tester);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(testApp(
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<bool>(
              context: context,
              builder: (_) => DeleteWithTransferDialog(
                entityType: 'agent',
                entityName: 'Agent Alpha',
                fetchDeleteInfo: () async => {
                  'customers_count': 3,
                  'orders_count': 4,
                  'transferable_agents': [
                    {'id': 2, 'name': 'Agent Beta'},
                  ],
                },
                onDelete: ({
                  required pin,
                  required action,
                  transferToId,
                }) async {},
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField));
    await tester.pump();

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Enter your 6-digit PIN to confirm'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Deactivate'), findsOneWidget);
    expect(
      tester.getBottomLeft(find.byType(TextField)).dy,
      lessThan(340),
    );
    expect(
      tester.getBottomLeft(find.text('Cancel')).dy,
      lessThan(340),
    );
    expect(
      tester.getBottomLeft(find.text('Deactivate')).dy,
      lessThan(340),
    );
  });
}
