import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stock_flow_admin/shared/widgets.dart';

void main() {
  testWidgets('PulsingDot animates and disposes cleanly', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Center(child: PulsingDot()))),
    );
    await tester.pump();
    expect(find.byType(PulsingDot), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 700));

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('PulsingDot renders statically when animations are disabled',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(body: Center(child: PulsingDot())),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(PulsingDot), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('PulsingDot accepts an external controller', (tester) async {
    final controller = AnimationController(
      vsync: const TestVSync(),
      duration: const Duration(milliseconds: 1400),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Center(child: PulsingDot(controller: controller))),
      ),
    );
    await tester.pump();
    expect(find.byType(PulsingDot), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    controller.dispose();
    expect(tester.takeException(), isNull);
  });
}
