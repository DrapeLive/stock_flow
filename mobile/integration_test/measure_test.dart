import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stock_flow_admin/main.dart' as app;
import 'package:stock_flow_admin/shared/admin_shell.dart';

/// Phase-1 measurement harness.
///
/// Drives the REAL app on a device/emulator against the local backend and
/// prints `[MEASURE]` lines (plus the app's own `[perf]` instrumentation) so
/// before/after tables can be produced from a single `adb logcat` / console.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('measure login + tab TTC', (tester) async {
    final swStart = Stopwatch()..start();
    await app.main();
    await tester.pump();

    // Wait for either the login form or the dashboard (persisted session).
    await Future.doWhile(() async {
      await tester.pump(const Duration(milliseconds: 300));
      return find.text('ORDERS').evaluate().isEmpty &&
          find.byType(TextField).evaluate().isEmpty;
    });

    if (find.byType(TextField).evaluate().isNotEmpty) {
      // Fresh install: log in.
      final swLogin = Stopwatch()..start();
      await tester.enterText(
          find.byType(TextField).first, 'kidsadmin@example.com');
      await tester.enterText(find.byType(TextField).at(1), 'password123');
      await tester.tap(find.text('Sign in'));
      await tester.pump();
      await _pumpUntil(tester,
          () => find.text('ORDERS').evaluate().isNotEmpty,
          what: 'dashboard after login');
      debugPrint(
          '[MEASURE] login :: submit-to-dashboard = ${swLogin.elapsedMilliseconds}ms');
      debugPrint(
          '[MEASURE] start :: app-main-to-login-form = ${swStart.elapsedMilliseconds}ms');
    } else {
      debugPrint('[MEASURE] start :: app-main-to-dashboard = ${swStart.elapsedMilliseconds}ms');
    }

    // Orders tab is the landing tab.
    final swLanding = Stopwatch()..start();
    await _pumpUntil(tester, () => _busyCount() == 0,
        what: 'ORDERS content settled');
    swLanding.stop();
    debugPrint(
        '[MEASURE] tab :: ORDERS cold = ${swLanding.elapsedMilliseconds}ms');

    // Cold visits.
    for (final tab in const ['STOCK', 'USERS', 'STATS']) {
      final ms = await _tabTtc(tester, tab);
      debugPrint('[MEASURE] tab :: $tab cold = ${ms}ms');
    }

    // Warm revisit (second mount re-fires initState in this app's flat routes).
    for (final tab in const ['STOCK', 'STATS']) {
      final ms = await _tabTtc(tester, tab);
      debugPrint('[MEASURE] tab :: $tab warm = ${ms}ms');
    }

    // Rapid switching (all four quickly) to expose jank.
    final sw = Stopwatch()..start();
    final steps = <String, int>{};
    for (final tab in const ['USERS', 'STOCK', 'STATS', 'STOCK', 'ORDERS']) {
      final stepSw = Stopwatch()..start();
      await _tapTabGlide(tester, tab);
      stepSw.stop();
      steps[tab] = stepSw.elapsedMilliseconds;
    }
    sw.stop();
    debugPrint(
        '[MEASURE] rapid :: walk=${sw.elapsedMilliseconds}ms steps=$steps');
  });
}

int _busyCount() => find.byType(CircularProgressIndicator).evaluate().length;

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition,
    {Duration timeout = const Duration(seconds: 30), String what = 'condition'}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (condition()) return;
  }
  throw StateError('Timed out waiting for $what');
}

/// Time from tapping a bottom-nav tab until its screen finished loading.
Future<int> _tabTtc(WidgetTester tester, String label) async {
  final sw = Stopwatch()..start();
  Finder navLabel() => find.descendant(
      of: find.byType(AdminNavBar), matching: find.text(label));
  await _pumpUntil(tester, () => navLabel().evaluate().isNotEmpty,
      timeout: const Duration(seconds: 10), what: 'nav label $label');
  await tester.tap(navLabel());
  await tester.pump();
  await _pumpUntil(tester, () {
    final onTab = navLabel().evaluate().isNotEmpty;
    return onTab && _busyCount() == 0;
  }, what: '$label content');
  sw.stop();
  return sw.elapsedMilliseconds;
}

/// Tap a bottom-nav tab, waiting (fast) for it to be present so rapid walks
/// don't crash on the mid-transition frame where the nav bar is gone.
Future<void> _tapTabGlide(WidgetTester tester, String label) async {
  Finder navLabel() => find.descendant(
      of: find.byType(AdminNavBar), matching: find.text(label));
  await _pumpUntil(tester, () => navLabel().evaluate().isNotEmpty,
      timeout: const Duration(seconds: 10), what: 'nav label $label');
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tap(navLabel());
  await tester.pump(const Duration(milliseconds: 80));
}