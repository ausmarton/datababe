import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_harness.dart';

void main() {
  final harness = TestHarness();

  setUp(harness.setUp);
  tearDown(harness.tearDown);

  Future<void> navigateToType(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(ActionChip, label));
    await tester.pumpAndSettle();
  }

  group('Duration validation — inline error', () {
    testWidgets('sleep form shows end time fields', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());
      await navigateToType(tester, 'Sleep');

      expect(find.text('Log Sleep'), findsOneWidget);
      expect(find.text('End date'), findsOneWidget);
      expect(find.text('End time'), findsOneWidget);
    });

    testWidgets('end time "Not set" by default', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());
      await navigateToType(tester, 'Sleep');

      // End time should show "Not set" by default
      expect(find.text('Not set'), findsWidgets);
    });

    testWidgets('no error text when end time is not set', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());
      await navigateToType(tester, 'Sleep');

      // No inline error when end time is null
      expect(find.text('End time must be after start time'), findsNothing);
    });

    testWidgets('no error text visible for point-in-time activities',
        (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());
      await navigateToType(tester, 'Bottle Feed');

      // Bottle feed has no end time at all
      expect(find.text('End time'), findsNothing);
      expect(find.text('End time must be after start time'), findsNothing);
    });
  });

  group('Duration validation — all duration types show end time', () {
    for (final type in [
      'Breast Feed',
      'Tummy Time',
      'Indoor Play',
      'Outdoor Play',
      'Pump',
      'Bath',
      'Skin to Skin',
      'Sleep',
    ]) {
      testWidgets('$type has end time fields', (tester) async {
        await tester.runAsync(() => harness.seedMinimal());
        await pumpApp(tester, harness.buildApp());
        await navigateToType(tester, type);

        expect(find.text('End time'), findsOneWidget,
            reason: '$type should have end time field');
        expect(find.text('End date'), findsOneWidget,
            reason: '$type should have end date field');
      });
    }
  });

  group('Duration validation — non-duration types lack end time', () {
    for (final type in [
      'Bottle Feed',
      'Diaper',
      'Medication',
      'Solids',
      'Growth',
      'Temperature',
      'Potty',
    ]) {
      testWidgets('$type has no end time fields', (tester) async {
        await tester.runAsync(() => harness.seedMinimal());
        await pumpApp(tester, harness.buildApp());
        await navigateToType(tester, type);

        expect(find.text('End time'), findsNothing,
            reason: '$type should NOT have end time field');
        expect(find.text('End date'), findsNothing,
            reason: '$type should NOT have end date field');
      });
    }
  });

  group('Duration validation — save button present', () {
    testWidgets('save button on duration activity', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());
      await navigateToType(tester, 'Sleep');

      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('save allowed without end time (null is OK)', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());
      await navigateToType(tester, 'Tummy Time');

      // Save without setting end time — should succeed (endTime null is valid)
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Should navigate back to home (save succeeded)
      expect(find.text('Log Tummy Time'), findsNothing);
    });
  });
}
