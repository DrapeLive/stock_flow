import 'package:flutter_test/flutter_test.dart';

import 'package:stock_flow_admin/core/utils/derive_username.dart';
import 'package:stock_flow_admin/core/utils/formatters.dart';
import 'package:stock_flow_admin/core/utils/order_item_sort.dart';
import 'package:stock_flow_admin/core/utils/piece_counts.dart';
import 'package:stock_flow_admin/core/utils/status_maps.dart';
import 'package:stock_flow_admin/core/utils/stock_validators.dart';
import 'package:stock_flow_admin/features/orders/order_flow_utils.dart';
import 'package:stock_flow_admin/features/summary/summary_screen.dart';
import 'package:stock_flow_admin/data/repositories.dart';
import 'package:stock_flow_admin/models/models.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('formatters', () {
    test('formatInr uses Indian grouping', () {
      expect(formatInr(1234567.5), '₹12,34,567.50');
    });

    test('toApiDate formats yyyy-MM-dd', () {
      expect(toApiDate(DateTime(2026, 8, 5)), '2026-08-05');
    });

    test('formatDate renders dd MMM yyyy', () {
      expect(formatDate('2026-08-05'), '05 Aug 2026');
      expect(formatDate(null), '—');
      expect(formatDate('garbage'), 'garbage');
    });

    test('formatDateShort renders dd MMM', () {
      expect(formatDateShort('2026-08-05'), '05 Aug');
      expect(formatDateShort(''), '—');
    });

    test('formatDateTime renders dd MMM yyyy, hh:mm a', () {
      expect(formatDateTime('2026-08-05T14:30:00Z'), contains('05 Aug 2026'));
      expect(formatDateTime(null), '—');
    });

    test('formatSets singular/plural', () {
      expect(formatSets(0), '0 Sets');
      expect(formatSets(1), '1 Set');
      expect(formatSets(2), '2 Sets');
      expect(formatSets(11), '11 Sets');
    });

    test('formatPieces singular/plural', () {
      expect(formatPieces(0), '0 pcs');
      expect(formatPieces(1), '1 pc');
      expect(formatPieces(9), '9 pcs');
    });

    test('archiveCountdownLabel handles 0/1/7/8 days', () {
      expect(archiveCountdownLabel(0), 'Deletes today');
      expect(archiveCountdownLabel(1), 'Deletes in 1 day');
      expect(archiveCountdownLabel(7), 'Deletes in 7 days');
      expect(archiveCountdownLabel(8), 'Deletes in 8 days');
      expect(archiveCountdownLabel(-1), 'Deletes today');
    });

    test('activeFilterCount counts set filters', () {
      expect(activeFilterCount(), 0);
      expect(activeFilterCount(from: '2026-01-01'), 1);
      expect(activeFilterCount(to: '2026-02-01'), 1);
      expect(activeFilterCount(agent: 2), 1);
      expect(activeFilterCount(customer: 5), 1);
      expect(
        activeFilterCount(
            from: '2026-01-01', to: '2026-02-01', agent: 2, customer: 5),
        4,
      );
      expect(
        activeFilterCount(
            from: '', to: '2026-02-01', agent: null, customer: 5),
        2,
      );
    });
  });

  group('status_maps', () {
    test('OrderStatus.from normalises case', () {
      expect(OrderStatus.from('pending'), OrderStatus.pending);
      expect(OrderStatus.from('DISPATCHED'), OrderStatus.dispatched);
      expect(OrderStatus.from('weird'), OrderStatus.unknown);
      expect(OrderStatus.from(null), OrderStatus.unknown);
    });

    test('label/raw round-trip', () {
      for (final s in OrderStatus.values) {
        expect(OrderStatus.from(s.raw), s);
        if (s != OrderStatus.unknown) expect(s.label, isNotEmpty);
      }
    });

    test('statusBadgeColors maps known statuses', () {
      final (bg, fg) = statusBadgeColors(OrderStatus.pending);
      expect(bg, isNot(fg));
      expect(statusBadgeColors(OrderStatus.unknown), isNotNull);
    });
  });

  group('derive_username', () {
    test('slugifies and dedupes', () {
      expect(deriveUsername('  Ravi Kumar  '), 'ravi_kumar');
      expect(deriveUsername('A. B'), 'a_b');
      expect(deriveUsername('Sara', existingUsernames: {'sara'}),
          'sara_1');
      expect(
          deriveUsername('Sara',
              existingUsernames: {'sara', 'sara_1', 'sara_2'}),
          'sara_3');
      expect(deriveUsername('  '), '');
    });
  });

  group('piece_counts', () {
    test('pieceCountFor falls back to 1', () {
      expect(pieceCountFor('20-38'), 10);
      expect(pieceCountFor('S,M,L,XL'), 4);
      expect(pieceCountFor('nope'), 1);
    });

    test('singleSizeRangeFor finds lone ranges', () {
      expect(singleSizeRangeFor('38'), '38');
      expect(singleSizeRangeFor('S'), null);
    });

    test('size tables are consistent', () {
      expect(kSizeRangeToSizes['20-30'], ['20-24', '26-30']);
      expect(kSizeRangePieceCount['M,L,XL'], 3);
    });
  });

  group('stock_validators', () {
    List<VariantSize> gentsSizes(int stock) => [
          const VariantSize(sizeRange: 'S', stock: 0),
          VariantSize(sizeRange: 'M,L,XL', stock: stock),
          const VariantSize(sizeRange: 'XXL', stock: 0),
        ];

    test('sizeRangesWithStock handles gents grouping', () {
      final ranges = sizeRangesWithStock(
        sizes: gentsSizes(4),
        itemType: 'gents',
        orderGroups: const ['S', 'M,L,XL', 'XXL'],
      );
      // gents keeps only the widest matched range.
      expect(ranges.single.sizeRange, 'M,L,XL');
      expect(ranges.single.stock, 4); // min across the grouped ranges
    });

    test('variantOutOfStock when everything is zero', () {
      expect(
        variantOutOfStock(
          sizes: gentsSizes(0),
          itemType: 'gents',
          orderGroups: const ['S', 'M,L,XL', 'XXL'],
        ),
        isTrue,
      );
    });

    test('itemOutOfStock requires all variants out', () {
      final healthy = gentsSizes(5);
      expect(
        itemOutOfStock(
          variantSizes: [healthy],
          itemType: 'gents',
          orderGroups: const ['S', 'M,L,XL', 'XXL'],
        ),
        isFalse,
      );
      expect(
        itemPartiallyOutOfStock(
          variantSizes: [healthy, gentsSizes(0)],
          itemType: 'gents',
          orderGroups: const ['S', 'M,L,XL', 'XXL'],
        ),
        isTrue,
      );
    });
  });

  group('models', () {
    test('asInt/asString/asList helpers', () {
      expect(asInt(5), 5);
      expect(asInt('12'), 12);
      expect(asInt('x'), null);
      expect(s(null), '');
      expect(s(42, 'fallback'), '42');
      expect(asList<int>('nope', (_) => 1), isEmpty);
      expect(asList<Map<String, dynamic>>([{'a': 1}], (m) => m), hasLength(1));
    });

    test('Paginated.fromJson', () {
      final page = Paginated.fromJson(
        {
          'count': 2,
          'next': 'http://x/?page=2',
          'previous': null,
          'results': [
            {'id': 3, 'name': 'A'},
            {'id': 4, 'name': 'B'},
          ],
        },
        (m) => SimpleCustomer.fromJson(m),
      );
      expect(page.count, 2);
      expect(page.next, 'http://x/?page=2');
      expect(page.results.map((c) => c.name), ['A', 'B']);
    });

    test('AuthUser + Session round-trip', () {
      const user =
          AuthUser(id: 1, role: 'ADMIN', username: 'admin', business: 'xl');
      final session = Session(
          access: 'a', refresh: 'r', user: user);
      final restored = Session.fromJson(session.toJson());
      expect(restored.access, 'a');
      expect(restored.user.role, 'ADMIN');
      expect(restored.user.username, 'admin');
      expect(restored.user.business, 'xl');
    });

    test('Item parses variants and totalStock', () {
      final item = Item.fromJson(itemJson());
      expect(item.name, 'ITEM-A');
      expect(item.totalStock, 10);
      expect(item.variants.single.sizes, hasLength(2));
      expect(
        item.variants.single.sizes.map((s) => s.sizeRange),
        ['S', 'M,L,XL'],
      );
    });

    test('Item parses purge fields and tolerates old cached payloads', () {
      final withPurge = Item.fromJson({
        ...itemJson(),
        'purge_on': '2026-10-01',
        'days_until_purge': 7,
      });
      expect(withPurge.purgeOn, '2026-10-01');
      expect(withPurge.daysUntilPurge, 7);

      final legacy = Item.fromJson(itemJson());
      expect(legacy.purgeOn, isNull);
      expect(legacy.daysUntilPurge, isNull);
    });

    test('ItemStockEntry stock/sets getters', () {
      final entry = ItemStockEntry.fromJson(stockEntryJson());
      expect(entry.totalStock, 10);
      expect(entry.name, 'ITEM-A');
    });

    test('OrderItem display helpers', () {
      final oi = OrderItem.fromJson(orderItemJson());
      expect(oi.displayName, 'ITEM-A');
      expect(oi.quantity, 2);
      expect((oi.pieceCount ?? 1) * oi.quantity, 8);
      expect(oi.displaySizeGroup, 'S,M,L,XL');
    });

    test('OrderItem parses when item is a PK int (list payload)', () {
      final oi = OrderItem.fromJson({
        'id': 12,
        'item': 10,
        'variant': 100,
        'size_group': 'M,L,XL',
        'item_name': 'ITEM-B',
        'item_price': '600',
        'variant_image': 'http://example.com/img.png',
        'quantity': 3,
        'piece_count': 3,
        'variant_display_order': '2',
      });
      expect(oi.item, isNull);
      expect(oi.displayName, 'ITEM-B');
      expect(oi.displayPrice, '600');
      expect(oi.imageUrl, 'http://example.com/img.png');
      expect(oi.quantity, 3);
      expect((oi.pieceCount ?? 1) * oi.quantity, 9);
    });

    test('Order parses when items carry int item PKs', () {
      final order = Order.fromJson({
        'id': 2,
        'items': [
          {
            'id': 12,
            'item': 10,
            'variant': 100,
            'size_group': 'M,L,XL',
            'item_name': 'ITEM-B',
            'item_price': '600',
            'variant_image': '',
            'quantity': 3,
            'piece_count': 3,
            'variant_display_order': '2',
          },
        ],
        'agent_details': agentJson()['user'],
        'customer_details': customerJson(),
        'total_quantity': '3',
        'total_sets': 3,
        'total_pieces': 9,
        'status': 'PENDING',
        'created_at': '2026-08-21',
        'expected_delivery_date': null,
        'preferred_transport': null,
        'transport_company': null,
        'lr_number': '',
        'notes': '',
      });
      expect(order.id, 2);
      expect(order.items.single.displayName, 'ITEM-B');
      expect(order.items.single.displayPrice, '600');
      expect(order.customer.name, 'XL Fashions');
    });

    test('Order parses nested agent/customer', () {
      final order = Order.fromJson(orderJson());
      expect(order.id, 1);
      expect(order.customer.name, 'XL Fashions');
      expect(order.agent.username, 'agent_alpha');
      expect(order.status, 'PENDING');
      expect(order.totalSets, 2);
      expect(order.totalPieces, 8);
      expect(order.items, hasLength(1));
    });

    test('Agent displayName prefers display_name', () {
      final flat = Agent.fromJson({
        'id': 2,
        'user': {'id': 20},
      });
      expect(flat.displayName, 'Agent 20');
      final full = Agent.fromJson(agentJson());
      expect(full.displayName, 'Agent Alpha');
    });

    test('Customer/Agent parse numeric total fields (API sends ints)', () {
      final customer = Customer.fromJson(customerJson());
      expect(customer.totalOrders, '4');
      final agent = Agent.fromJson(agentJson());
      expect(agent.totalCustomers, '3');
    });

    test('AnalyticsData parses', () {
      final data = AnalyticsData.fromJson(analyticsJson());
      expect(data.kpis.pending, 4);
      expect(data.trend, hasLength(1));
      expect(data.topCustomers.first.name, 'XL Fashions');
      expect(data.timeMetrics?.avgDispatchHours, 12.5);
    });

    test('OrderFilters.toQuery omits empties', () {
      const f = OrderFilters(statuses: ['PENDING']);
      expect(f.toQuery(), {'page': 1, 'page_size': 50, 'status': ['PENDING']});
      const g = OrderFilters(search: 'x', fromDate: '2026-01-01', agent: 2);
      expect(g.toQuery(), {
        'page': 1,
        'page_size': 50,
        'search': 'x',
        'from_date': '2026-01-01',
        'agent': 2,
      });
    });

    test('VariantSize.fromJson accepts size_range key', () {
      final vs = VariantSize.fromJson({'size_range': 'M,L,XL', 'stock': 5});
      expect(vs.sizeRange, 'M,L,XL');
      expect(vs.stock, 5);
    });

    test('VariantSize.fromJson accepts size key (variants/all endpoint)', () {
      final vs = VariantSize.fromJson({'size': '38', 'stock': 10});
      expect(vs.sizeRange, '38');
      expect(vs.stock, 10);
    });

    test('VariantSize.fromJson prefers size_range when both present', () {
      final vs =
          VariantSize.fromJson({'size_range': 'M,L,XL', 'size': 'M', 'stock': 3});
      expect(vs.sizeRange, 'M,L,XL');
      expect(vs.stock, 3);
    });
  });

  group('summary computations', () {
    test('getPieceCount covers ranged/single/derived', () {
      expect(getPieceCount('20-38'), 10);
      expect(getPieceCount('S'), 1);
      expect(getPieceCount('S,M'), 2);
    });

    test('formatCurrency rounds and groups Indian style', () {
      expect(formatCurrency(1234567), '₹12,34,567.00');
    });

    test('computeSummary aggregates gents/kids + total', () {
      final summary = computeSummary([
        // gents: S=5pcs(1) + M,L,XL=5pcs(3) => 20 units, 10 stock
        ItemStockEntry.fromJson(stockEntryJson()),
        ItemStockEntry.fromJson({
          ...stockEntryJson(),
          'id': 11,
          'name': 'ITEM-K',
          'type': 'kids',
          'price': '200',
          'variants': [
            {
              'id': 101,
              'qr_code': 'QRK',
              'image': '',
              'sizes': [
                {'size_range': '20-24', 'stock': 2},
              ],
              'total_stock': 2,
              'display_order': '1',
            },
          ],
        }),
      ]);

      expect(summary.totalStock, 12);
      expect(summary.totalUnits, (5 * 4) + (2 * 3)); // 20 + 6 = 26
      expect(summary.totalPrice, (20 * 500) + (6 * 200)); // 10,000 + 1,200
      expect(summary.gentsStock, 10);
      expect(summary.kidsStock, 2);
      expect(summary.gentsPrice, 20 * 500);
      expect(summary.kidsPrice, 6 * 200);
      expect(summary.itemSummaries, hasLength(2));
    });
  });

  group('order_flow_utils', () {
    ItemVariantQR variant(List<(String, int)> sizes) => ItemVariantQR(
          id: 100,
          qrCode: 'QRONE',
          sizes: [
            for (final (range, stock) in sizes)
              VariantSize(sizeRange: range, stock: stock),
          ],
          totalStock: sizes.fold(0, (a, b) => a + b.$2),
        );

    test('availableSizeRanges matches gents exactly', () {
      final v = variant([('S', 5), ('M,L,XL', 5)]);
      final ranges = availableSizeRanges(
        v,
        'gents',
        const ['S,M,L,XL', 'M,L,XL,XXL', 'S,M,L,XL,XXL'],
      );
      expect(ranges, ['S,M,L,XL']);
    });

    test('availableSizeRanges keeps covered kids ranges', () {
      final v = variant([('20-24', 1), ('26-30', 1), ('32-36', 1)]);
      final ranges = availableSizeRanges(
        v,
        'kids',
        const ['20-38', '20-36', '26-38', '26-36', '20-30', '32-38'],
      );
      expect(ranges, contains('20-36'));
      expect(ranges, isNot(contains('20-38')));
      expect(ranges, isNot(contains('26-38')));
    });

    test('availableStockForSizeGroup subtracts reservations', () {
      final v = variant([('S', 5), ('M,L,XL', 5)]);
      expect(
        availableStockForSizeGroup(v, 'S,M,L,XL', const []),
        5,
      );
      expect(
        availableStockForSizeGroup(
          v,
          'S,M,L,XL',
          const [(sizeGroup: 'S,M,L,XL', quantity: 3)],
        ),
        2,
      );
      expect(
        availableStockForSizeGroup(
          v,
          'S,M,L,XL',
          const [(sizeGroup: 'M,L,XL', quantity: 9)],
        ),
        0,
      );
    });

    test('computeDuplicateGroups groups same variant + size group', () {
      final item = Item.fromJson(itemJson());
      final items = [
        OrderItem(
            id: 1,
            item: item,
            variant: 100,
            sizeGroup: 'S,M,L,XL',
            quantity: 2,
            variantDisplayOrder: '1'),
        OrderItem(
            id: 2,
            item: item,
            variant: 100,
            sizeGroup: 'S,M,L,XL',
            quantity: 3,
            variantDisplayOrder: '1'),
        OrderItem(
            id: 3,
            item: item,
            variant: 100,
            sizeGroup: 'M,L,XL',
            quantity: 1,
            variantDisplayOrder: '1'),
      ];
      final groups = computeDuplicateGroups(items);
      expect(groups, hasLength(1));
      expect(groups.single.sizeGroup, 'S,M,L,XL');
      expect(groups.single.total, 5);
      expect(groups.single.items.map((i) => i.id), [1, 2]);
    });

    test('OrderDraftSession start/clear', () {
      expect(OrderDraftSession.orderId, isNull);
      OrderDraftSession.start(orderId: 7, customerId: 3);
      expect(OrderDraftSession.orderId, 7);
      expect(OrderDraftSession.customerId, 3);
      OrderDraftSession.clear();
      expect(OrderDraftSession.orderId, isNull);
      expect(OrderDraftSession.customerId, isNull);
    });
  });

  group('order_item_sort', () {
    OrderItem item(int id, int quantity, int packed, {int pieceCount = 1}) =>
        OrderItem(
          id: id,
          quantity: quantity,
          packedQuantity: packed,
          pieceCount: pieceCount,
          variantDisplayOrder: '1',
        );

    List<int> ids(List<OrderItem> items) =>
        [for (final i in items) i.id];

    test('isOrderItemFullyPacked boundaries', () {
      expect(isOrderItemFullyPacked(item(1, 3, 0)), isFalse);
      expect(isOrderItemFullyPacked(item(1, 3, 2)), isFalse);
      expect(isOrderItemFullyPacked(item(1, 2, 4, pieceCount: 2)), isTrue);
      expect(isOrderItemFullyPacked(item(1, 2, 5, pieceCount: 2)), isTrue);
    });

    test('puts unpacked first, packed last, stable within groups', () {
      final items = [
        item(1, 2, 0),
        item(2, 1, 1),
        item(3, 1, 0),
        item(4, 2, 4, pieceCount: 2),
      ];
      expect(ids(sortOrderItemsUnpackedFirst(items)), [1, 3, 2, 4]);
    });

    test('keeps an all-packed list unchanged', () {
      expect(
        ids(sortOrderItemsUnpackedFirst([item(5, 1, 1), item(6, 2, 2)])),
        [5, 6],
      );
    });

    test('keeps an all-unpacked list unchanged', () {
      expect(
        ids(sortOrderItemsUnpackedFirst([item(7, 3, 0), item(8, 1, 0)])),
        [7, 8],
      );
    });

    test('treats partially packed items as unpacked', () {
      final items = [item(1, 1, 1), item(2, 3, 2), item(3, 2, 0)];
      expect(ids(sortOrderItemsUnpackedFirst(items)), [2, 3, 1]);
    });

    test('does not mutate the input list', () {
      final items = [item(1, 1, 1), item(2, 1, 0)];
      final before = ids(items);
      final result = sortOrderItemsUnpackedFirst(items);
      expect(ids(items), before);
      expect(identical(result, items), isFalse);
    });

    test('returns an empty list for empty input', () {
      expect(sortOrderItemsUnpackedFirst(const []), isEmpty);
    });
  });
}