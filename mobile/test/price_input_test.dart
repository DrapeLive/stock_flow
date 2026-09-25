import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stock_flow_admin/core/utils/price_input.dart';

void main() {
  group('sanitizePriceInput', () {
    test('keeps plain integers', () {
      expect(sanitizePriceInput('0'), '0');
      expect(sanitizePriceInput('12'), '12');
      expect(sanitizePriceInput('499'), '499');
    });

    test('keeps one decimal point and at most two decimals', () {
      expect(sanitizePriceInput('12.5'), '12.5');
      expect(sanitizePriceInput('12.50'), '12.50');
    });

    test('rejects a second decimal point', () {
      expect(sanitizePriceInput('1..2'), '1.2');
      expect(sanitizePriceInput('1.2.3'), '1.23');
    });

    test('caps decimals to two places (12.345 -> 12.34)', () {
      expect(sanitizePriceInput('12.345'), '12.34');
    });

    test('drops non-numeric characters', () {
      expect(sanitizePriceInput('abc'), '');
      expect(sanitizePriceInput('₹1,200'), '1200');
      expect(sanitizePriceInput('-12'), '12');
      expect(sanitizePriceInput('1e6'), '16');
    });

    test('caps integer digits to eight (DecimalField max_digits=10)', () {
      expect(sanitizePriceInput('1234567890'), '12345678');
      expect(sanitizePriceInput('12345678.99'), '12345678.99');
    });
  });

  group('parseItemPrice', () {
    test('parses valid prices', () {
      expect(parseItemPrice('0'), 0);
      expect(parseItemPrice('12'), 12);
      expect(parseItemPrice('12.5'), 12.5);
      expect(parseItemPrice('12.50'), 12.5);
    });

    test('returns null when blank or unparseable', () {
      expect(parseItemPrice(''), isNull);
      expect(parseItemPrice('  '), isNull);
      expect(parseItemPrice('.'), isNull);
      expect(parseItemPrice('abc'), isNull);
    });

    test('caps overflow to the backend width while parsing', () {
      // The formatter caps integer digits first, so no value can reach 1e8
      // through the UI; sanitize keeps only the first eight digits.
      expect(parseItemPrice('1234567890'), 12345678);
      expect(parseItemPrice('99999999.99'), 99999999.99);
    });
  });

  group('PriceTextInputFormatter', () {
    const formatter = PriceTextInputFormatter();

    test('lets valid input through unchanged', () {
      final result =
          formatter.formatEditUpdate(_old('1'), _new('12'));
      expect(result.text, '12');
    });

    test('rejects letters while typing', () {
      final result =
          formatter.formatEditUpdate(_old('12'), _new('12a'));
      expect(result.text, '12');
      expect(result.selection.baseOffset, 2);
    });

    test('rejects a second dot', () {
      final result =
          formatter.formatEditUpdate(_old('12.5'), _new('12.5.'));
      expect(result.text, '12.5');
    });

    test('caps decimal digits while typing', () {
      final result =
          formatter.formatEditUpdate(_old('12.3'), _new('12.34'));
      final exceeded =
          formatter.formatEditUpdate(_old('12.34'), _new('12.345'));
      expect(result.text, '12.34');
      expect(exceeded.text, '12.34');
    });
  });
}

TextEditingValue _old(String text) => TextEditingValue(
    text: text, selection: TextSelection.collapsed(offset: text.length));

TextEditingValue _new(String text) => TextEditingValue(
    text: text, selection: TextSelection.collapsed(offset: text.length));