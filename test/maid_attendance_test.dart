import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitolivingguard/screens/guard/gate_home_screen.dart';

void main() {
  testWidgets('the gate tile opens attendance and keeps leading zeros', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: GateHomeScreen()));
    await tester.tap(find.text('Maid\nAttendance'));
    await tester.pumpAndSettle();

    expect(find.text('Maid attendance'), findsOneWidget);
    final input = find.byType(TextField);
    final submit = find.widgetWithText(FilledButton, 'Mark present');
    await tester.enterText(input, '00123');
    await tester.pump();
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    await tester.enterText(input, '001234');
    await tester.pump();
    expect(tester.widget<TextField>(input).controller!.text, '001234');
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
  });
}
