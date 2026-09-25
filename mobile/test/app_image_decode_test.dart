import 'package:flutter_test/flutter_test.dart';

import 'package:stock_flow_admin/shared/widgets.dart';

void main() {
  group('appImageDecodeSide', () {
    test('scales the larger box side by the device pixel ratio', () {
      expect(appImageDecodeSide(52, 52, 2), 104);
    });

    test('uses the width when it is the larger side', () {
      expect(appImageDecodeSide(100, 40, 3), 300);
    });

    test('uses the height when it is the larger side', () {
      expect(appImageDecodeSide(40, 100, 3), 300);
    });

    test('falls back when constraints are unbounded', () {
      expect(
        appImageDecodeSide(double.infinity, double.infinity, 2, fallback: 20),
        40,
      );
    });

    test('falls back when the box is too small to be meaningful', () {
      expect(appImageDecodeSide(0, 0, 2, fallback: 16), 32);
      expect(appImageDecodeSide(5, 50, 2, fallback: 10), 100);
    });

    test('never returns less than one pixel', () {
      expect(appImageDecodeSide(10, 10, 0.01), 1);
    });
  });
}
