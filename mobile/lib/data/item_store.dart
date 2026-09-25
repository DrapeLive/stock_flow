/// Hive-persisted inventory mirror backing the Stock screen.
///
/// The server's `GET /api/items/sync/` payload is projected into this store:
/// each item is kept as a raw JSON map under the box key `i:<id>` and sync
/// bookkeeping under `meta`. Pure helpers (`ItemSyncData`) live here without any
/// Flutter/Hive dependency so they can be unit-tested in isolation.
library;

import 'package:hive_ce/hive.dart' show Box;

import '../core/cache/app_cache.dart';
import '../models/models.dart';

const int kItemSyncSchema = 1;
const String kItemSyncKeyPrefix = 'i:';
const String kItemSyncMetaKey = 'meta';

/// Pure data transforms over the raw sync maps. No I/O, no dependencies.
abstract final class ItemSyncData {
  /// Returns `true` when [incoming] must replace the stored [existing] item
  /// (missing locally, or its `rev`/catalog timestamp changed).
  static bool shouldUpsert(Map<String, dynamic>? existing, Map<String, dynamic> incoming) =>
      existing == null || existing['rev'] != incoming['rev'];

  /// Server-clock offset in milliseconds (`server_now - device_now`) so the
  /// archive rule never depends on the device's wall clock.
  static int computeServerOffsetMs(String? serverTimeIso, DateTime deviceNow) {
    if (serverTimeIso == null) return 0;
    final t = DateTime.tryParse(serverTimeIso);
    if (t == null) return 0;
    return t.toUtc().difference(deviceNow.toUtc()).inMilliseconds;
  }

  /// Offset-corrected "now" in absolute time (UTC-normalised pair).
  static DateTime correctedNow(int serverOffsetMs, DateTime deviceNow) =>
      deviceNow.add(Duration(milliseconds: serverOffsetMs));

  /// Archive boundary evaluated against [now] (already offset-corrected).
  static DateTime archiveCutoff(DateTime now, int? archiveAfterDays) =>
      now.subtract(Duration(days: archiveAfterDays ?? 0));

  /// Applies one stock row delta `{id, size, stock}` to [items] (list of raw
  /// item maps), mutating in place. Returns true when the row was found.
  static bool applyStockRow(List<Map<String, dynamic>> items, Map<String, dynamic> row) {
    final rowId = asInt(row['id']);
    final size = s(row['size']);
    final stock = asInt(row['stock']) ?? 0;
    for (final item in items) {
      for (final v in asList(item['variants'], (m) => m)) {
        for (final sz in asList(v['sizes'], (m) => m)) {
          if (asInt(sz['id']) == rowId) {
            sz['stock'] = stock;
            sz['size'] = size;
            return true;
          }
        }
      }
    }
    return false;
  }

  /// Local integrity check: active items + total stock, applying the same
  /// archive rule as the server (drop items whose `out_of_stock_since` is
  /// older than [archiveAfterDays]).
  ///
  /// [now] is the offset-corrected device time; [deviceNow] is only consulted
  /// through [now] so callers can pass a fixed clock in tests.
  static ({int items, int totalStock}) check(
      List<Map<String, dynamic>> items, int? archiveAfterDays,
      {DateTime? now}) {
    final clock = now ?? DateTime.now();
    final cutoff = archiveAfterDays == null
        ? null
        : archiveCutoff(clock, archiveAfterDays);
    var count = 0;
    var total = 0;
    for (final item in items) {
      final oos = item['out_of_stock_since'] as String?;
      if (oos != null && cutoff != null) {
        final t = DateTime.tryParse(oos);
        if (t != null && t.isBefore(cutoff)) continue;
      }
      count++;
      for (final v in asList(item['variants'], (m) => m)) {
        for (final sz in asList(v['sizes'], (m) => m)) {
          total += asInt(sz['stock']) ?? 0;
        }
      }
    }
    return (items: count, totalStock: total);
  }

  /// Projects raw sync item maps into the stock-list shape the Stock screen
  /// renders (variant sizes use the `size` column as the display range).
  ///
  /// Items are ordered newest-first (`id` descending) to match the web stock
  /// list, which the backend serves with `order_by("-id")`.
  static List<ItemStockEntry> toEntries(List<Map<String, dynamic>> items) {
    final sorted = [...items]..sort((a, b) {
        final ia = asInt(a['id']) ?? 0;
        final ib = asInt(b['id']) ?? 0;
        return ib.compareTo(ia);
      });
    return [
      for (final item in sorted)
        ItemStockEntry(
          id: asInt(item['id']) ?? 0,
          name: s(item['name']),
          type: item['type'] as String?,
          price: s(item['price']),
          image: item['thumb'] as String?,
          variants: asList(
            item['variants'],
            (v) => ItemVariantQR(
              id: asInt(v['id']) ?? 0,
              qrCode: v['qr_code'] as String?,
              image: v['image'] as String?,
              sizes: asList(
                v['sizes'],
                (sz) => VariantSize(sizeRange: s(sz['size']), stock: asInt(sz['stock']) ?? 0),
              ),
              totalStock: asList(v['sizes'], (sz) => sz).fold(
                  0, (sum, sz) => sum + (asInt(sz['stock']) ?? 0)),
              displayOrder: v['display_order'] as String?,
            ),
          ),
        ),
    ];
  }
}

