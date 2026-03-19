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

  group('Discard confirmation', () {
    testWidgets('back without changes navigates away immediately',
        (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());
      await navigateToType(tester, 'Bottle Feed');

      expect(find.text('Log Bottle Feed'), findsOneWidget);

      // Press back — no dialog expected since no changes made
      final backButton = find.byType(BackButton);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Should be back on home screen
      expect(find.text('Log Bottle Feed'), findsNothing);
    });

    testWidgets('back after typing shows discard dialog', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());
      await navigateToType(tester, 'Bottle Feed');

      // Type in the volume field to make form dirty
      final volumeField = find.widgetWithText(TextFormField, 'Volume (ml)');
      await tester.enterText(volumeField, '120');
      await tester.pumpAndSettle();

      // Press back — dialog should appear
      final backButton = find.byType(BackButton);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Discard'), findsOneWidget);
    });

    testWidgets('cancel in dialog stays on form', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());
      await navigateToType(tester, 'Bottle Feed');

      // Make dirty
      final volumeField = find.widgetWithText(TextFormField, 'Volume (ml)');
      await tester.enterText(volumeField, '120');
      await tester.pumpAndSettle();

      // Press back
      final backButton = find.byType(BackButton);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Should still be on form
      expect(find.text('Log Bottle Feed'), findsOneWidget);
    });

    testWidgets('discard in dialog navigates away', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());
      await navigateToType(tester, 'Bottle Feed');

      // Make dirty
      final volumeField = find.widgetWithText(TextFormField, 'Volume (ml)');
      await tester.enterText(volumeField, '120');
      await tester.pumpAndSettle();

      // Press back
      final backButton = find.byType(BackButton);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Tap Discard
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      // Should be back on home screen
      expect(find.text('Log Bottle Feed'), findsNothing);
    });

    testWidgets('save clears dirty state — back works normally',
        (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());
      await navigateToType(tester, 'Tummy Time');

      // Tummy time doesn't require any fields — just save
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Should navigate away after save (no dialog)
      expect(find.text('Log Tummy Time'), findsNothing);
    });

    testWidgets('date picker change makes form dirty', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());
      await navigateToType(tester, 'Bottle Feed');

      // Tap the date row to open date picker
      await tester.tap(find.text('Date'));
      await tester.pumpAndSettle();

      // Pick a date (tap OK on the date picker)
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Press back — should show dialog since date was touched
      final backButton = find.byType(BackButton);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsOneWidget);
    });

    testWidgets('notes field change triggers dirty flag', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());
      await navigateToType(tester, 'Diaper');

      // Type in notes
      final notesField = find.widgetWithText(TextFormField, 'Notes');
      await tester.scrollUntilVisible(
        notesField,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.enterText(notesField, 'test note');
      await tester.pumpAndSettle();

      // Press back — should show dialog
      final backButton = find.byType(BackButton);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsOneWidget);
    });

    testWidgets('duration type — no changes, back works immediately',
        (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());
      await navigateToType(tester, 'Sleep');

      expect(find.text('Log Sleep'), findsOneWidget);

      // Back without changes
      final backButton = find.byType(BackButton);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // No dialog, navigated away
      expect(find.text('Log Sleep'), findsNothing);
    });
  });
}
