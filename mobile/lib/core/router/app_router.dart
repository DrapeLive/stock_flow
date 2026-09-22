import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/analytics/analytics_screen.dart';
import '../../features/auth/forgot_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/reset_screen.dart';
import '../../features/bulk_import/bulk_import_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/items/item_edit_screen.dart';
import '../../features/items/item_wizard_screen.dart';
import '../../features/items/items_screen.dart';
import '../../features/items/ordered_items_screen.dart';
import '../../features/items/qr_label_screen.dart';
import '../../features/items/qr_print_select_screen.dart';
import '../../features/orders/order_create_customer_screen.dart';
import '../../features/orders/order_create_item_screen.dart';
import '../../features/orders/order_create_scanner_screen.dart';
import '../../features/orders/order_create_search_screen.dart';
import '../../features/orders/order_create_screen.dart';
import '../../features/orders/order_edit_stub_screen.dart';
import '../../features/orders/order_status_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/summary/summary_screen.dart';
import '../../features/users/agent_detail_screen.dart';
import '../../features/users/agent_new_screen.dart';
import '../../features/users/customer_detail_screen.dart';
import '../../features/users/customer_new_screen.dart';
import '../../features/users/users_screen.dart';
import '../../providers.dart';
import 'route_observer.dart';

/// Production of the app's [GoRouter]. Mirrors the role guard in
/// `proxy.ts` / `AuthContext` — unauthenticated users land on `/login`,
/// authenticated users are pushed to `/admin`.
final routerProvider = Provider<GoRouter>((ref) {
  final refreshListenable = ValueNotifier<int>(0);
  ref.listen(
    sessionProvider.select((s) => s != null),
    (_, __) => refreshListenable.value++,
    fireImmediately: true,
  );

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: refreshListenable,
    observers: [routeObserver],
    redirect: (context, state) {
      final loggedIn = ref.read(sessionProvider) != null;
      final location = state.matchedLocation;
      if (!loggedIn && location != '/login') return '/login';
      if (loggedIn && (location == '/login' || location == '/')) return '/admin';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (c, s) => const ForgotScreen(),
      ),
      GoRoute(
        path: '/reset-password/:token',
        builder: (c, s) => ResetScreen(token: Uri.decodeComponent(s.pathParameters['token'] ?? '')),
      ),
      GoRoute(path: '/admin', builder: (c, s) => const DashboardScreen()),
      GoRoute(path: '/admin/profile', builder: (c, s) => const ProfileScreen()),
      GoRoute(path: '/admin/analytics', builder: (c, s) => const AnalyticsScreen()),
      GoRoute(path: '/admin/summary', builder: (c, s) => const SummaryScreen()),
      GoRoute(
        path: '/admin/bulk-import',
        builder: (c, s) => const BulkImportScreen(),
      ),
      GoRoute(path: '/admin/users', builder: (c, s) => const UsersScreen()),
      GoRoute(
        path: '/admin/users/customers/new',
        builder: (c, s) => const CustomerNewScreen(),
      ),
      GoRoute(
        path: '/admin/users/customers/:id',
        builder: (c, s) => CustomerDetailScreen(
          customerId: int.parse(s.pathParameters['id'] ?? '0'),
        ),
      ),
      GoRoute(
        path: '/admin/users/agents/new',
        builder: (c, s) => const AgentNewScreen(),
      ),
      GoRoute(
        path: '/admin/users/agents/:id',
        builder: (c, s) =>
            AgentDetailScreen(agentId: int.parse(s.pathParameters['id'] ?? '0')),
      ),
      GoRoute(path: '/admin/items', builder: (c, s) => const ItemsScreen()),
      GoRoute(
        path: '/admin/items/new',
        builder: (c, s) => const ItemWizardScreen(),
      ),
      GoRoute(
        path: '/admin/items/edit/:id',
        builder: (c, s) =>
            ItemEditScreen(itemId: int.parse(s.pathParameters['id'] ?? '0')),
      ),
      GoRoute(
        path: '/admin/items/ordered/:id',
        builder: (c, s) => OrderedItemsScreen(
          itemId: int.parse(s.pathParameters['id'] ?? '0'),
        ),
      ),
      GoRoute(
        path: '/admin/items/qr/:qr',
        builder: (c, s) => QrLabelScreen(qr: s.pathParameters['qr'] ?? ''),
      ),
      GoRoute(
        path: '/admin/items/qr-print',
        builder: (c, s) => QrPrintSelectScreen(
          itemId: int.tryParse(s.uri.queryParameters['item'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/admin/order/new',
        builder: (c, s) => OrderCreateCustomerScreen(
          presetCustomerId:
              int.tryParse(s.uri.queryParameters['customer'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/admin/order/new/:id',
        builder: (c, s) => OrderCreateScreen(
          customerId: int.parse(s.pathParameters['id'] ?? '0'),
        ),
      ),
      GoRoute(
        path: '/admin/order/new/:id/scan',
        builder: (c, s) => OrderCreateScannerScreen(
          customerId: int.parse(s.pathParameters['id'] ?? '0'),
        ),
      ),
      GoRoute(
        path: '/admin/order/new/:id/search',
        builder: (c, s) => OrderCreateSearchScreen(
          customerId: int.parse(s.pathParameters['id'] ?? '0'),
        ),
      ),
      GoRoute(
        path: '/admin/order/new/:id/pick/:itemId',
        builder: (c, s) => OrderCreateItemScreen(
          customerId: int.parse(s.pathParameters['id'] ?? '0'),
          itemId: int.parse(s.pathParameters['itemId'] ?? '0'),
        ),
      ),
      GoRoute(
        path: '/admin/order/new/:id/item/:qr',
        builder: (c, s) => OrderCreateItemScreen(
          customerId: int.parse(s.pathParameters['id'] ?? '0'),
          qr: Uri.decodeComponent(s.pathParameters['qr'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/admin/order/status/:id',
        builder: (c, s) => OrderStatusScreen(
          orderId: int.parse(s.pathParameters['id'] ?? '0'),
        ),
      ),
      GoRoute(
        path: '/admin/order/status/:id/edit',
        builder: (c, s) => OrderEditStubScreen(
          orderId: int.parse(s.pathParameters['id'] ?? '0'),
        ),
      ),
    ],
  );
});