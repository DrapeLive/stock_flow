import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import 'package:stock_flow_admin/features/analytics/analytics_screen.dart';

import 'helpers.dart';

Map<String, dynamic> _analyticsPayload({
  double? totalValue,
  int? totalSets,
  int? totalPieces,
}) =>
    {
      'kpis': {
        'total': 8,
        'draft': 1,
        'pending': 3,
        'editing': 0,
        'packed': 2,
        'dispatched': 2,
        'total_value': totalValue ?? 15000.0,
        'total_sets': totalSets ?? 32,
        'total_pieces': totalPieces ?? 90,
      },
      'trend': <dynamic>[],
      'top_customers': <dynamic>[],
      'top_agents': <dynamic>[],
      'top_items': <dynamic>[],
      'time_metrics': {
        'avg_dispatch_hours': 12.5,
        'median_dispatch_hours': 10.0,
        'dispatched_within_24h_pct': 80.0,
      },
    };

Finder get _kpiTiles => find.byWidgetPredicate(
    (w) => w.runtimeType.toString().contains('KpiTile'));

void main() {
  late ProviderContainer container;

  setUp(() async {
    await resetTestInfra();
    container = makeTestContainer();
    seedAdminSession();
    addTearDown(container.dispose);
  });

  group('KPI value cards (Total Order Value / Total Sets Ordered)', () {
    const masked = '\u2022\u2022\u2022\u2022';

    testWidgets('render both labels but lock totals behind a PIN by default',
        (tester) async {
      useTallSurface(tester);
      mockGet('/api/dashboard/analytics/',
          query: {'from': Matchers.any, 'to': Matchers.any},
          body: _analyticsPayload());

      await pumpScreen(tester, const AnalyticsScreen(), container);
      await tester.pumpAndSettle();

      expect(find.text('TOTAL ORDER VALUE'), findsOneWidget);
      expect(find.text('TOTAL SETS ORDERED'), findsOneWidget);
      expect(find.text('Total Order Value'), findsNothing);
      // Locked by default: totals are masked and no currency is shown.
      expect(find.text(masked), findsNWidgets(2));
      expect(find.byIcon(Icons.lock_outline), findsNWidgets(2));
      expect(find.text('Tap to unlock'), findsNWidgets(2));
      expect(find.textContaining('\u20B9'), findsNothing);
      // Five KPI tiles: 2 value cards + 3 dispatch metrics.
      expect(_kpiTiles, findsNWidgets(5));
    });

    testWidgets('entering the correct PIN unlocks and reveals the totals',
        (tester) async {
      useTallSurface(tester);
      mockGet('/api/dashboard/analytics/',
          query: {'from': Matchers.any, 'to': Matchers.any},
          body: _analyticsPayload());
      mockPost('/api/auth/verify-pin/');

      await pumpScreen(tester, const AnalyticsScreen(), container);
      await tester.pumpAndSettle();

      expect(find.text(masked), findsNWidgets(2));
      await tester.tap(find.text('Tap to unlock').first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '1234');
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(find.text(masked), findsNothing);
      expect(find.textContaining('\u20B9'), findsWidgets);
      expect(_kpiTiles, findsNWidgets(5));
    });

    testWidgets('stay aligned (same size) and never overflow at long values '
        'with a 1.3x text scale', (tester) async {
      useTallSurface(tester);
      // 8-digit values produce the worst-case ₹ / comma / whitespace widths.
      final response = _analyticsPayload(
        totalValue: 99999999,
        totalSets: 9999999,
        totalPieces: 99999999,
      );
      mockGet('/api/dashboard/analytics/',
          query: {'from': Matchers.any, 'to': Matchers.any}, body: response);

      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pumpScreen(tester, const AnalyticsScreen(), container);
      await tester.pumpAndSettle();
      await tester.pump();

      expect(tester.takeException(), isNull,
          reason: 'long ₹ values must not make the KPI cards overflow');

      final orderValue = _kpiTiles.at(0);
      final setsOrdered = _kpiTiles.at(1);
      expect(orderValue, findsOneWidget);
      expect(setsOrdered, findsOneWidget);

      final sizeA = tester.getSize(orderValue);
      final sizeB = tester.getSize(setsOrdered);
      expect(sizeA.width, greaterThan(0));
      expect(sizeA.height, greaterThan(0));
      // The two side-by-side tiles must be exactly the same size so their tops
      // and bottoms line up on the row.
      expect(sizeA, sizeB);
      expect(_kpiTiles, findsNWidgets(5));
    });
  });
}