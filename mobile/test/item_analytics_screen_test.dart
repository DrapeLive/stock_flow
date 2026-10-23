import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stock_flow_admin/features/analytics/item_analytics_screen.dart';
import 'package:stock_flow_admin/models/models.dart';

import 'helpers.dart';

Map<String, dynamic> _datePayload(String category, int pieces, double sales) {
  final payload = _analyticsPayload();
  payload['item_analytics'] = {
    'summary': {
      'total_pieces': pieces,
      'total_sales': sales,
      'distinct_items': 1,
    },
    'categories': [
      {'name': category, 'pieces': pieces, 'sales': sales},
    ],
    'fabrics': [
      {'name': '$category fabric', 'pieces': pieces, 'sales': sales},
    ],
  };
  return payload;
}

Map<String, dynamic> _analyticsPayload({bool includeItems = true}) {
  final payload = <String, dynamic>{
    'kpis': {
      'total': 2,
      'draft': 0,
      'pending': 1,
      'editing': 0,
      'packed': 1,
      'dispatched': 0,
      'total_value': 1500.0,
      'total_sets': 20,
      'total_pieces': 55,
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
  };
  if (includeItems) {
    payload['item_analytics'] = {
      'summary': {
        'total_pieces': 55,
        'total_sales': 1500.0,
        'distinct_items': 4,
      },
      'categories': [
        {'name': 'Shirts', 'pieces': 5, 'sales': 1000.0},
        {'name': 'Trousers', 'pieces': 50, 'sales': 500.0},
      ],
      'fabrics': [
        {'name': 'Cotton', 'pieces': 5, 'sales': 1000.0},
        {'name': 'Denim', 'pieces': 50, 'sales': 500.0},
      ],
    };
  }
  return payload;
}

Future<void> _pickDate(
  WidgetTester tester,
  String currentValue,
  String day,
) async {
  await tester.tap(find.text(currentValue));
  await tester.pumpAndSettle();
  await tester.tap(find.text(day).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

void main() {
  late ProviderContainer container;

  setUp(() async {
    await resetTestInfra();
    container = makeTestContainer();
    seedAdminSession();
    addTearDown(container.dispose);
  });

  group('ItemAnalyticsData parsing', () {
    test('parses summary, categories and fabrics', () {
      final data = AnalyticsData.fromJson(_analyticsPayload());

      expect(data.hasItemAnalytics, isTrue);
      expect(data.itemAnalytics.summary.totalPieces, 55);
      expect(data.itemAnalytics.summary.totalSales, 1500.0);
      expect(data.itemAnalytics.summary.distinctItems, 4);
      expect(data.itemAnalytics.categories, hasLength(2));
      expect(data.itemAnalytics.categories.first.name, 'Shirts');
      expect(data.itemAnalytics.categories.first.pieces, 5);
      expect(data.itemAnalytics.categories.first.sales, 1000.0);
      expect(data.itemAnalytics.fabrics.first.name, 'Cotton');
    });

    test('marks item analytics unavailable when the backend omits it', () {
      final data = AnalyticsData.fromJson(_analyticsPayload(includeItems: false));

      expect(data.hasItemAnalytics, isFalse);
      expect(data.itemAnalytics.summary.totalPieces, 0);
      expect(data.itemAnalytics.categories, isEmpty);
      expect(data.itemAnalytics.fabrics, isEmpty);
    });
  });

  group('ItemAnalyticsScreen', () {
    testWidgets('renders summary, category and fabric reports', (tester) async {
      useTallSurface(tester);
      mockGet(
        '/api/dashboard/analytics/',
        query: {'from': '2026-09-01', 'to': '2026-09-30'},
        body: _analyticsPayload(),
      );

      await pumpScreen(
        tester,
        const ItemAnalyticsScreen(from: '2026-09-01', to: '2026-09-30'),
        container,
      );
      await tester.pumpAndSettle();

      expect(find.text('Item-wise Analytics'), findsOneWidget);
      expect(find.text('TOTAL PIECES'), findsOneWidget);
      expect(find.text('TOTAL SALES'), findsOneWidget);
      expect(find.text('ITEMS SOLD'), findsOneWidget);
      expect(find.text('55'), findsNWidgets(3));
      expect(find.textContaining('1,500'), findsNWidgets(3));
      expect(find.text('SALES BY CATEGORY'), findsOneWidget);
      expect(find.text('SALES BY FABRIC'), findsOneWidget);
      expect(find.text('Shirts'), findsOneWidget);
      expect(find.text('Trousers'), findsOneWidget);
      expect(find.text('Cotton'), findsOneWidget);
      expect(find.text('Denim'), findsOneWidget);
      expect(find.text('Total'), findsNWidgets(2));
    });

    testWidgets('sorts both reports by sales amount or pieces sold',
        (tester) async {
      useTallSurface(tester);
      mockGet(
        '/api/dashboard/analytics/',
        query: {'from': '2026-09-01', 'to': '2026-09-30'},
        body: _analyticsPayload(),
      );

      await pumpScreen(
        tester,
        const ItemAnalyticsScreen(from: '2026-09-01', to: '2026-09-30'),
        container,
      );
      await tester.pumpAndSettle();

      final shirts = find.text('Shirts');
      final trousers = find.text('Trousers');
      expect(tester.getTopLeft(shirts).dy, lessThan(tester.getTopLeft(trousers).dy));

      await tester.tap(find.text('Pieces sold'));
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(trousers).dy,
        lessThan(tester.getTopLeft(shirts).dy),
      );
    });

    testWidgets('shows a retryable error when item analytics is missing',
        (tester) async {
      useTallSurface(tester);
      mockGet(
        '/api/dashboard/analytics/',
        query: {'from': '2026-09-01', 'to': '2026-09-30'},
        body: _analyticsPayload(includeItems: false),
      );

      await pumpScreen(
        tester,
        const ItemAnalyticsScreen(from: '2026-09-01', to: '2026-09-30'),
        container,
      );
      await tester.pumpAndSettle();

      expect(find.text('Could not load item analytics'), findsOneWidget);
      expect(find.textContaining('unavailable'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('applies a range, refreshes reports and collapses the picker',
        (tester) async {
      useTallSurface(tester);
      mockGet(
        '/api/dashboard/analytics/',
        query: {'from': '2026-09-01', 'to': '2026-09-30'},
        body: _analyticsPayload(),
      );
      mockGet(
        '/api/dashboard/analytics/',
        query: {'from': '2026-09-02', 'to': '2026-09-20'},
        body: _datePayload('Jackets', 12, 2400),
      );

      await pumpScreen(
        tester,
        const ItemAnalyticsScreen(from: '2026-09-01', to: '2026-09-30'),
        container,
      );
      await tester.pumpAndSettle();

      expect(find.text('Apply'), findsOneWidget);
      expect(find.text('2026-09-01'), findsOneWidget);
      expect(find.text('2026-09-30'), findsOneWidget);
      expect(find.text('Shirts'), findsOneWidget);

      await _pickDate(tester, '2026-09-01', '2');
      await _pickDate(tester, '2026-09-30', '20');

      expect(find.text('2026-09-02'), findsOneWidget);
      expect(find.text('2026-09-20'), findsOneWidget);

      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(find.text('Apply'), findsNothing);
      expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
      expect(find.text('2026-09-02 – 2026-09-20'), findsOneWidget);
      expect(find.text('Jackets'), findsOneWidget);
      expect(find.text('Shirts'), findsNothing);

      await tester.tap(find.byIcon(Icons.calendar_today_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Apply'), findsOneWidget);
      expect(find.text('2026-09-02'), findsOneWidget);
      expect(find.text('2026-09-20'), findsOneWidget);
    });

    testWidgets('an unapplied range change is discarded on collapse',
        (tester) async {
      useTallSurface(tester);
      mockGet(
        '/api/dashboard/analytics/',
        query: {'from': '2026-09-02', 'to': '2026-09-20'},
        body: _datePayload('Jackets', 12, 2400),
      );
      await pumpScreen(
        tester,
        const ItemAnalyticsScreen(from: '2026-09-02', to: '2026-09-20'),
        container,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.calendar_today_outlined));
      await tester.pumpAndSettle();

      await _pickDate(tester, '2026-09-02', '15');

      expect(find.text('2026-09-15'), findsOneWidget);
      expect(find.text('Jackets'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.calendar_today_outlined).first);
      await tester.pumpAndSettle();

      expect(find.text('2026-09-02 – 2026-09-20'), findsOneWidget);
      expect(find.text('Jackets'), findsOneWidget);
      expect(find.text('Caps'), findsNothing);

      await tester.tap(find.byIcon(Icons.calendar_today_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Apply'), findsOneWidget);
      expect(find.text('2026-09-02'), findsOneWidget);
      expect(find.text('2026-09-20'), findsOneWidget);
      expect(find.text('2026-09-15'), findsNothing);
    });

    testWidgets('Apply is disabled while a request is in flight',
        (tester) async {
      useTallSurface(tester);
      dioAdapter.onGet(
        '/api/dashboard/analytics/',
        (server) => server.reply(
          200,
          _analyticsPayload(),
          delay: const Duration(milliseconds: 300),
        ),
        queryParameters: {
          'from': '2026-09-01',
          'to': '2026-09-30',
        },
      );

      await pumpScreen(
        tester,
        const ItemAnalyticsScreen(from: '2026-09-01', to: '2026-09-30'),
        container,
      );
      await tester.pump();

      expect(find.byType(FilledButton), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('Apply'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
    });
  });
}
