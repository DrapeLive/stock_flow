<<<<<<< HEAD
=======
import 'dart:convert';
>>>>>>> dev
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_ce/hive.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
<<<<<<< HEAD
=======
import 'package:http_mock_adapter/http_mock_adapter.dart' as mock;
>>>>>>> dev

import 'package:stock_flow_admin/core/api/api_client.dart';
import 'package:stock_flow_admin/core/cache/app_cache.dart';
import 'package:stock_flow_admin/core/theme/app_theme.dart';
import 'package:stock_flow_admin/models/models.dart';
import 'package:stock_flow_admin/providers.dart';

import 'package:stock_flow_admin/data/item_store.dart';

/// A single shared binding for the whole suite.
final TestWidgetsFlutterBinding binding = TestWidgetsFlutterBinding.ensureInitialized();

bool _hiveInit = false;

/// Initialises Hive into a throwaway temp dir (once) and wires the AppCache
/// static boxes so `path_provider`/`getApplicationDocumentsDirectory` are
/// never needed. Boxes use the in-memory backend so `put`/`clear` complete
/// immediately — async file writes never resolve under flutter_test's
/// FakeAsync and would stall any widget test that trips `networkFirst`.
/// Also disables google_fonts network fetching so text renders with the
/// fallback font in tests.
Future<void> initTestInfra() async {
  if (_hiveInit) return;
  final dir = Directory.systemTemp.createTempSync('stock_flow_hive_test_');
  Hive.init(dir.path);
  AppCache.sessionBox =
      await Hive.openBox(AppCache.sessionBoxName, bytes: Uint8List(0));
  AppCache.prefsBox =
      await Hive.openBox(AppCache.prefsBoxName, bytes: Uint8List(0));
  AppCache.cacheBox =
      await Hive.openBox(AppCache.cacheBoxName, bytes: Uint8List(0));
  AppCache.itemSyncBox =
      await Hive.openBox(AppCache.itemSyncBoxName, bytes: Uint8List(0));
  GoogleFonts.config.allowRuntimeFetching = false;
  _hiveInit = true;
}

/// The current DioAdapter; recreated per test by [resetTestInfra].
late DioAdapter dioAdapter;

/// Clears Hive boxes, resets auth token/interceptors, and swaps in a fresh
/// [DioAdapter] (unmocked routes throw -> catches test mistakes early).
Future<void> resetTestInfra() async {
  await initTestInfra();
  await AppCache.sessionBox.clear();
  await AppCache.prefsBox.clear();
  await AppCache.cacheBox.clear();
  AppCache.clearItemSync();
  ApiClient.setToken(null);
  ApiClient.init();
  dioAdapter = DioAdapter(dio: ApiClient.dio);
}

// ---------------------------------------------------------------------------
// Request mocking (http_mock_adapter 0.6.x)
// ---------------------------------------------------------------------------

void mockGet(
  String path, {
  dynamic body,
  Map<String, dynamic>? query,
  int status = 200,
}) {
  dioAdapter.onGet(
    path,
    (server) => server.reply(status, body ?? const <String, dynamic>{}),
    queryParameters: query ?? const <String, dynamic>{},
  );
}

void mockPost(String path, {dynamic body, Map<String, dynamic>? query}) {
  dioAdapter.onPost(
    path,
    (server) => server.reply(200, body ?? const <String, dynamic>{}),
    queryParameters: query ?? const <String, dynamic>{},
    data: Matchers.any,
  );
}

<<<<<<< HEAD
=======
/// Matches a JSON request body exactly (decoded map or encoded string), so a
/// payload-shape regression fails loudly instead of silently dropping the
/// fields the backend actually reads. Implemented against the mock adapter's
/// own matcher interface, which is distinct from `package:matcher`'s.
class JsonBody implements mock.Matcher {
  const JsonBody(this.expected);

  final Map<String, dynamic> expected;

  @override
  bool matches(dynamic actual) {
    Object? decoded = actual;
    if (decoded is String) {
      try {
        decoded = jsonDecode(decoded);
      } catch (_) {
        return false;
      }
    }
    if (decoded is! Map) return false;
    final map = decoded;
    if (map.length != expected.length) return false;
    return expected.entries.every((e) => map[e.key] == e.value);
  }
}

