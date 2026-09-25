import 'package:flutter/foundation.dart';

/// Performance instrumentation.
///
/// Active in debug builds; additionally active in release builds compiled with
/// `--dart-define=PERF_LOG=true` (Phase-1 measurement against production).
/// Timestamps screen loads (TTC) and cache/network events for `adb logcat`.
class Perf {
  Perf._();

  static const bool _releaseEnabled = bool.fromEnvironment('PERF_LOG');

  static bool get enabled => kDebugMode || _releaseEnabled;

  static final Map<String, Stopwatch> _sw = {};

  static void start(String tag) {
    if (!enabled) return;
    if (_sw.containsKey(tag)) return;
    _sw[tag] = Stopwatch()..start();
  }

  /// Records elapsed ms since [start] and clears the marker.
  static void end(String tag, String label) {
    if (!enabled) return;
    final w = _sw.remove(tag);
    if (w == null) return;
    debugPrint('[perf] $tag :: $label = ${w.elapsedMilliseconds}ms');
  }

  static void log(String tag, String message) {
    if (!enabled) return;
    debugPrint('[perf] $tag :: $message');
  }
}