import 'package:flutter_test/flutter_test.dart';

import 'package:stock_flow_admin/data/item_store.dart';
import 'package:stock_flow_admin/models/models.dart';

import 'helpers.dart';

Map<String, dynamic> sizeRow(int id, String size, int stock) =>
    {'id': id, 'size': size, 'stock': stock};

Map<String, dynamic> variant(
        int id, List<Map<String, dynamic>> sizes,
        {String? qr, String? order}) =>
    {'id': id, 'qr_code': qr, 'display_order': order, 'sizes': sizes};

Map<String, dynamic> item(int id, String name, List<Map<String, dynamic>> variants,
        {String rev = 'r1', String? oos}) =>
    {
      'id': id,
      'rev': rev,
      'name': name,
      'price': '300.00',
      'type': 'kids',
      'thumb': 'http://host/media/$id.jpg',
      'out_of_stock_since': oos,
      'variants': variants,
    };

void main() {
  group('ItemSyncData.shouldUpsert', () {
    test('inserts when missing locally', () {
      expect(ItemSyncData.shouldUpsert(null, item(1, 'Shirt', [])), isTrue);
    });

    test('skips when rev unchanged', () {
      final existing = item(1, 'Shirt', [], rev: 'r1');
      expect(
        ItemSyncData.shouldUpsert(
            existing, item(1, 'Shirt', [], rev: 'r1')),
        isFalse,
      );
    });

    test('replaces when rev changed (catalog edit)', () {
      final existing = item(1, 'Shirt', [], rev: 'r1');
      expect(
        ItemSyncData.shouldUpsert(
            existing, item(1, 'Shirt—edited', [], rev: 'r2')),
        isTrue,
      );
    });
  });

  group('ItemSyncData.applyStockRow', () {
    test('updates the matching size row in place', () {
      final items = [
        item(1, 'A', [variant(10, [sizeRow(100, 'S', 2)])]),
        item(2, 'B', [variant(20, [sizeRow(200, 'M', 5), sizeRow(201, 'L', 0)])]),
      ];
      final found =
          ItemSyncData.applyStockRow(items, {'id': 201, 'size': 'L', 'stock': 12});
      expect(found, isTrue);
      expect(items[1]['variants'][0]['sizes'][1]['stock'], 12);
    });

    test('ignores rows whose item is not stored', () {
      final items = [item(1, 'A', [variant(10, [sizeRow(100, 'S', 2)])])];
      expect(ItemSyncData.applyStockRow(items, {'id': 999, 'size': 'X', 'stock': 0}),
          isFalse);
    });
  });

  group('ItemSyncData.check', () {
    test('counts items and total stock of the active set', () {
      final items = [
        item(1, 'A', [variant(10, [sizeRow(100, 'S', 2), sizeRow(101, 'M', 3)])]),
        item(2, 'B', [variant(20, [sizeRow(200, 'L', 5)])]),
      ];
      expect(ItemSyncData.check(items, 30), (items: 2, totalStock: 10));
    });

    test('drops items archived by the local rule (out_of_stock_since > N days)',
        () {
      final archive = DateTime.now()
          .toUtc()
          .subtract(const Duration(days: 40))
          .toIso8601String();
      final fresh = DateTime.now()
          .toUtc()
          .subtract(const Duration(days: 5))
          .toIso8601String();
      final items = [
        item(1, 'Archived', [variant(10, [sizeRow(100, 'S', 4)])], oos: archive),
        item(2, 'Recent', [variant(20, [sizeRow(200, 'M', 6)])], oos: fresh),
        item(3, 'Never-out', [variant(30, [sizeRow(300, 'L', 7)])]),
      ];
      expect(ItemSyncData.check(items, 30), (items: 2, totalStock: 13));
    });

    test('counts everything when no archive policy is known', () {
      final items = [item(1, 'A', [variant(10, [sizeRow(100, 'S', 4)])])];
      expect(ItemSyncData.check(items, null), (items: 1, totalStock: 4));
    });
  });

  group('ItemSyncData.computeServerOffsetMs / correctedNow', () {
    test('computes zero offset from UTC server time', () {
      final server = DateTime.utc(2026, 9, 20, 12);
      expect(
        ItemSyncData.computeServerOffsetMs(server.toIso8601String(), server),
        0,
      );
    });

    test('recovers server time for a device clock 1 day ahead', () {
      final server = DateTime.utc(2026, 9, 20, 12);
      final device = server.add(const Duration(days: 1));
      final offset = ItemSyncData.computeServerOffsetMs(
          server.toIso8601String(), device);
      expect(offset, -const Duration(days: 1).inMilliseconds);
      expect(ItemSyncData.correctedNow(offset, device).toUtc(), server);
    });

    test('recovers server time for a device clock 1 day behind', () {
      final server = DateTime.utc(2026, 9, 20, 12);
      final device = server.subtract(const Duration(days: 1));
      final offset = ItemSyncData.computeServerOffsetMs(
          server.toIso8601String(), device);
      expect(offset, const Duration(days: 1).inMilliseconds);
      expect(ItemSyncData.correctedNow(offset, device).toUtc(), server);
    });

    test('accommodates devices in non-UTC timezones', () {
      final server = DateTime.utc(2026, 9, 20, 12);
      final serverIso = server.toIso8601String();
      // A +05:30 device with an accurate clock reports its local wall time,
      // so the offset is effectively zero.
      final deviceUtc = server;
      final offset = ItemSyncData.computeServerOffsetMs(serverIso, deviceUtc);
      expect(offset, 0);
      // …and a skew of a few hours on top is recovered too.
      final skewed = server.add(const Duration(hours: 2, minutes: 30));
      final skewedOffset =
          ItemSyncData.computeServerOffsetMs(serverIso, skewed);
      expect(ItemSyncData.correctedNow(skewedOffset, skewed).toUtc(), server);
    });

    test('is a no-op when the server_time is missing or malformed', () {
      expect(ItemSyncData.computeServerOffsetMs(null, DateTime.now()), 0);
      expect(ItemSyncData.computeServerOffsetMs('not-a-date', DateTime.now()),
          0);
    });
  });

  group('ItemSyncData.check against a skewed device clock', () {
    // The server flags an item as out-of-stock at serverNow - 29 days. With an
    // archival policy of 30 days it must remain active on that exact boundary.
    Map<String, dynamic> oosItem(int id, String iso) =>
        item(id, 'A$id', [variant(100 + id, [sizeRow(1000 + id, 'S', 1)])],
            oos: iso);

    test('parity is restored for +/-, 1-day and timezone skews', () {
      final server = DateTime.utc(2026, 9, 20, 12);
      const days = 30;
      final oos = server.subtract(const Duration(days: 29)).toIso8601String();
      final items = [
        oosItem(1, oos),
        item(2, 'A2', [variant(102, [sizeRow(1002, 'S', 1)])]),
      ];

      final expected = ItemSyncData.check(items, days, now: server);
      expect(expected.totalStock, 2);

      for (final skew in [
        server.add(const Duration(days: 1)), // device clock 1 day ahead
        server.subtract(const Duration(days: 1)), // …and behind
        server.add(const Duration(hours: 5, minutes: 30)), // tz-style skew
      ]) {
        final offset = ItemSyncData.computeServerOffsetMs(
            server.toIso8601String(), skew);
        final corrected =
            ItemSyncData.correctedNow(offset, skew);
        expect(ItemSyncData.check(items, days, now: corrected), expected);
      }
    });

    test('a naive device clock alone would drive a mismatch loop', () {
      final server = DateTime.utc(2026, 9, 20, 12);
      final device = server.add(const Duration(days: 1)); // clock ahead
      // OOS 29.5 days before server now; the naive device (cutoff -29 days)
      // drops it, while the server (cutoff -30 days) keeps it.
      final oos = server
          .subtract(const Duration(days: 29, hours: 12))
          .toIso8601String();
      final items = [oosItem(1, oos)];

      final serverTruth = ItemSyncData.check(items, 30, now: server);
      expect(serverTruth.items, 1);
      final naive = ItemSyncData.check(items, 30, now: device);
      expect(naive.items, 0);

      final offset = ItemSyncData.computeServerOffsetMs(
          server.toIso8601String(), device);
      expect(
        ItemSyncData.check(items, 30,
            now: ItemSyncData.correctedNow(offset, device)),
        serverTruth,
      );
    });

    test('archiveCutoff follows the supplied clock', () {
      final server = DateTime.utc(2026, 9, 20, 12);
      expect(ItemSyncData.archiveCutoff(server, 30),
          server.subtract(const Duration(days: 30)));
      expect(ItemSyncData.archiveCutoff(server, null), server);
    });
  });

  group('ItemSyncData.toEntries', () {
    test('projects sync maps into the stock-screen shape', () {
      final items = [
        item(2, 'B', [
          variant(21, [sizeRow(211, 'S', 2), sizeRow(212, 'M', 3)],
              qr: 'QR-B', order: '2')
        ], rev: 'r2'),
        item(1, 'A', [
          variant(11, [sizeRow(111, 'L', 5)], qr: 'QR-A', order: '1')
        ], rev: 'r1'),
      ];
      final entries = ItemSyncData.toEntries(items);

      expect(entries, hasLength(2));
      // Newest first, matching the web stock list (`order_by("-id")`).
      expect(entries.map((e) => e.id), [2, 1]);
      expect(entries[1].name, 'A');
      expect(entries[1].image, 'http://host/media/1.jpg');
      expect(entries[1].variants.single.displayOrder, '1');
      expect(entries[1].variants.single.qrCode, 'QR-A');
      expect(entries[1].variants.single.totalStock, 5);

      final b = entries[0];
      expect(b.name, 'B');
      expect(b.variants, hasLength(1));
      expect(b.variants.first.sizes, hasLength(2));
      expect(b.variants.first.sizes.first.sizeRange, 'S');
      expect(b.variants.first.sizes.first.stock, 2);
      expect(b.totalStock, 5);
    });

    test('orders newest-first regardless of arrival order', () {
      final ascending = [
        item(1, 'A', []),
        item(2, 'B', []),
        item(3, 'C', []),
      ];
      final shuffled = [
        item(3, 'C', []),
        item(1, 'A', []),
        item(2, 'B', []),
      ];

      expect(
        ItemSyncData.toEntries(ascending).map((e) => e.id).toList(),
        [3, 2, 1],
      );
      expect(
        ItemSyncData.toEntries(shuffled).map((e) => e.id).toList(),
        [3, 2, 1],
      );
    });

    test('values mirror the sync item fields', () {
      final entry = ItemSyncData.toEntries([
        item(7, 'Kurti', [
          variant(70, [sizeRow(701, 'S', 0), sizeRow(702, 'L', 0)], order: '3')
        ]),
      ]).single;
      expect(entry, isA<ItemStockEntry>());
      expect(entry.type, 'kids');
      expect(entry.price, '300.00');
      expect(entry.variants.single.sizes.every((s) => s.stock == 0), isTrue);
    });
  });

  group('ItemStore server-time adoption', () {
    setUp(() async {
      await resetTestInfra();
    });

    test('persists the offset and recovers it after a save', () {
      final store = ItemStore.instance;
      final server = DateTime.utc(2026, 9, 20, 12);

      store.adoptServerTime(server.toIso8601String(),
          receivedAt: server.add(const Duration(days: 1)));
      expect(store.serverTimeOffsetMs, -const Duration(days: 1).inMilliseconds);
      store.upsertItems([
        item(1, 'A', [variant(10, [sizeRow(100, 'S', 1)])])
      ]);
      expect(store.serverTimeOffsetMs, -const Duration(days: 1).inMilliseconds);

      store.adoptServerTime(server.toIso8601String(),
          receivedAt: server.subtract(const Duration(days: 1)));
      expect(store.serverTimeOffsetMs, const Duration(days: 1).inMilliseconds);
    });

    test('check() runs against the offset-corrected clock', () {
      final store = ItemStore.instance;
      final ref = DateTime.now();
      // Device 5 days behind the server.
      store.adoptServerTime(ref.toUtc().toIso8601String(),
          receivedAt: ref.subtract(const Duration(days: 5)));
      expect(store.serverTimeOffsetMs, const Duration(days: 5).inMilliseconds);

      final oos =
          ref.toUtc().subtract(const Duration(days: 27)).toIso8601String();
      store.upsertItems([
        item(1, 'Cellar', [variant(10, [sizeRow(100, 'S', 2)])], oos: oos),
        item(2, 'Fresh', [variant(20, [sizeRow(200, 'M', 3)])]),
      ]);
      // corrected now = now + 5d -> cutoff = now + 5d - 30d = now - 25d; the
      // 27-day-old OOS item must be archived by the server's clock even though
      // the device's naive clock would keep it for two more days.
      expect(store.check(), (items: 1, totalStock: 3));
    });

    test('clearStore resets the offset', () {
      final store = ItemStore.instance;
      final server = DateTime.utc(2026, 9, 20, 12);
      store.adoptServerTime(server.toIso8601String(),
          receivedAt: server.add(const Duration(days: 1)));
      expect(store.serverTimeOffsetMs, -const Duration(days: 1).inMilliseconds);
      store.clearStore();
      expect(store.serverTimeOffsetMs, 0);
    });
  });

  group('ItemStore delta re-sync stability', () {
    setUp(() async {
      await resetTestInfra();
    });

    test('re-applying an unchanged payload keeps variant order and display_order text',
        () {
      final store = ItemStore.instance;
      final payload = [
        item(9, 'Stable', [
          variant(90, [sizeRow(900, 'S', 1)], order: '2'),
          variant(91, [sizeRow(901, 'M', 1)], order: '1'),
        ], rev: 'r1'),
      ];
      store.upsertItems(payload);
      final first = store.entries().single.variants;
      final beforeIds = first.map((v) => v.id).toList();
      final beforeOrders = first.map((v) => v.displayOrder).toList();

      store.upsertItems(payload);
      final after = store.entries().single.variants;
      expect(after.map((v) => v.id).toList(), beforeIds);
      expect(after.map((v) => v.displayOrder).toList(), beforeOrders);
    });

    test('an in-place stock delta does not rescramble variant order', () {
      final store = ItemStore.instance;
      store.upsertItems([
        item(5, 'K', [
          variant(50, [sizeRow(500, 'S', 1)], order: '1'),
          variant(51, [sizeRow(501, 'M', 1)], order: '2'),
        ], rev: 'r1'),
      ]);

      ItemSyncData.applyStockRow(
          store.storedItems(), {'id': 501, 'size': 'M', 'stock': 7});
      final entry = store.entries().single;
      expect(entry.variants.map((v) => v.id).toList(), [50, 51]);
      expect(entry.variants.last.sizes.first.stock, 7);
      expect(entry.variants.map((v) => v.displayOrder).toList(), ['1', '2']);
    });
  });
}