>>>>>>> dev
void mockPut(String path, {dynamic body, Map<String, dynamic>? query}) {
  dioAdapter.onPut(
    path,
    (server) => server.reply(200, body ?? const <String, dynamic>{}),
    queryParameters: query ?? const <String, dynamic>{},
    data: Matchers.any,
  );
}

void mockPatch(String path, {dynamic body, Map<String, dynamic>? query}) {
  dioAdapter.onPatch(
    path,
    (server) => server.reply(200, body ?? const <String, dynamic>{}),
    queryParameters: query ?? const <String, dynamic>{},
    data: Matchers.any,
  );
}

void mockDelete(String path, {dynamic body, Map<String, dynamic>? query}) {
  dioAdapter.onDelete(
    path,
    (server) => server.reply(200, body ?? const <String, dynamic>{}),
    queryParameters: query ?? const <String, dynamic>{},
    data: Matchers.any,
  );
}

// ---------------------------------------------------------------------------
// Session + widget pumping
// ---------------------------------------------------------------------------

/// Fresh container with the connectivity provider overridden to "online" so
/// the connectivity_plus platform channel is never invoked.
ProviderContainer makeTestContainer() => ProviderContainer(
      overrides: [
        connectivityProvider
            .overrideWith((ref) => Stream.value(true)),
      ],
    );

/// Persists an admin session into the Hive session box. The
/// [sessionProvider] restores from this on first read, so seed BEFORE pumping.
/// [business] defaults to the historical 'xlapparals' fixture value (treated
/// as no business); pass 'gents'/'kids' to simulate a business-scoped admin.
void seedAdminSession({String? business = 'xlapparals'}) {
  AppCache.sessionPut('access', 'test-access');
  AppCache.sessionPut('refresh', 'test-refresh');
  AppCache.sessionPut(
    'user',
    AuthUser(
      id: 1,
      role: 'ADMIN',
      username: 'admin',
      email: 'admin@xlapparals.in',
      business: business,
    ).toJson(),
  );
}

/// Larger-than-default surface so admin layouts don't overflow in tests.
void useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(600, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Pumps [child] inside a ProviderScope backed by [container].
Future<void> pumpScreen(
  WidgetTester tester,
  Widget child,
  ProviderContainer container,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: child,
      ),
    ),
  );
  await tester.pump();
}

// ---------------------------------------------------------------------------
// Fixture data (mirrors the Django serializer keys)
// ---------------------------------------------------------------------------

Map<String, dynamic> customerJson() => {
      'id': 3,
      'name': 'XL Fashions',
      'address': 'MG Road, Pune',
      'contact': '9876500000',
      'agent': 2,
      'agent_name': 'Agent Alpha',
      'gst': '27AAAAA0000A1Z5',
      'preferred_transport': 1,
      'preferred_transport_name': 'VRL Logistics',
      'total_orders': 4,
    };

Map<String, dynamic> agentJson() => {
      'id': 2,
      'user': {
        'id': 20,
        'username': 'agent_alpha',
        'email': 'alpha@xlapparals.in',
        'display_name': 'Agent Alpha',
      },
      'contact': '9850000000',
      'total_customers': 3,
    };

Map<String, dynamic> agentDetailJson() => {
      'id': 2,
      'user': {
        'id': 3,
        'username': 'agent1',
        'email': 'agent1@gmail.com',
        'role': 'AGENT',
        'display_name': 'agent1',
      },
      'contact': '8281700904',
      'total_customers': 0,
      'assigned_items': [
        {
          'id': 1,
          'name': '00001',
          'type': 'kids',
          'price': '200.00',
          'variants': [
            {
              'id': 1,
              'image': '',
              'qr_code': '7ab1526b-70cb-4490-bc09-c560dff4dc3d',
              'size_ranges': [
                {'size_range': '38', 'stock': 10},
                {'size_range': '20-24', 'stock': 10},
              ],
              'created_at': DateTime.now().toUtc().toIso8601String(),
              'display_order': '1',
            },
          ],
        },
      ],
    };

Map<String, dynamic> variantAllRealJson() => {
      'id': 1,
      'item_id': 1,
      'item_name': '00001',
      'item_type': 'kids',
      'item_price': '200.00',
      'qr_code': '7ab1526b-70cb-4490-bc09-c560dff4dc3d',
      'image': '',
      'sizes': [
        {'size': '38', 'stock': 10},
        {'size': '20-24', 'stock': 7},
      ],
      'total_stock': 31,
      'unique_sizes': ['20-24', '32-36', '26-30', '38'],
    };

