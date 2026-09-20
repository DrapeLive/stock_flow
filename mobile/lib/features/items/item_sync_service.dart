import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

import '../../core/api/api_client.dart';
import '../../data/item_store.dart';
import '../../models/models.dart';

/// Orchestrates incremental inventory sync into [ItemStore].
///
/// Contract:
/// - Bootstrap download of `/api/items/sync/` pages, rendered as they land.
/// - Delta syncs keyed by the server cursor, with a 30s overlap so overlaps
///   are idempotently replayed and no change is missed between rounds.
/// - The server's `check` fingerprint is compared to the local store; on
///   mismatch a full reconcile is scheduled, rate-limited to once/60s.
/// - Single-flight: only one network round runs at a time; a `force` request
///   during a round is remembered and replayed after it finishes.
/// - `force` (pull-to-refresh, own writes) bypasses the 10s min interval.
/// - Network failure keeps the store intact; the reason is surfaced to the
///   screen via [lastError].
class ItemSyncService with WidgetsBindingObserver {
  ItemSyncService._();

  static final ItemSyncService instance = ItemSyncService._();

  static const Duration minInterval = Duration(seconds: 10);
  static const Duration overlapWindow = Duration(seconds: 30);
  static const Duration reconcileDelay = Duration(seconds: 60);

  /// Bumped on every store mutation so screens can rebuild.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Timestamp of the last successful sync.
  final ValueNotifier<DateTime?> lastSynced = ValueNotifier<DateTime?>(null);

  /// True while a sync round is in flight.
  final ValueNotifier<bool> syncing = ValueNotifier<bool>(false);

  /// Human-readable reason for the last sync failure (null when healthy).
  final ValueNotifier<String?> lastError = ValueNotifier<String?>(null);

  DateTime? _lastRun;
  Completer<void>? _inFlight;
  bool _pending = false;
  bool _pendingForce = false;
  DateTime? _reconcileAt;

  bool _attached = false;

  /// Registers the app-lifecycle observer so resuming re-syncs in the
  /// background. Safe to call repeatedly.
  void attach() {
    if (_attached) return;
    _attached = true;
    WidgetsBinding.instance.addObserver(this);
  }

  void detach() {
    if (!_attached) return;
    _attached = false;
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      trigger();
    }
  }

  /// Starts a sync round. Never throws; failures land in [lastError].
  Future<void> trigger({bool force = false}) async {
    final inFlight = _inFlight;
    if (inFlight != null) {
      if (force) {
        _pending = true;
        _pendingForce = true;
      }
      return inFlight.future;
    }
    final now = DateTime.now();
    if (!force && _lastRun != null && now.difference(_lastRun!) < minInterval) {
      return;
    }
    _lastRun = now;
    syncing.value = true;
    lastError.value = null;
    final completer = Completer<void>();
    _inFlight = completer;
    try {
      await _run(now, force: force);
      completer.complete();
    } catch (e) {
      _handleFailure(e);
      completer.complete();
    } finally {
      _inFlight = null;
      syncing.value = false;
    }
    if (_pending) {
      final wasForce = _pendingForce;
      _pending = false;
      _pendingForce = false;
      await trigger(force: wasForce);
    }
  }

  Future<void> _run(DateTime started, {required bool force}) async {
    final store = ItemStore.instance;
    final reconcileDue = _reconcileAt != null && started.isAfter(_reconcileAt!);
    if (reconcileDue) _reconcileAt = null;

    if (!store.hasBootstrapped || reconcileDue) {
      await _bootstrap();
    } else {
      final cursor = store.cursor;
      if (cursor == null) {
        await _bootstrap();
        return;
      }
      await _delta(store, _overlap(cursor));
    }
    lastSynced.value = DateTime.now();
  }

  /// Full download, applied page by page so partial results are already
  /// renderable. Ends with a verify round that double-checks the store.
  Future<void> _bootstrap() async {
    final store = ItemStore.instance;
    store.clearStore();
    revision.value++;
    var page = 1;
    String? cursor;
    int? archiveAfterDays;
    while (true) {
      final res = await ApiClient.dio.get<Map<String, dynamic>>(
        '/api/items/sync/',
        queryParameters: {'page': page, 'page_size': ItemStore.pageSize},
      );
      final data = res.data ?? <String, dynamic>{};
      cursor = s(data['cursor'], '').isEmpty ? null : s(data['cursor']);
      archiveAfterDays = (data['archive_after_days'] as num?)?.toInt();
      store.adoptServerTime(s(data['server_time'], ''));
      final items = data['items'] as List? ?? const [];
      final changed =
          store.upsertItems(items.map((e) => (e as Map).cast<String, dynamic>()));
      if (changed > 0) revision.value++;
      final next = data['next_page'];
      if (items.isEmpty || next == null) break;
      page = (next as num).toInt();
    }
    store.commitBootstrap(cursor: cursor, archiveAfterDays: archiveAfterDays);
    revision.value++;
    if (cursor != null) {
      await _delta(store, cursor); // verifies via server `check`
    }
  }

  /// Applies item/stock/removed deltas, saves the new cursor and verifies the
  /// local store against the server `check`. Returns whether it matched.
  Future<bool> _delta(ItemStore store, String since) async {
    final res = await ApiClient.dio.get<Map<String, dynamic>>(
      '/api/items/sync/',
      queryParameters: {'since': since},
    );
    final data = res.data ?? <String, dynamic>{};
    if (s(data['mode'], 'delta') == 'full') {
      await _bootstrap();
      return true;
    }
    final cursor = s(data['cursor'], '').isEmpty ? null : s(data['cursor']);
    final archiveAfterDays = (data['archive_after_days'] as num?)?.toInt();
    store.adoptServerTime(s(data['server_time'], ''));

    final changed = store.upsertItems((data['items'] as List? ?? const [])
        .map((e) => (e as Map).cast<String, dynamic>()));
    if (changed > 0) revision.value++;

    final applied =
        store.applyStockRows((data['stock'] as List?)?.cast<dynamic>() ?? const []);
    if (applied > 0) revision.value++;

    final removed = store.removeItems(data['removed_item_ids'] as List? ?? const []);
    if (removed > 0) revision.value++;

    store.commitDelta(cursor: cursor, archiveAfterDays: archiveAfterDays);

    final check = (data['check'] as Map?) ?? const <String, dynamic>{};
    final expected = (
      items: asInt(check['items']) ?? -1,
      totalStock: asInt(check['total_stock']) ?? -1,
    );
    final local = store.check();
    final ok = expected.items >= 0 && expected == local;
    if (!ok) _scheduleReconcile();
    return ok;
  }

  void _scheduleReconcile() {
    if (_reconcileAt != null) return;
    _reconcileAt = DateTime.now().add(reconcileDelay);
  }

  String _overlap(String cursor) {
    final t = DateTime.tryParse(cursor);
    final base = t?.toUtc() ?? DateTime.now().toUtc();
    return base.subtract(overlapWindow).toIso8601String();
  }

  void _handleFailure(Object e) {
    final offline = e is DioException &&
        e.response == null &&
        {
          DioExceptionType.connectionTimeout,
          DioExceptionType.sendTimeout,
          DioExceptionType.receiveTimeout,
          DioExceptionType.connectionError,
          DioExceptionType.unknown,
        }.contains(e.type);
    lastError.value =
        offline ? "Couldn't sync. You're offline." : "Couldn't sync. Retry.";
  }
}