/// Box-backed facade over [AppCache.itemSyncBox].
class ItemStore {
  ItemStore._();

  static final ItemStore instance = ItemStore._();

  static const int pageSize = 100;

  Box<dynamic> get _box => AppCache.itemSyncBox;

  Map<String, dynamic> _meta() =>
      (_box.get(kItemSyncMetaKey) as Map?)?.cast<String, dynamic>() ??
      <String, dynamic>{};

  bool get hasBootstrapped => (_meta()['lastFullSync'] as String?)?.isNotEmpty ?? false;

  String? get cursor => s(_meta()['cursor'], '').isEmpty ? null : s(_meta()['cursor']);

  int? get archiveAfterDays => (_meta()['archiveAfterDays'] as num?)?.toInt();

  /// Persisted `server_now - device_now` offset in milliseconds (0 when the
  /// server clock has never been observed or the last clear reset it).
  int get serverTimeOffsetMs => (_meta()['serverTimeOffsetMs'] as num?)?.toInt() ?? 0;

  /// Offset-corrected device "now", used for the archive rule.
  DateTime get correctedNow =>
      ItemSyncData.correctedNow(serverTimeOffsetMs, DateTime.now());

  int get schema => (_meta()['schema'] as num?)?.toInt() ?? 0;

  List<String> get _itemKeys => _box.keys
      .where((k) => k.toString().startsWith(kItemSyncKeyPrefix))
      .map((k) => k.toString())
      .toList();

  /// Reads every stored raw item map (unused Hive entries are skipped).
  List<Map<String, dynamic>> storedItems() => [
        for (final k in _itemKeys)
          if ((_box.get(k) as Map?) != null) (_box.get(k) as Map).cast<String, dynamic>(),
      ];

  ItemStore _persistMeta(Map<String, dynamic> next) {
    _box.put(kItemSyncMetaKey, next);
    return this;
  }

  /// Drops all items and resets bookkeeping (fresh bootstraps, forced syncs,
  /// logout).
  void clearStore() {
    for (final k in _itemKeys) {
      _box.delete(k);
    }
    _persistMeta({
      'schema': kItemSyncSchema,
      'cursor': null,
      'lastFullSync': null,
      'archiveAfterDays': archiveAfterDays,
      'serverTimeOffsetMs': 0,
    });
  }

  /// Records the server-clock offset observed at [receivedAt] (defaults to
  /// now) so archive checks use the server's time, never the device's.
  /// Accepts the raw ISO `server_time` from a sync response.
  void adoptServerTime(String? serverTimeIso, {DateTime? receivedAt}) {
    final offset = ItemSyncData.computeServerOffsetMs(
        serverTimeIso, receivedAt ?? DateTime.now());
    if (offset == 0 && serverTimeIso == null) return;
    final meta = _meta();
    meta['serverTimeOffsetMs'] = offset;
    _persistMeta(meta);
  }

  /// Upserts items whose `rev` differs from the stored copy (or that are new).
  /// Returns the number actually changed.
  int upsertItems(Iterable<Map<String, dynamic>> incoming) {
    var changed = 0;
    for (final raw in incoming) {
      final id = asInt(raw['id']);
      if (id == null) continue;
      final existing = _box.get('$kItemSyncKeyPrefix$id') as Map?;
      final existingMap = existing?.cast<String, dynamic>();
      if (ItemSyncData.shouldUpsert(existingMap, raw)) {
        _box.put('$kItemSyncKeyPrefix$id', raw);
        changed++;
      }
    }
    return changed;
  }

  /// Applies a batch of stock rows `[{id, size, stock}, ...]`. Rows whose item
  /// is not in the store are ignored (a new item arrives as a full upsert).
  int applyStockRows(List<dynamic> rows) {
    if (rows.isEmpty) return 0;
    final items = storedItems();
    var applied = 0;
    for (final r in rows) {
      if (ItemSyncData.applyStockRow(items, (r as Map).cast<String, dynamic>())) {
        applied++;
      }
    }
    for (final item in items) {
      final id = asInt(item['id']);
      if (id != null) _box.put('$kItemSyncKeyPrefix$id', item);
    }
    return applied;
  }

  int removeItems(List<dynamic> ids) {
    var removed = 0;
    for (final id in ids) {
      final key = '$kItemSyncKeyPrefix${asInt(id)}';
      if (_box.containsKey(key)) {
        _box.delete(key);
        removed++;
      }
    }
    return removed;
  }

  void commitBootstrap({required String? cursor, required int? archiveAfterDays}) {
    final meta = _meta();
    meta['schema'] = kItemSyncSchema;
    meta['lastFullSync'] = DateTime.now().toUtc().toIso8601String();
    meta['cursor'] = cursor;
    meta['archiveAfterDays'] = archiveAfterDays;
    _persistMeta(meta);
  }

  void commitDelta({required String? cursor, required int? archiveAfterDays}) {
    final meta = _meta();
    meta['cursor'] = cursor;
    meta['archiveAfterDays'] = archiveAfterDays;
    _persistMeta(meta);
  }

  /// The exact projection the Stock screen consumes.
  List<ItemStockEntry> entries() => ItemSyncData.toEntries(storedItems());

  /// Local integrity check for the current archive policy (uses the
  /// offset-corrected server clock).
  ({int items, int totalStock}) check() =>
      ItemSyncData.check(storedItems(), archiveAfterDays, now: correctedNow);
}