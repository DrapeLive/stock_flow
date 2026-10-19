import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import 'package:stock_flow_admin/core/api/api_client.dart';
import 'package:stock_flow_admin/core/theme/app_theme.dart';
import 'package:stock_flow_admin/data/repositories.dart';
import 'package:stock_flow_admin/features/dashboard/dashboard_screen.dart';

import 'helpers.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

/// An `orderJson()` draft plus the server-derived `expires_at` that ONLY
/// `GET /api/orders/admin-drafts/` sends. [expiresIn] is deliberately given
/// half-minute margins so a rendered "Expires in Xm" label cannot flip across
/// a minute boundary while the test runs.
Map<String, dynamic> draftOrderJson({
  required int id,
  Duration expiresIn = const Duration(minutes: 9, seconds: 30),
  String customerName = 'XL Fashions',
}) =>
    {
      ...orderJson(),
      'id': id,
      'status': 'DRAFT',
      'customer_details': {...customerJson(), 'name': customerName},
      'expires_at': DateTime.now().add(expiresIn).toIso8601String(),
    };

Map<String, dynamic> draftsBody(List<Map<String, dynamic>> results) => {
      'count': results.length,
      'next': null,
      'previous': null,
      'results': results,
    };

// ---------------------------------------------------------------------------
// OrderRepo endpoints
// ---------------------------------------------------------------------------

