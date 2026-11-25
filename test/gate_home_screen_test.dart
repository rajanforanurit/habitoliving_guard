import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:habitoliving_shared/models/admin.dart';
import 'package:habitolivingguard/screens/guard/gate_home_screen.dart';

void main() {
  testWidgets('the gate page has no bottom navigation', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: GateHomeScreen())),
    );

    expect(find.byType(BottomNavigationBar), findsNothing);
    expect(
      find.byWidgetPredicate((w) => w is Material && w.child is InkWell),
      findsWidgets,
      reason: 'the four gate actions should still be tappable tiles',
    );
  });

  testWidgets('the gate page fits a small phone without overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: GateHomeScreen())),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('a recent activity line reads as a sentence', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GateHomeScreen(
            activities: [
              GateActivity.fromJson({
                'id': 'maid1:2026-11-25',
                'kind': 'MAID_ATTENDANCE',
                'name': 'Rani',
                'status': 'PRESENT',
              }),
              const GateActivity(
                id: 'v1',
                kind: GateActivityKind.visitor,
                name: 'Ramesh',
                status: 'APPROVED',
                flatLabel: 'A-103',
                at: null,
              ),
              const GateActivity(
                id: 'd1',
                kind: GateActivityKind.delivery,
                name: 'Ravi',
                status: 'APPROVED',
                flatLabel: 'A-101',
                company: 'Zepto',
                at: null,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Maid attendance recorded for Rani'), findsOneWidget);
    expect(find.text('Visitor approved by A-103 for Ramesh'), findsOneWidget);
    expect(find.text('Delivery approved from A-101 for Zepto'), findsOneWidget);
  });
}
