import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stock_flow_admin/features/summary/summary_screen.dart';

import 'helpers.dart';

List<String> _allRenderedTexts(WidgetTester tester) {
  final out = <String>[];
  for (final w in tester.allWidgets) {
    if (w is Text) {
      if (w.data != null) out.add(w.data!);
      final span = w.textSpan;
      if (span != null) out.add(span.toPlainText());
    } else if (w is RichText) {
      out.add(w.text.toPlainText());
    }
  }
  return out;
}

void _expectNoMojibake(Iterable<String> texts) {
  const markers = ['â', 'Â', 'Ã'];
  for (final t in texts) {
    for (final m in markers) {
      expect(t.contains(m), isFalse,
          reason: 'found "$m" mojibake marker in rendered text: "$t"');
    }
  }
}

void main() {
  testWidgets('Summary screen renders no UTF-8 mojibake in any text',
      (tester) async {
    await resetTestInfra();
    final container = makeTestContainer();
    addTearDown(container.dispose);

    mockGet('/api/items/stock-list/', body: [stockEntryJson()]);
    seedAdminSession();
    useTallSurface(tester);

    await pumpScreen(tester, const SummaryScreen(), container);
    await tester.pumpAndSettle();

    // Part B2: the sort control uses the shared arrow constant.
    expect(find.text('Total Pieces: Low \u2192 High'), findsOneWidget);

    // Part B3: the size-range reference section (header + chips) is gone.
    expect(find.textContaining('PIECE COUNT'), findsNothing);
    expect(find.textContaining('→ 10 pcs'), findsNothing);
    // The average line still renders, now with the real × symbol.
    expect(find.textContaining('avg pcs/set'), findsWidgets);

    _expectNoMojibake(_allRenderedTexts(tester));
  });

  testWidgets('Summary stat cards render the shared INR symbol, not "â"',
      (tester) async {
    await resetTestInfra();
    final container = makeTestContainer();
    addTearDown(container.dispose);

    mockGet('/api/items/stock-list/', body: [stockEntryJson(), stockEntryJson()]);
    seedAdminSession();
    useTallSurface(tester);

    await pumpScreen(tester, const SummaryScreen(), container);
    await tester.pumpAndSettle();

    expect(find.textContaining('\u20B9'), findsWidgets);
    _expectNoMojibake(_allRenderedTexts(tester));
  });
}