void main() {
  setUp(() async {
    await resetTestInfra();
  });

  group('draftRemainingLabel', () {
    final now = DateTime(2026, 10, 6, 12);

    test('formats future expiries at second/minute/hour precision', () {
      expect(
        draftRemainingLabel('2026-10-06T12:12:30', now: now),
        '12m 30s',
      );
      expect(draftRemainingLabel('2026-10-06T12:00:45', now: now), '45s');
      expect(draftRemainingLabel('2026-10-06T14:05:00', now: now), '2h 5m');
    });

    test('marks past expiries Expired and bad input null', () {
      expect(
        draftRemainingLabel('2026-10-06T11:59:00', now: now),
        'Expired',
      );
      expect(draftRemainingLabel(null), isNull);
      expect(draftRemainingLabel('not-a-timestamp'), isNull);
    });

    test('parses the offset timestamps the backend actually sends', () {
      final expiresAt = now.add(const Duration(minutes: 3)).toIso8601String();
      expect(draftRemainingLabel(expiresAt, now: now), '3m 0s');
    });
  });

  group('OrderRepo abandoned draft endpoints', () {
    test('getAdminDrafts parses count, rows and the derived expiry',
        () async {
      mockGet('/api/orders/admin-drafts/',
          body: draftsBody([draftOrderJson(id: 41)]));

      final page = await repos.order.getAdminDrafts();

      expect(page.count, 1);
      final draft = page.results.single;
      expect(draft.id, 41);
      expect(draft.status, 'DRAFT');
      expect(draft.expiresAt, isNotNull);
      expect(DateTime.tryParse(draft.expiresAt!), isNotNull);
    });

    test('acceptDraft sends the admin PIN to the admin-accept endpoint', () async {
      var calls = 0;
      dioAdapter.onPost(
        '/api/orders/9/admin-accept-draft/',
        // replyCallback's data fn runs PER SERVED REQUEST (unlike the plain
        // (server) => server.reply(...) callback, which configures the handler
        // once at registration), so it doubles as a call counter.
        (server) => server.replyCallback(200, (options) {
          calls++;
          return {'message': 'Order placed', 'order_id': 9};
        }),
        data: const JsonBody({'pin': '2468'}),
      );

      await repos.order.acceptDraft(9, '2468');

      expect(calls, 1);
    });

    test('rejectDraft sends the admin PIN in the body', () async {
      dioAdapter.onPost(
        '/api/orders/9/admin-reject-draft/',
        (server) =>
            server.reply(200, {'message': 'Draft rejected', 'order_id': 9}),
        data: const JsonBody({'pin': '2468'}),
      );

      await repos.order.rejectDraft(9, '2468');
    });

    test('a backend rejection surfaces the server message as ApiException',
        () async {
      dioAdapter.onPost(
        '/api/orders/9/admin-accept-draft/',
        (server) => server.reply(400, {'detail': 'This draft has expired'}),
        data: const JsonBody({'pin': '2468'}),
      );

      await expectLater(
        repos.order.acceptDraft(9, '2468'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.message, 'message', 'This draft has expired'),
        ),
      );
    });
  });

  // -------------------------------------------------------------------------
  // Dashboard: banner + Drafts tab + accept/reject flows
  // -------------------------------------------------------------------------

  group('DashboardScreen abandoned drafts', () {
    late ProviderContainer container;

    setUp(() async {
      await resetTestInfra();
      container = makeTestContainer();
      addTearDown(container.dispose);
      seedAdminSession();
    });

    /// The dashboard's endpoints for a Pending-tab session whose only drafts
    /// are [drafts]. Every non-DRAFT order is marked viewed so the shared
    /// unread pulse stays stopped and `pumpAndSettle` can settle.
    void mockDashboard({List<Map<String, dynamic>> drafts = const []}) {
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
      mockGet('/api/orders/admin-drafts/', body: draftsBody(drafts));
    }

    /// The count Text rendered in the header Row (direct Text children only,
    /// so nested labels such as the Unread chip are never picked up).
    String headerCount(WidgetTester tester, String headerLabel) {
      final label = find.text(headerLabel);
      expect(label, findsOneWidget, reason: '$headerLabel header must render');
      final row = tester.widget<Row>(
        find.ancestor(of: label, matching: find.byType(Row)).first,
      );
      final counts = [
        for (final child in row.children)
          if (child is Text && child.data != headerLabel) child.data,
      ];
      expect(counts, hasLength(1),
          reason: 'expected exactly one count in the $headerLabel header');
      return counts.single!;
    }

    testWidgets('banner shows the count + oldest expiry above the tab strip',
        (tester) async {
      useTallSurface(tester);
      // List order mirrors the server (oldest first): #7 is closest to
      // expiring, so it must drive the banner line.
      mockDashboard(drafts: [
        draftOrderJson(id: 7, expiresIn: const Duration(minutes: 5, seconds: 30)),
        draftOrderJson(id: 8, expiresIn: const Duration(minutes: 12, seconds: 30)),
      ]);

      await pumpScreen(tester, const DashboardScreen(), container);
      await tester.pumpAndSettle();

      expect(find.text('2 abandoned drafts to review'), findsOneWidget);
      expect(
        find.textContaining('Oldest expires in 5m'),
        findsOneWidget,
        reason: 'the banner reports the OLDEST draft expiry',
      );
      expect(
        find.textContaining('Oldest expires in 12m'),
        findsNothing,
        reason: 'the newest draft must not be reported as the oldest',
      );

      final bannerY = tester
          .getTopLeft(find.text('2 abandoned drafts to review'))
          .dy;
      final tabY = tester.getTopLeft(find.text('Drafts')).dy;
      expect(bannerY, lessThan(tabY),
          reason: 'the banner sits ABOVE the tab strip');
    });

    testWidgets('tapping the banner opens the Drafts tab',
        (tester) async {
      useTallSurface(tester);
      mockDashboard(drafts: [draftOrderJson(id: 7)]);

      await pumpScreen(tester, const DashboardScreen(), container);
      await tester.pumpAndSettle();

      await tester.tap(find.text('1 abandoned draft to review'));
      await tester.pumpAndSettle();

      final draftTab = tester.widget<AnimatedContainer>(
        find
            .ancestor(of: find.text('Drafts'), matching: find.byType(AnimatedContainer))
            .first,
      );
      expect((draftTab.decoration as BoxDecoration?)?.color,
          AppColors.primary,
          reason: 'the Drafts tab became active');
      expect(headerCount(tester, 'Abandoned drafts'), '1');
    });

    testWidgets(
        'Drafts tab lists cards with countdown + Accept/Reject, expands items '
        'inline and never navigates', (tester) async {
      useTallSurface(tester);
      mockDashboard(drafts: [
        draftOrderJson(id: 7),
        draftOrderJson(
            id: 8,
            customerName: 'Zen Stores',
            expiresIn: const Duration(minutes: 12, seconds: 30)),
      ]);

      await pumpScreen(tester, const DashboardScreen(), container);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Drafts'));
      await tester.pumpAndSettle();

      expect(headerCount(tester, 'Abandoned drafts'), '2');
      expect(find.text('ID #7'), findsOneWidget);
      expect(find.text('ID #8'), findsOneWidget);
      expect(find.text('Accept'), findsNWidgets(2));
      expect(find.text('Reject'), findsNWidgets(2));
      expect(find.textContaining('Expires in 9m'), findsOneWidget);
      expect(find.textContaining('Expires in 12m'), findsOneWidget);
      // Search/filters take no parameters on this endpoint, so they are
      // hidden rather than shown as no-ops.
      expect(find.byType(TextField), findsNothing);

      // Inline expansion. If this tap ever regressed into a router push the
      // test would throw (the harness has no GoRouter) and fail.
      expect(find.text('ITEM-A'), findsNothing);
      await tester.tap(find.text('Tap to view 1 item').first);
      await tester.pumpAndSettle();

      expect(find.textContaining('ITEM-A'), findsWidgets);
      expect(find.textContaining('Tap to hide items'), findsOneWidget);
      expect(find.text('Abandoned drafts'), findsOneWidget,
          reason: 'still on the dashboard, not navigated away');
    });

    testWidgets('Reject asks for the PIN before firing any request; Cancel does nothing',
        (tester) async {
      useTallSurface(tester);
      mockDashboard(drafts: [draftOrderJson(id: 7)]);

      var rejectCalls = 0;
      dioAdapter.onPost(
        '/api/orders/7/admin-reject-draft/',
        (server) => server.replyCallback(200, (options) {
          rejectCalls++;
          return {'message': 'Draft rejected', 'order_id': 7};
        }),
        data: Matchers.any,
      );

      await pumpScreen(tester, const DashboardScreen(), container);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Drafts'));
      await tester.pumpAndSettle();

      // Cancel: nothing is sent, the card stays.
      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();
      expect(find.text('Discard Draft'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(rejectCalls, 0, reason: 'Cancel must not fire the endpoint');
      expect(find.text('ID #7'), findsOneWidget);

      // Confirm: exactly one request with the entered PIN, card removed.
      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '4242');
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(rejectCalls, 1);
      expect(find.text('ID #7'), findsNothing);
      expect(find.textContaining('Draft #7 discarded'), findsOneWidget);
      expect(find.text('No Abandoned Drafts'), findsOneWidget);
      expect(headerCount(tester, 'Abandoned drafts'), '0');
      // Let the success toast's 3s auto-dismiss timer fire.
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('Accept places without asking for a PIN and removes the card',
        (tester) async {
      useTallSurface(tester);
      mockDashboard(drafts: [
        draftOrderJson(id: 7),
        draftOrderJson(id: 8, customerName: 'Zen Stores'),
      ]);

      var acceptCalls = 0;
      dioAdapter.onPost(
        '/api/orders/7/admin-accept-draft/',
        (server) => server.replyCallback(200, (options) {
          acceptCalls++;
          return {'message': 'Order placed', 'order_id': 7};
        }),
        data: Matchers.any,
      );

      await pumpScreen(tester, const DashboardScreen(), container);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Drafts'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Accept').first);
      await tester.pumpAndSettle();

      expect(acceptCalls, 1);
      expect(find.text('Enter PIN'), findsNothing,
          reason: 'Accept never asks for a PIN');
      expect(find.text('ID #7'), findsNothing);
      expect(find.text('ID #8'), findsOneWidget,
          reason: 'the other draft stays listed');
      expect(headerCount(tester, 'Abandoned drafts'), '1');
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('a server rejection shows its message and keeps the list truthful',
        (tester) async {
      useTallSurface(tester);
      mockDashboard(drafts: [draftOrderJson(id: 7)]);

      dioAdapter.onPost(
        '/api/orders/7/admin-accept-draft/',
        (server) =>
            server.reply(400, {'detail': 'This draft has expired'}),
        data: Matchers.any,
      );

      await pumpScreen(tester, const DashboardScreen(), container);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Drafts'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();

      expect(find.text('This draft has expired'), findsOneWidget,
          reason: 'the backend message reaches the admin verbatim');
      expect(find.text('ID #7'), findsOneWidget,
          reason: 'an action that failed must not remove the card');
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('no drafts: no banner, empty state on the tab',
        (tester) async {
      useTallSurface(tester);
      mockDashboard();

      await pumpScreen(tester, const DashboardScreen(), container);
      await tester.pumpAndSettle();

      expect(find.textContaining('abandoned draft'), findsNothing,
          reason: 'a zero count hides the banner entirely');

      await tester.tap(find.text('Drafts'));
      await tester.pumpAndSettle();

      expect(find.text('No Abandoned Drafts'), findsOneWidget);
      expect(find.text('Accept'), findsNothing);
      expect(headerCount(tester, 'Abandoned drafts'), '0');
    });
  });
}
