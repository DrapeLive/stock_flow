import 'package:flutter/services.dart';

/// Exclusive upper bound for `Item.price` (backend `DecimalField(max_digits=10,
/// decimal_places=2)` can hold up to 99,999,999.99).
const double kMaxItemPrice = 100000000.0;

const int kMaxPriceIntegerDigits = 8;
const int kMaxPriceDecimalDigits = 2;

/// Keeps digits and at most one decimal point; allows at most two decimal
/// places and eight integer digits; drops every other character. Pure so it
/// can be unit-tested without a widget tree.
String sanitizePriceInput(String raw) {
  final out = StringBuffer();
  var hasDot = false;
  var intDigits = 0;
  var decDigits = 0;
  for (var i = 0; i < raw.length; i++) {
    final code = raw.codeUnitAt(i);
    if (code == 0x2E) {
      if (hasDot) continue;
      hasDot = true;
      out.writeCharCode(code);
    } else if (code >= 0x30 && code <= 0x39) {
      if (hasDot) {
        if (decDigits < kMaxPriceDecimalDigits) {
          decDigits++;
          out.writeCharCode(code);
        }
      } else if (intDigits < kMaxPriceIntegerDigits) {
        intDigits++;
        out.writeCharCode(code);
      }
    }
  }
  return out.toString();
}

/// Parses a sanitized price. Returns null when blank, unparseable, or at/over
/// the backend limit; a zero price parses to 0.0 (validity gating lives at
/// the field level).
double? parseItemPrice(String raw) {
  final s = sanitizePriceInput(raw);
  if (s.isEmpty) return null;
  final v = double.tryParse(s);
  if (v == null || v >= kMaxItemPrice) return null;
  return v;
}

/// Keeps the price field contents valid while typing: drops invalid
/// characters greedily, preserves digits/dot, and caps digits per the
/// backend column.
class PriceTextInputFormatter extends TextInputFormatter {
  const PriceTextInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final filtered = sanitizePriceInput(newValue.text);
    if (filtered == newValue.text) return newValue;
    return TextEditingValue(
      text: filtered,
      selection: TextSelection.collapsed(offset: filtered.length),
    );
  }
}