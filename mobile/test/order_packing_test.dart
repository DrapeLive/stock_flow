import 'package:flutter_test/flutter_test.dart';

import 'package:stock_flow_admin/core/utils/order_packing.dart';
import 'package:stock_flow_admin/models/models.dart';

OrderItem line(int id, int quantity, int packed, {int pieceCount = 1}) =>
    OrderItem(
      id: id,
      quantity: quantity,
      packedQuantity: packed,
      pieceCount: pieceCount,
      variantDisplayOrder: 1,
    );

Order order(String? status, List<OrderItem> items) => Order(
      id: 1,
      items: items,
      agent: const SimpleAgent(id: 0),
      customer: const SimpleCustomer(id: 0, name: ''),
      totalSets: 0,
      totalPieces: 0,
      status: status,
      createdAt: '2026-01-01',
    );

void main() {
  group('unpackedLineCount', () {
    test('no items -> 0', () {
      expect(unpackedLineCount(order('PENDING', const [])), 0);
    });

    test('all packed -> 0', () {
      expect(
        unpackedLineCount(order('PENDING', [
          line(1, 2, 8, pieceCount: 4),
          line(2, 1, 3, pieceCount: 3),
        ])),
        0,
      );
    });

    test('all unpacked -> one per line', () {
      expect(
        unpackedLineCount(order('PENDING', [line(1, 2, 0), line(2, 3, 0)])),
        2,
      );
    });

    test('partially packed counts as unpacked', () {
      // qty 2 * pieceCount 3 = 6 pieces; only 2 packed -> still unpacked.
      expect(
        unpackedLineCount(order('PENDING', [line(1, 2, 2, pieceCount: 3)])),
        1,
      );
    });

    test('mixed counts only the unpacked lines', () {
      expect(
        unpackedLineCount(order('PENDING', [
          line(1, 1, 9, pieceCount: 9), // fully packed
          line(2, 2, 3, pieceCount: 3), // partial (3 of 6)
          line(3, 1, 0, pieceCount: 9), // none
        ])),
        2,
      );
    });

    test('DISPATCHED hides the badge', () {
      expect(
        unpackedLineCount(
            order('DISPATCHED', [line(1, 1, 0, pieceCount: 9)])),
        0,
      );
    });

    test('PACKED with an unpacked line still shows it', () {
      expect(
        unpackedLineCount(order('PACKED', [
          line(1, 1, 9, pieceCount: 9),
          line(2, 1, 0, pieceCount: 9),
        ])),
        1,
      );
    });

    test('DRAFT / EDITING / null hide the badge', () {
      expect(unpackedLineCount(order('DRAFT', [line(1, 1, 0)])), 0);
      expect(unpackedLineCount(order('EDITING', [line(1, 1, 0)])), 0);
      expect(unpackedLineCount(order(null, [line(1, 1, 0)])), 0);
    });

    test('missing pieceCount defaults to 1 piece per set', () {
      // qty 2 * default 1 = 2 pieces; 1 packed -> partial -> unpacked.
      expect(unpackedLineCount(order('PENDING', [line(1, 2, 1)])), 1);
    });
  });
}
