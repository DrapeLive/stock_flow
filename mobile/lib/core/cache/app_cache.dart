import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:hive_ce/hive.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/perf.dart';

/// Hive-backed cache replicating the web app's client-side "don't refetch every
/// time" behaviour (module-level size-range cache, sessionStorage filters,
/// viewed-order-ids, transport/brand/customer lists).
///
/// Boxes:
///  - `session` — auth tokens + user (equivalent of the JS cookies)
///  - `prefs`   — persisted UI state (dashboard tab/filters, viewed order ids)
///  - `cache`   — TTL JSON cache keyed by `namespace::key`
class AppCache {
  AppCache._();

  static const String sessionBoxName = 'session';
  static const String prefsBoxName = 'prefs';
  static const String cacheBoxName = 'cache';
  static const String itemSyncBoxName = 'itemSync';

  static late Box<dynamic> sessionBox;
  static late Box<dynamic> prefsBox;
  static late Box<dynamic> cacheBox;
  static late Box<dynamic> itemSyncBox;

  /// On-disk image cache used by every [CachedNetworkImage] in the app.
  ///
  /// Overrides the library default (only ~100 files / 30-day retention) so
  /// product photos stay local across restarts and are not refetched on
  /// revisits. Bounded by a 2000-file LRU cap, images expire after a year.
  /// Wiped on logout for privacy.
  static final CacheManager imageCacheManager = CacheManager(
    Config(
      'app_images',
      stalePeriod: const Duration(days: 365),
      maxNrOfCacheObjects: 2000,
    ),
  );

  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    Hive.init(dir.path);
    sessionBox = await Hive.openBox(sessionBoxName);
    prefsBox = await Hive.openBox(prefsBoxName);
    cacheBox = await Hive.openBox(cacheBoxName);
    itemSyncBox = await Hive.openBox(itemSyncBoxName);
  }

  // -- session ------------------------------------------------------------

  static void sessionPut(String key, dynamic value) => sessionBox.put(key, value);

  static dynamic sessionGet(String key) => sessionBox.get(key);

  static Future<void> clearSession() async => sessionBox.clear();

  // -- item sync store ------------------------------------------------------
  //
  // Persisted inventory mirror used by the Stock screen. Items live under
  // `i:<id>` raw JSON keys; sync bookkeeping under `meta`. Cleared on logout
  // so one user's business never leaks into the next session.

  static clearItemSync() {
    itemSyncBox.clear();
    itemSyncBox.put(
      'meta',
      {'schema': 0, 'cursor': null, 'lastFullSync': null, 'archiveAfterDays': 30},
    );
  }

  // -- prefs --------------------------------------------------------------

  static Box<dynamic> get prefs => prefsBox;

  static String pref(String key, [String fallback = '']) =>
      (prefsBox.get(key) ?? fallback).toString();

  static void setPref(String key, String value) => prefsBox.put(key, value);

  static bool prefBool(String key, [bool fallback = false]) =>
      prefsBox.get(key, defaultValue: fallback) as bool;

  static void setPrefBool(String key, bool value) => prefsBox.put(key, value);

  static dynamic prefJson(String key) => prefsBox.get(key);

  static void setPrefJson(String key, dynamic value) => prefsBox.put(key, value);

  static void removePref(String key) => prefsBox.delete(key);

  // -- cache --------------------------------------------------------------

  static String _key(String namespace, String key) => '$namespace::$key';

  static Future<dynamic> read(String namespace, String key) async {
    final entry = cacheBox.get(_key(namespace, key));
    if (entry == null) return null;
    try {
      return jsonDecode(jsonEncode(entry['data']));
    } catch (_) {
      return entry['data'];
    }
  }

  static Future<void> write(String namespace, String key, dynamic data) async {
    await cacheBox.put(_key(namespace, key), {'data': data, 'savedAt': DateTime.now().millisecondsSinceEpoch});
    await _evictOldest(namespace);
  }

  /// Keeps any namespace (e.g. per-filter orders or per-search customers) from
  /// growing the Hive box without bound by dropping the oldest entries.
  static const int maxKeysPerNamespace = 30;

  static Future<void> _evictOldest(String namespace) async {
    final prefix = '$namespace::';
    final keys = cacheBox.keys
        .where((k) => k.toString().startsWith(prefix))
        .toList();
    if (keys.length <= maxKeysPerNamespace) return;
    final savedAtByKey = <String, int>{};
    for (final k in keys) {
      final entry = cacheBox.get(k);
      savedAtByKey[k.toString()] =
          entry is Map ? (entry['savedAt'] as num?)?.toInt() ?? 0 : 0;
    }
    final sorted =
        savedAtByKey.keys.toList()..sort((a, b) => savedAtByKey[a]!.compareTo(savedAtByKey[b]!));
    while (sorted.length > maxKeysPerNamespace) {
      final oldest = sorted.removeAt(0);
      await cacheBox.delete(oldest);
    }
  }

  static int? savedAt(String namespace, String key) {
    final entry = cacheBox.get(_key(namespace, key));
    if (entry == null) return null;
    return (entry['savedAt'] as num?)?.toInt();
  }

  /// Returns the cached value if it is younger than [ttl], otherwise runs
  /// [fetch] and stores the result. Falls back to a stale cached value when
  /// the network call fails.
  static Future<dynamic> staleWhileRevalidate(
    String namespace,
    String key,
    Future<dynamic> Function() fetch, {
    required Duration ttl,
  }) async {
    final ts = savedAt(namespace, key);
    final fresh = ts != null &&
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ts)) < ttl;
    final cached = await read(namespace, key);
    if (fresh && cached != null) {
      _cacheLog('HIT', namespace, key);
      return cached;
    }
    if (cached != null) {
      _cacheLog('STALE-REVALIDATE', namespace, key);
    } else {
      _cacheLog('MISS', namespace, key);
    }
    try {
      final data = await fetch();
      await write(namespace, key, data);
      return data;
    } catch (_) {
      if (cached != null) {
        _cacheLog('FALLBACK-ON-ERROR', namespace, key);
        return cached;
      }
      rethrow;
    }
  }

  /// Always hits the network (live data), falling back to the last-known cache
  /// on failure so the app stays browsable offline.
  static Future<dynamic> networkFirst(
    String namespace,
    String key,
    Future<dynamic> Function() fetch,
  ) async {
    try {
      final data = await fetch();
      await write(namespace, key, data);
      return data;
    } catch (_) {
      final cached = await read(namespace, key);
      if (cached != null) {
        _cacheLog('FALLBACK-ON-ERROR', namespace, key);
        return cached;
      }
      rethrow;
    }
  }

  static void _cacheLog(String kind, String namespace, String key) {
    if (!Perf.enabled) return;
    debugPrint('[perf] CACHE $kind $namespace::$key');
  }

  static Future<void> invalidate(String namespace) async {
    final prefix = '$namespace::';
    final keys = cacheBox.keys
        .where((k) => k.toString().startsWith(prefix))
        .toList();
    for (final k in keys) {
      await cacheBox.delete(k);
    }
  }

  static Future<void> clearAll() async {
    await cacheBox.clear();
    await prefsBox.clear();
  }
}