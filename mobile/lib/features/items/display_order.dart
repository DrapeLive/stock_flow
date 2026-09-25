/// Shared, single fallback for variant `display_order`, which may be null or
/// blank. Mirrors the web convention (`frontend/lib/colorLabel.ts`):
///  - chips/cards: show `Color #<n>`, falling back to the position number;
///  - sorting: numeric value ascending, unset/blank/non-numeric last.
/// A helper-only file so it can be unit-tested without widget dependencies.
library;

/// Numeric value used for sorting; unset/blank/non-numeric sort last.
int variantOrderValue(String? displayOrder) {
  final parsed = int.tryParse(displayOrder?.trim() ?? '');
  return parsed ?? 1 << 30;
}

/// Chip/card caption: `Color #<display_order>` or `Color #<position>`.
String colorNumberLabel(String? displayOrder, int position) {
  final value = displayOrder?.trim() ?? '';
  return value.isEmpty ? 'Color #$position' : 'Color #$value';
}

final _numRegex = RegExp(r'\d+|\D+');

List<Object> _tokens(String s) => _numRegex
    .allMatches(s)
    .map((m) => m.group(0)!)
    .map((t) => int.tryParse(t) ?? t.toLowerCase())
    .toList();

/// Numeric-aware name comparison, ascending — mirrors the web
/// `a.name.localeCompare(b.name, undefined, { numeric: true })` used by the
/// Ordered tab's group-name sort.
int compareItemNamesAsc(String a, String b) {
  final ta = _tokens(a);
  final tb = _tokens(b);
  final n = ta.length < tb.length ? ta.length : tb.length;
  for (var i = 0; i < n; i++) {
    final x = ta[i];
    final y = tb[i];
    if (x is int && y is int) {
      if (x != y) return x - y;
    } else if (x is String && y is String) {
      if (x != y) return x.compareTo(y);
    } else {
      final r = x.toString().compareTo(y.toString());
      if (r != 0) return r;
    }
  }
  return ta.length - tb.length;
}

/// Descending variant of [compareItemNamesAsc], mirroring the web
/// `b.name.localeCompare(a.name, undefined, { numeric: true })`.
int compareItemNamesDesc(String a, String b) => compareItemNamesAsc(b, a);