import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/api/api_client.dart';
import 'core/cache/app_cache.dart';
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

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const StockFlowApp(),
    ),
  );
}