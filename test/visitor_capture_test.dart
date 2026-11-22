import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitolivingguard/screens/guard/register_visitor_screen.dart';
import 'package:habitolivingguard/screens/guard/tower_flat_selector.dart';

void main() {
  testWidgets('the gate loading message is centered in the safe area', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GatePage(
          body: GateStatusMessage(
            icon: Icons.hourglass_top_rounded,
            title: 'Loading the flat list',
            message: 'Fetching the society layout.',
          ),
        ),
      ),
    );
    final group = find.descendant(
      of: find.byType(GateStatusMessage),
      matching: find.byType(Column),
    );
    expect(tester.getCenter(group), tester.getCenter(find.byType(Scaffold)));
  });

  testWidgets('confirming a photo returns to the same visitor form', (
    tester,
  ) async {
    VisitorSubmission? submitted;
    final photo = MemoryImage(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO/aWZ8AAAAASUVORK5CYII=',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => RegisterVisitorScreen(
            flatsByTower: const {
              'Tower A': ['A-101'],
            },
            onCapturePhoto: () =>
                Navigator.of(context).push<ImageProvider<Object>>(
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                      body: Center(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(photo),
                          child: const Text('Use photo'),
                        ),
                      ),
                    ),
                  ),
                ),
            onSubmit: (value) => submitted = value,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('A-101'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'Test Visitor');
    await tester.ensureVisible(find.text('Tap to Take Visitor Photo'));
    await tester.tap(find.text('Tap to Take Visitor Photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use photo'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(find.text('Tower A  •  Flat A-101'), findsOneWidget);
    expect(find.text('Test Visitor'), findsOneWidget);
    expect(find.text('Tap to retake photo'), findsOneWidget);
    await tester.tap(find.text('Tap to retake photo'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Tap to retake photo'), findsOneWidget);
    await tester.tap(find.text('Send for Approval'));
    expect(submitted?.flat, 'A-101');
    expect(submitted?.name, 'Test Visitor');
    expect(submitted?.photo, photo);
  });
}
