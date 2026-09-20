import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

/// Root widget. Wrapped in [UncontrolledProviderScope] so `main` can hoist
/// [ProviderContainer] for the 401 → logout wiring in `ApiClient`.
class StockFlowApp extends ConsumerWidget {
  const StockFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Stock Flow Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
    );
  }
}