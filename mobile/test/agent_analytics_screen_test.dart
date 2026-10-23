import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stock_flow_admin/core/cache/app_cache.dart';
import 'package:stock_flow_admin/features/analytics/agent_analytics_screen.dart';
import 'package:stock_flow_admin/models/models.dart';

import 'helpers.dart';

Map<String, dynamic> _analyticsPayload() => {
      'kpis': {
        'total': 2,
        'draft': 0,
        'pending': 1,
        'editing': 0,
        'packed': 1,
        'dispatched': 0,
        'total_value': 12700.0,
        'total_sets': 10,
        'total_pieces': 30,
      },
      'trend': <dynamic>[],
      'top_customers': <dynamic>[],
      'top_agents': <dynamic>[],
      'top_items': <dynamic>[],
      'time_metrics': {
        'avg_dispatch_hours': null,
        'median_dispatch_hours': null,
        'dispatched_within_24h_pct': null,
      },
      'agent_analytics': {
        'summary': {
          'agents': 2,
          'orders': 2,
          'order_amount': 12700.0,
        },
        'agents': [
          {
            'id': 1,
            'username': 'agent1',
            'orders': 1,
            'order_amount': 11500.0,
          },
          {
            'id': 2,
            'username': 'agent2',
            'orders': 1,
            'order_amount': 1200.0,
          },
        ],
      },
    };

void main() {
  late ProviderContainer container;

  setUp(() async {
    await resetTestInfra();
    container = makeTestContainer();
    seedAdminSession();
    addTearDown(container.dispose);
  });

  group('AgentAnalyticsData parsing', () {
    test('parses the agent breakdown and summary', () {
      final data = AnalyticsData.fromJson(_analyticsPayload());

      expect(data.hasAgentAnalytics, isTrue);
      expect(data.agentAnalytics.summary.agents, 2);
      expect(data.agentAnalytics.summary.orders, 2);
      expect(data.agentAnalytics.summary.orderAmount, 12700.0);
      expect(data.agentAnalytics.agents, hasLength(2));
      expect(data.agentAnalytics.agents.first.username, 'agent1');
      expect(data.agentAnalytics.agents.first.orders, 1);
      expect(data.agentAnalytics.agents.first.orderAmount, 11500.0);
    });

    test('marks agent analytics unavailable when the backend omits it', () {
      final payload = _analyticsPayload();
      payload.remove('agent_analytics');

      final data = AnalyticsData.fromJson(payload);

      expect(data.hasAgentAnalytics, isFalse);
      expect(data.agentAnalytics.summary.agents, 0);
      expect(data.agentAnalytics.agents, isEmpty);
    });
  });

  group('AgentAnalyticsScreen', () {
    testWidgets('asks for a PIN before showing agent analytics',
        (tester) async {
      useTallSurface(tester);

      await pumpScreen(
        tester,
        const AgentAnalyticsScreen(from: '2026-09-01', to: '2026-09-30'),
        container,
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Enter your 6-digit PIN to view agent-wise analytics'),
        findsOneWidget,
      );
      expect(find.text('Confirm'), findsOneWidget);
      expect(find.text('PIN required'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('PIN required'), findsOneWidget);
      expect(find.text('Enter PIN'), findsOneWidget);
      expect(find.text('agent1'), findsNothing);
    });

    testWidgets('unlocks with the correct PIN and renders summary and rows',
        (tester) async {
      useTallSurface(tester);
      mockPost('/api/auth/verify-pin/');
      mockGet(
        '/api/dashboard/analytics/',
        query: {'from': '2026-09-01', 'to': '2026-09-30'},
        body: _analyticsPayload(),
      );

      await pumpScreen(
        tester,
        const AgentAnalyticsScreen(from: '2026-09-01', to: '2026-09-30'),
        container,
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '1234');
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(find.text('AGENTS'), findsNWidgets(2));
      expect(find.text('ORDERS'), findsNWidgets(2));
      expect(find.text('ORDER AMOUNT'), findsOneWidget);
      expect(find.text('agent1'), findsOneWidget);
      expect(find.text('agent2'), findsOneWidget);
      expect(find.textContaining('11,500'), findsOneWidget);
      expect(find.textContaining('1,200'), findsOneWidget);
    });

    testWidgets('ignores a cached payload that predates agent_analytics',
        (tester) async {
      useTallSurface(tester);
      final stale = Map<String, dynamic>.from(_analyticsPayload())
        ..remove('agent_analytics');
      await AppCache.write(
        'dash-v4',
        '2026-09-01::2026-09-30',
        stale,
      );
      mockPost('/api/auth/verify-pin/');
      mockGet(
        '/api/dashboard/analytics/',
        query: {'from': '2026-09-01', 'to': '2026-09-30'},
        body: _analyticsPayload(),
      );

      await pumpScreen(
        tester,
        const AgentAnalyticsScreen(from: '2026-09-01', to: '2026-09-30'),
        container,
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '1234');
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(find.text('agent1'), findsOneWidget);
      expect(find.textContaining('11,500'), findsOneWidget);
    });

    testWidgets('shows a retryable error when agent_analytics is missing',
        (tester) async {
      useTallSurface(tester);
      final payload = Map<String, dynamic>.from(_analyticsPayload())
        ..remove('agent_analytics');
      mockPost('/api/auth/verify-pin/');
      mockGet(
        '/api/dashboard/analytics/',
        query: {'from': '2026-09-01', 'to': '2026-09-30'},
        body: payload,
      );

      await pumpScreen(
        tester,
        const AgentAnalyticsScreen(from: '2026-09-01', to: '2026-09-30'),
        container,
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '1234');
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(find.text('Could not load agent analytics'), findsOneWidget);
      expect(find.textContaining('unavailable'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('renders the empty state for a valid empty result',
        (tester) async {
      useTallSurface(tester);
      final payload = Map<String, dynamic>.from(_analyticsPayload());
      payload['agent_analytics'] = {
        'summary': {'agents': 0, 'orders': 0, 'order_amount': 0},
        'agents': <dynamic>[],
      };
      mockPost('/api/auth/verify-pin/');
      mockGet(
        '/api/dashboard/analytics/',
        query: {'from': '2026-09-01', 'to': '2026-09-30'},
        body: payload,
      );

      await pumpScreen(
        tester,
        const AgentAnalyticsScreen(from: '2026-09-01', to: '2026-09-30'),
        container,
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '1234');
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(find.text('No agent activity in range'), findsOneWidget);
      expect(find.text('AGENTS'), findsNWidgets(2));
    });
  });
}
