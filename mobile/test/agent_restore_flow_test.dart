import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:stock_flow_admin/features/users/agent_new_screen.dart';

import 'helpers.dart';

void main() {
  late ProviderContainer container;

  setUp(() async {
    await resetTestInfra();
    container = makeTestContainer();
    addTearDown(container.dispose);
    seedAdminSession();
  });

  testWidgets(
      'create collision offers restore and reuses the typed name/contact',
      (tester) async {
    useTallSurface(tester);

    mockGet('/api/agents/', body: <Map<String, dynamic>>[]);
    mockPost(
      '/api/agents/',
      status: 400,
      body: {
        'error': 'This agent was deleted.',
        'code': 'agent_deactivated',
        'agent_id': 2,
      },
    );
    mockPost(
      '/api/agents/2/restore/',
      body: agentJson(),
      data: const JsonBody({
        'display_name': 'John Doe',
        'contact': '9999999999',
      }),
    );

    final router = GoRouter(
      initialLocation: '/admin/users/agents/new',
      routes: [
        GoRoute(
          path: '/admin/users/agents/new',
          builder: (_, __) => const AgentNewScreen(),
        ),
        GoRoute(
          path: '/admin/users/agents/:id',
          builder: (_, state) =>
              Scaffold(body: Text('Agent ${state.pathParameters['id']}')),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(3), '9999999999');
    await tester.enterText(fields.at(2), 'secret123');
    await tester.enterText(fields.at(1), 'john@xlapparals.in');
    // Enter the name last: its onChanged inserts the live username preview,
    // which would otherwise shift the field indexes mid-entry.
    await tester.enterText(fields.at(0), 'John Doe');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create Agent'));
    await tester.pumpAndSettle();

    expect(find.text('Agent already exists'), findsOneWidget);
    expect(find.text('Restore Agent'), findsOneWidget);

    await tester.tap(find.text('Restore Agent'));
    await tester.pumpAndSettle();

    expect(find.text('Agent 2'), findsOneWidget);

    // Let the success toast's auto-dismiss timer fire before teardown.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}
