import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:habitolivingguard/screens/guard/gate_home_screen.dart';

void main() {
  testWidgets('GateTabBar stays compact inside a Scaffold bottom bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: GateTabBar(
            selectedTab: GateTab.gate,
            onTabSelected: (_) {},
          ),
        ),
      ),
    );

    final size = tester.getSize(find.byType(GateTabBar));
    expect(
      size.height,
      lessThan(120),
      reason: 'tab bar height was ${size.height}',
    );
  });

  testWidgets('GateHomeScreen embedded renders without overflow', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GateHomeScreen(embedded: true, onTabSelected: (_) {}),
          bottomNavigationBar: GateTabBar(
            selectedTab: GateTab.gate,
            onTabSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}