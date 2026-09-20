import 'package:flutter/foundation.dart';

/// DEBUG-ONLY performance instrumentation.
///
/// Every method is a no-op in release builds (all guarded by [kDebugMode]).
/// Used by the Phase-1 measurement pass to timestamp screen loads (TTC) and
/// cache/network events so they can be read from `adb logcat`/test output.
class Perf {
  Perf._();

  static final Map<String, Stopwatch> _sw = {};

  static void start(String tag) {
    if (!kDebugMode) return;
    if (_sw.containsKey(tag)) return;
    _sw[tag] = Stopwatch()..start();
  }

  /// Records elapsed ms since [start] and clears the marker.
  static void end(String tag, String label) {
    if (!kDebugMode) return;
    final w = _sw.remove(tag);
    if (w == null) return;
    debugPrint('[perf] $tag :: $label = ${w.elapsedMilliseconds}ms');
  }

  static void log(String tag, String message) {
    if (!kDebugMode) return;
    debugPrint('[perf] $tag :: $message');
  }
}