Map<String, dynamic> paginatedOrderJson() => {
      'count': 1,
      'next': null,
      'previous': null,
      'results': [orderJson()],
    };

Map<String, dynamic> orderItemJson() => {
      'id': 11,
      'item': itemJson(),
      'variant': 100,
      'size_group': 'S,M,L,XL',
      'size': 'M,L,XL',
      'item_name': 'ITEM-A',
      'item_price': '500',
      'variant_image': '',
      'quantity': 2,
      'original_quantity': 2,
      'packed_quantity': 0,
      'piece_count': 4,
      'variant_display_order': '1',
      'order': 1,
    };

Map<String, dynamic> orderJson() => {
      'id': 1,
      'items': [orderItemJson()],
      'agent_details': agentJson()['user'],
      'customer_details': customerJson(),
      'total_quantity': '2',
      'total_sets': 2,
      'total_pieces': 8,
      'status': 'PENDING',
      'created_at': '2026-08-20',
      'expected_delivery_date': '2026-09-01',
      'preferred_transport': 1,
      'preferred_transport_name': 'VRL Logistics',
      'transport_company': null,
      'transport_company_name': null,
      'lr_number': '',
      'notes': '',
    };

Map<String, dynamic> itemJson() => {
      'id': 10,
      'name': 'ITEM-A',
      'type': 'gents',
      'price': '500',
      'description': 'Test item',
      'variants': [
        {
          'id': 100,
          'qr_code': 'QRONE',
          'image': '',
          'display_order': '1',
          'sizes': [
            {'id': 1, 'size_range': 'S', 'stock': 5},
            {'id': 2, 'size_range': 'M,L,XL', 'stock': 5},
          ],
        },
      ],
    };

Map<String, dynamic> stockEntryJson() => {
      'id': 10,
      'name': 'ITEM-A',
      'type': 'gents',
      'price': '500',
      'image': '',
      'variants': [
        {
          'id': 100,
          'qr_code': 'QRONE',
          'image': '',
          'sizes': [
            {'size_range': 'S', 'stock': 5},
            {'size_range': 'M,L,XL', 'stock': 5},
          ],
          'total_stock': 10,
          'display_order': '1',
          'created_at': '',
        },
      ],
    };

// ---------------------------------------------------------------------------
// Item sync store fixtures
// ---------------------------------------------------------------------------

/// Converts a stock-list-shaped item (as used by the widget-test fixtures)
/// into a `/api/items/sync/` payload item so the screen can be driven from the
/// synced store.
Map<String, dynamic> asSyncItem(Map<String, dynamic> e) => {
      'id': e['id'],
      'rev': 'r1',
      'name': e['name'],
      'type': e['type'],
      'price': e['price'],
      'thumb': e['image'],
      'out_of_stock_since': null,
      'variants': [
        for (final v in (e['variants'] as List? ?? const []))
          {
            'id': v['id'],
            'qr_code': v['qr_code'],
            'image': v['image'],
            'display_order': v['display_order'],
            'sizes': [
              for (final s in (v['sizes'] as List? ?? const []))
                {
                  'id': asInt(s['id']),
                  'size': s['size_range'] ?? s['size'],
                  'stock': s['stock'],
                },
            ],
          },
      ],
    };

/// Seeds [AppCache.itemSyncBox] with [entries] so the Stock screen renders
/// them immediately (mirrors a completed bootstrap).
void seedItemStore(List<dynamic> entries) {
  for (final e in entries) {
    final item = asSyncItem((e as Map).cast<String, dynamic>());
    AppCache.itemSyncBox.put('$kItemSyncKeyPrefix${item['id']}', item);
  }
  AppCache.itemSyncBox.put('$kItemSyncKeyPrefix$kItemSyncMetaKey', {
    'schema': 1,
    'cursor': null,
    'lastFullSync': DateTime.now().toUtc().toIso8601String(),
    'archiveAfterDays': 30,
    'serverTimeOffsetMs': 0,
  });
}

/// A full-mode sync page for mocking the background round.
Map<String, dynamic> syncPageJson({List<dynamic>? items}) {
  final list = (items ?? [stockEntryJson()]).map((e) => asSyncItem((e as Map).cast<String, dynamic>())).toList();
  return {
    'mode': 'full',
    'cursor': DateTime.now().toUtc().toIso8601String(),
    'server_time': DateTime.now().toUtc().toIso8601String(),
    'archive_after_days': 30,
    'items': list,
    'stock': <dynamic>[],
    'removed_item_ids': <dynamic>[],
    'check': {
      'items': list.length,
      'total_stock': 10,
    },
    'next_page': null,
  };
}

