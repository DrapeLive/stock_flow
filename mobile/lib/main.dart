import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/api/api_client.dart';
import 'core/cache/app_cache.dart';
import 'core/notifications/push_service.dart';
import 'core/router/app_router.dart';
import 'providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppCache.init();
  ApiClient.init();

  // Hoist a container so the static 401 hook can reach the session notifier.
  final container = ProviderContainer();
  ApiClient.onUnauthorized = () {
    container.read(sessionProvider.notifier).logout();
  };

  // Best-effort push wiring; no-ops when Firebase isn't configured yet.
  PushService.instance.onOpen = (data) {
    final router = container.read(routerProvider);
    final route = routeForPush(data);
    // Defer until the router is attached so cold-start taps (getInitialMessage)
    // navigate reliably. Order deep-links are pushed on top of the current
    // stack so the system back button returns to the dashboard instead of
    // exiting the app; `/admin` resets to the dashboard root.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route == '/admin') {
        router.go('/admin');
      } else {
        router.push(route);
      }
    });
  };
  unawaited(PushService.instance.init());

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const StockFlowApp(),
    ),
  );
}