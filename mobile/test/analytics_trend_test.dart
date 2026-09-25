import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:intl/intl.dart';

import 'package:stock_flow_admin/features/analytics/analytics_screen.dart';
import 'package:stock_flow_admin/models/models.dart';

import 'helpers.dart';

// ---------------------------------------------------------------------------
// An analytics payload shaped exactly as the backend serializes it
// (backend/apps/dashboard/views.py, AdminAnalyticsView): "trend" is a list of
// {"day": "YYYY-MM-DD", "count": int} points.
// ---------------------------------------------------------------------------

Map<String, dynamic> _analyticsPayload({List<Map<String, dynamic>>? trend}) =>
    {
      'kpis': {
        'total': 8,
        'draft': 1,
        'pending': 3,
        'editing': 0,
        'packed': 2,
        'dispatched': 2,
        'total_value': 15000.0,
        'total_sets': 32,
        'total_pieces': 90,
      },
      'trend': trend ??
          [
            {'day': '2026-08-25', 'count': 2},
            {'day': '2026-09-01', 'count': 5},
            {'day': '2026-09-10', 'count': 1},
          ],
      'top_customers': <dynamic>[],
      'top_agents': <dynamic>[],
      'top_items': <dynamic>[],
      'time_metrics': {
        'avg_dispatch_hours': 12.5,
        'median_dispatch_hours': 10.0,
        'dispatched_within_24h_pct': 80.0,
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

  // ── Model parsing ─────────────────────────────────────────────────────────

  group('AnalyticsData.trend parsing', () {
    test('parses the backend {"day","count"} shape into points', () {
      final data = AnalyticsData.fromJson(_analyticsPayload());

      expect(data.trend, hasLength(3));
      expect(data.trend.first.day, '2026-08-25');
      expect(data.trend.first.count, 2);
      expect(data.trend[1].count, 5);
      expect(data.trend.last.day, '2026-09-10');
      expect(data.kpis.total, 8);
    });

    test('fails loudly in debug instead of silently dropping a missing '
        '"trend" key', () {
      final payload = _analyticsPayload(trend: null);
      // Remove the key entirely (simulating a renamed/changed contract).
      payload.remove('trend');

      if (kReleaseMode) {
        // Asserts are compiled out in release; parser falls back to [].
        final data = AnalyticsData.fromJson(payload);
        expect(data.trend, isEmpty);
      } else {
        expect(() => AnalyticsData.fromJson(payload),
            throwsA(isA<AssertionError>()));
      }
    });
  });

  // ── Widget rendering ──────────────────────────────────────────────────────

  final trendPaintFinder = find.byWidgetPredicate((w) =>
      w is CustomPaint &&
      w.painter != null &&
      w.painter!.runtimeType.toString().contains('TrendPainter'));

  group('Orders Trend card', () {
    testWidgets('draws a real (non-zero sized) chart when trend data exists',
        (tester) async {
      useTallSurface(tester);
      final now = DateTime.now();
      final from =
          DateFormat('y-MM-dd').format(now.subtract(const Duration(days: 30)));
      final to = DateFormat('y-MM-dd').format(now);
      final response = _analyticsPayload(trend: [
        {'day': from, 'count': 3},
        {'day': to, 'count': 7},
      ]);
      mockGet('/api/dashboard/analytics/',
          query: {'from': Matchers.any, 'to': Matchers.any}, body: response);

      await pumpScreen(tester, const AnalyticsScreen(), container);
      await tester.pumpAndSettle();

      // Regression for the blank card: the trend CustomPaint must receive a
      // non-zero canvas (previously it collapsed to width 0 and paint() bailed
      // on size.width <= 0, drawing nothing).
      expect(trendPaintFinder, findsOneWidget);
      final size = tester.getSize(trendPaintFinder);
      expect(size.width, greaterThan(0));
      expect(size.height, 80);
      expect(find.text('No order activity in this period'), findsNothing);
    });

    testWidgets('shows an explicit empty-state instead of a blank box when '
        'trend is empty', (tester) async {
      useTallSurface(tester);
      final response = _analyticsPayload(trend: <Map<String, dynamic>>[]);
      mockGet('/api/dashboard/analytics/',
          query: {'from': Matchers.any, 'to': Matchers.any}, body: response);

      await pumpScreen(tester, const AnalyticsScreen(), container);
      await tester.pumpAndSettle();

      expect(find.text('No order activity in this period'), findsOneWidget);
      expect(trendPaintFinder, findsNothing);
    });

    testWidgets('Today (single-day) range still paints a flat chart without '
        'NaN errors', (tester) async {
      useTallSurface(tester);
      final today = DateFormat('y-MM-dd').format(DateTime.now());
      final response = _analyticsPayload(trend: [
        {'day': today, 'count': 4},
      ]);
      mockGet('/api/dashboard/analytics/',
          query: {'from': Matchers.any, 'to': Matchers.any}, body: response);

      await pumpScreen(tester, const AnalyticsScreen(), container);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();

      expect(find.text('Today'), findsWidgets);
      expect(trendPaintFinder, findsOneWidget);
      expect(tester.getSize(trendPaintFinder).width, greaterThan(0));
    });
  });
}