/// An empty delta page (returned for `since` requests after a full bootstrap).
Map<String, dynamic> syncDeltaJson() => {
      'mode': 'delta',
      'cursor': DateTime.now().toUtc().toIso8601String(),
      'server_time': DateTime.now().toUtc().toIso8601String(),
      'archive_after_days': 30,
      'items': <dynamic>[],
      'stock': <dynamic>[],
      'removed_item_ids': <dynamic>[],
      'check': {'items': 1, 'total_stock': 10},
      'next_page': null,
    };

/// Registers sync mocks for BOTH bootstrap (no `since`) and the verify
/// `since` round, so the background sync round completes instead of looping.
/// NOTE: DioAdapter keeps the LAST matching handler, so the specific `since`
/// mock must be registered AFTER the generic (query-less) bootstrap mock.
void mockItemSync({List<dynamic>? items}) {
  mockGet('/api/items/sync/', body: syncPageJson(items: items));
  mockGet('/api/items/sync/',
      query: const {'since': Matchers.any}, body: syncDeltaJson());
}

Map<String, dynamic> sizeRangesJson() => {
      'order_creation_sizes_by_type': {
        'gents': ['S,M,L,XL', 'M,L,XL,XXL', 'S,M,L,XL,XXL'],
        'kids': ['20-38', '20-36', '26-38', '26-36', '20-30', '32-38'],
      },
      'item_creation_sizes_by_type': {
        'gents': [
          'S,M,L,XL,XXL',
          'S,M,L,XL',
          'M,L,XL,XXL',
          'M,L,XL',
        ],
        'kids': ['20-24', '26-36', '38'],
      },
    };

Map<String, dynamic> analyticsJson() => {
      'kpis': {
        'total': 10,
        'draft': 1,
        'pending': 4,
        'editing': 1,
        'packed': 2,
        'dispatched': 2,
        'total_value': 15000.00,
        'total_sets': 32,
        'total_pieces': 90,
      },
      'trend': [
        {'day': '2026-08-01', 'count': 3},
      ],
      'top_customers': [
        {'id': 3, 'name': 'XL Fashions', 'count': 4},
      ],
      'top_agents': [
        {'id': 2, 'name': 'Agent Alpha', 'count': 5},
      ],
      'top_items': [
        {'id': 10, 'name': 'ITEM-A', 'count': 2},
      ],
      'time_metrics': {
        'avg_dispatch_hours': 12.5,
        'median_dispatch_hours': 10.0,
        'dispatched_within_24h_pct': 80.0,
      },
    };

Map<String, dynamic> transportJson() => {
      'id': 1,
      'name': 'VRL Logistics',
      'is_active': true,
      'created_at': '',
    };

Map<String, dynamic> variantAllJson() => {
      'id': 100,
      'item_id': 10,
      'item_name': 'ITEM-A',
      'item_type': 'gents',
      'item_price': '500',
      'qr_code': 'QRONE',
      'image': '',
      'sizes': [
        {'size': 'S', 'stock': 5},
        {'size': 'M,L,XL', 'stock': 5},
      ],
      'total_stock': 10,
      'unique_sizes': ['S', 'M', 'L', 'XL'],
    };

Map<String, dynamic> customerRequirementsJson() => {
      'item': itemJson(),
      'customers': [
        {
          'customer_name': 'XL Fashions',
          'variant_display_order': '1',
          'quantity': 2,
          'size_group': 'S,M,L,XL',
          'variant_image': '',
        },
      ],
    };

Map<String, dynamic> unpackedJson() => {
      'id': 21,
      'item_name': 'ITEM-A',
      'item_type': 'gents',
      'variant_display_order': '1',
      'quantity': 2,
      'size_group': 'S,M,L,XL',
      'variant_image': '',
      'piece_count': 4,
    };

Map<String, dynamic> loginResponseJson({String? business = 'xlapparals'}) => {
      'user_id': 1,
      'role': 'ADMIN',
      'username': 'admin',
      'email': 'admin@xlapparals.in',
      'business': business,
      'is_superuser': true,
      'access': 'mock-access-token',
      'refresh': 'mock-refresh-token',
    };