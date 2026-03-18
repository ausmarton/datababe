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

  group('Bottle Feed form', () {
    testWidgets('shows feed type selector and volume field', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());
      await navigateToType(tester, 'Bottle Feed');

      expect(find.text('Log Bottle Feed'), findsOneWidget);
      expect(find.text('Formula'), findsOneWidget);
      expect(find.text('Breast Milk'), findsOneWidget);
      expect(find.text('Volume (ml)'), findsOneWidget);
      expect(find.text('Notes'), findsOneWidget);
    });

    testWidgets('shows Time picker', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());
      await navigateToType(tester, 'Bottle Feed');

      expect(find.text('Date'), findsOneWidget);
      expect(find.text('Time'), findsOneWidget);
      // Bottle feed has no end time
      expect(find.text('End date'), findsNothing);
    });
  });

  group('Breast Feed form', () {
    testWidgets('shows left/right breast fields and end time', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());
      await navigateToType(tester, 'Breast Feed');

      expect(find.text('Log Breast Feed'), findsOneWidget);
      expect(find.text('Right breast (minutes)'), findsOneWidget);
      expect(find.text('Left breast (minutes)'), findsOneWidget);
      expect(find.text('End time'), findsOneWidget);
      expect(find.text('Notes'), findsOneWidget);
    });
  });

  group('Diaper form', () {
    testWidgets('shows contents, size, colour, and consistency', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());
      await navigateToType(tester, 'Diaper');

      expect(find.text('Log Diaper'), findsOneWidget);
      // Contents selector
      expect(find.text('Pee'), findsOneWidget);
      expect(find.text('Poo'), findsOneWidget);
      expect(find.text('Both'), findsOneWidget);
      // Size selector
      expect(find.text('Small'), findsOneWidget);
      expect(find.text('Medium'), findsOneWidget);
      expect(find.text('Large'), findsOneWidget);
      // Poo fields (default is poo)
      expect(find.text('Colour'), findsOneWidget);
      expect(find.text('Consistency'), findsOneWidget);
      expect(find.text('Notes'), findsOneWidget);
    });

    testWidgets('switching to Both shows pee size selector', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());
      await navigateToType(tester, 'Diaper');

      // Tap 'Both'
      await tester.tap(find.text('Both'));
      await tester.pumpAndSettle();

      // Should now show pee size row
      expect(find.text('Pee: S'), findsOneWidget);
      expect(find.text('Pee: M'), findsOneWidget);
      expect(find.text('Pee: L'), findsOneWidget);
    });

    testWidgets('switching to Pee hides colour and consistency', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());
      await navigateToType(tester, 'Diaper');

      await tester.tap(find.text('Pee'));
      await tester.pumpAndSettle();

      expect(find.text('Colour'), findsNothing);
      expect(find.text('Consistency'), findsNothing);
    });
  });

  group('Medication form', () {
    testWidgets('shows medication name, dose, and unit fields', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());
      await navigateToType(tester, 'Medication');

      expect(find.text('Log Medication'), findsOneWidget);
      expect(find.text('Medication name'), findsOneWidget);
      expect(find.text('Dose'), findsOneWidget);
      expect(find.text('Unit'), findsOneWidget);
      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });
  });

  group('Growth form', () {
    testWidgets('shows weight, length, and head fields', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());
      await navigateToType(tester, 'Growth');

      expect(find.text('Log Growth'), findsOneWidget);
      expect(find.text('Weight (kg)'), findsOneWidget);
      expect(find.text('Length (cm)'), findsOneWidget);
      expect(find.text('Head circumference (cm)'), findsOneWidget);
      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });
  });

  group('Temperature form', () {
    testWidgets('shows temperature field', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());
      await navigateToType(tester, 'Temperature');

      expect(find.text('Log Temperature'), findsOneWidget);
      expect(find.textContaining('Temperature'), findsWidgets);
      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });
  });

  group('Pump form', () {
    testWidgets('shows volume field and end time', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());
      await navigateToType(tester, 'Pump');

      expect(find.text('Log Pump'), findsOneWidget);
      expect(find.text('Volume (ml)'), findsOneWidget);
      expect(find.text('End time'), findsOneWidget);
      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });
  });

  group('Potty form', () {
    testWidgets('shows contents and size selectors', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());
      await navigateToType(tester, 'Potty');

      expect(find.text('Log Potty'), findsOneWidget);
      expect(find.text('Pee'), findsOneWidget);
      expect(find.text('Poo'), findsOneWidget);
      expect(find.text('Both'), findsOneWidget);
      expect(find.text('Small'), findsOneWidget);
      expect(find.text('Medium'), findsOneWidget);
      expect(find.text('Large'), findsOneWidget);
      // Potty does NOT have colour/consistency
      expect(find.text('Colour'), findsNothing);
      expect(find.text('Consistency'), findsNothing);
    });
  });

  group('Duration-only forms', () {
    for (final entry in {
      'Tummy Time': 'Tummy Time',
      'Indoor Play': 'Indoor Play',
      'Outdoor Play': 'Outdoor Play',
      'Bath': 'Bath',
      'Skin to Skin': 'Skin to Skin',
      'Sleep': 'Sleep',
    }.entries) {
      testWidgets('${entry.key} shows end time and no extra fields',
          (tester) async {
        await tester.runAsync(() => harness.seedMinimal());
        await pumpApp(tester, harness.buildApp());
        await navigateToType(tester, entry.value);

        expect(find.textContaining('Log ${entry.value}'), findsOneWidget);
        expect(find.text('End time'), findsOneWidget);
        expect(find.text('Notes'), findsOneWidget);
        expect(find.text('Save'), findsOneWidget);
        // No type-specific extra fields
        expect(find.text('Volume (ml)'), findsNothing);
        expect(find.text('Weight (kg)'), findsNothing);
      });
    }
  });

  group('Common form behaviour', () {
    testWidgets('all activity types are accessible from home grid',
        (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());

      // Verify all 15 types have ActionChips
      for (final name in [
        'Bottle Feed',
        'Breast Feed',
        'Diaper',
        'Medication',
        'Solids',
        'Growth',
        'Tummy Time',
        'Indoor Play',
        'Outdoor Play',
        'Pump',
        'Temperature',
        'Bath',
        'Skin to Skin',
        'Potty',
        'Sleep',
      ]) {
        expect(find.widgetWithText(ActionChip, name), findsOneWidget,
            reason: '$name chip should be visible');
      }
    });
  });
}
