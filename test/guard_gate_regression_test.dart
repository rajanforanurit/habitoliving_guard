import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitoliving_shared/models/resident.dart';
import 'package:habitoliving_shared/models/society.dart';
import 'package:habitolivingguard/screens/guard/register_delivery_screen.dart';

void main() {
  test(
    'the gate directory uses actual flats even without a configured layout',
    () {
      final info = SocietyPropertyInfo.fromJson({
        'societyId': 'demo',
        'gateDirectory': [
          {
            'name': 'Tower A',
            'flats': [
              {'id': 'flat-a', 'label': 'A-101'},
            ],
          },
          {
            'name': 'Tower B',
            'flats': [
              {'id': 'flat-b', 'label': 'B-101'},
            ],
          },
        ],
      });

      expect(info.flatsByTower, {
        'Tower A': ['A-101'],
        'Tower B': ['B-101'],
      });
      expect(info.flatIds['B-101'], 'flat-b');
    },
  );

  test('older layout payloads still show configured flat labels', () {
    final info = SocietyPropertyInfo.fromJson({
      'propertyDetails': {
        'towers': [
          {
            'name': 'Tower B',
            'flats': ['B-101'],
          },
        ],
      },
    });

    expect(info.flatsByTower, {
      'Tower B': ['B-101'],
    });
  });

  test('an approval for collection at the gate cannot be used for entry', () {
    final delivery = Delivery.fromJson({
      'id': 'delivery',
      'status': 'APPROVED',
      'leaveAtGate': true,
    });

    expect(delivery.canLeaveAtGate, isTrue);
    expect(delivery.canEnter, isFalse);
  });

  testWidgets(
    'a courier below the first three rows can be selected and submitted',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      DeliverySubmission? submitted;
      await tester.pumpWidget(
        MaterialApp(
          home: RegisterDeliveryScreen(
            flatsByTower: const {
              'Tower A': ['A-101'],
            },
            onSubmit: (value) => submitted = value,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('A-101'));
      await tester.pumpAndSettle();

      final grid = find.byType(GridView);
      final indiaPost = find.text('India Post');
      await tester.scrollUntilVisible(
        indiaPost,
        100,
        scrollable: find.descendant(
          of: grid,
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(indiaPost);
      await tester.pump();
      await tester.tap(find.text('Register and notify'));

      expect(submitted?.brand.label, 'India Post');
      expect(submitted?.category, DeliveryCategory.document);
      expect(submitted?.flat, 'A-101');
      expect(tester.takeException(), isNull);
    },
  );
}
