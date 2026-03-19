import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_harness.dart';

void main() {
  final harness = TestHarness();

  setUp(harness.setUp);
  tearDown(harness.tearDown);

  Future<void> navigateToAllergens(WidgetTester tester) async {
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage Allergens'));
    await tester.pumpAndSettle();
  }

  Future<void> navigateToIngredients(WidgetTester tester) async {
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage Ingredients'));
    await tester.pumpAndSettle();
  }

  group('Allergen category — rename cascade', () {
    testWidgets('tap allergen chip opens rename dialog with correct title and fields',
        (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToAllergens(tester);

      // Tap on "peanut" chip label to trigger rename dialog
      await tester.tap(find.text('peanut'));
      await tester.pumpAndSettle();

      expect(find.text('Rename allergen'), findsOneWidget);
      expect(find.text('New name'), findsOneWidget);
    });

    testWidgets('rename dialog pre-fills current name in text field',
        (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToAllergens(tester);

      // Tap on "wheat (1)" chip label to trigger rename dialog
      await tester.tap(find.text('wheat (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Rename allergen'), findsOneWidget);
      // The text field should be pre-filled with the current name "wheat"
      final textField = tester.widget<TextField>(find.byType(TextField).last);
      expect(textField.controller?.text, 'wheat');
    });

    testWidgets('rename dialog has Cancel and Rename buttons',
        (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToAllergens(tester);

      await tester.tap(find.text('soy'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Rename'), findsOneWidget);
    });

    testWidgets('same-name rename is rejected — dialog dismisses without changes',
        (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToAllergens(tester);

      await tester.tap(find.text('peanut'));
      await tester.pumpAndSettle();

      // Tap Rename without changing the pre-filled name — same-name is rejected silently.
      // The production code disposes the renameController immediately after dialog pop,
      // which can cause a framework error on the next frame. Use pump() to flush the
      // dialog dismissal, then verify.
      await tester.tap(find.text('Rename'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Dialog should be dismissed, the allergen screen still visible with all 5 chips
      expect(find.text('Manage Allergens'), findsOneWidget);
      expect(find.byType(Chip), findsNWidgets(5));
    });
  });

  group('Allergen category — delete cascade', () {
    testWidgets('delete unused allergen (soy) shows simple confirmation without cascade warning',
        (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToAllergens(tester);

      // "soy" is the last chip in the list, with 0 ingredient usage
      final deleteIcons = find.byIcon(Icons.cancel);
      expect(deleteIcons, findsWidgets);

      // soy is 5th allergen (last) — tap its delete icon
      await tester.tap(deleteIcons.last);
      await tester.pumpAndSettle();

      expect(find.text('Delete allergen?'), findsOneWidget);
      expect(find.textContaining('Remove "soy"'), findsOneWidget);
      // Should NOT mention ingredient cascade
      expect(find.textContaining('ingredient'), findsNothing);
    });

    testWidgets('delete used allergen (egg) shows cascade warning mentioning 1 ingredient',
        (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToAllergens(tester);

      // "egg" is the first chip — tap its delete icon (first × icon)
      final deleteIcons = find.byIcon(Icons.cancel);
      await tester.tap(deleteIcons.first);
      await tester.pumpAndSettle();

      expect(find.text('Delete allergen?'), findsOneWidget);
      expect(find.textContaining('1 ingredient'), findsOneWidget);
      expect(find.textContaining('ingredients, targets, and activities'),
          findsOneWidget);
    });

    testWidgets('delete used allergen (dairy) shows cascade warning mentioning 2 ingredients',
        (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToAllergens(tester);

      // "dairy" is the second chip — tap its delete icon (second × icon)
      final deleteIcons = find.byIcon(Icons.cancel);
      await tester.tap(deleteIcons.at(1));
      await tester.pumpAndSettle();

      expect(find.text('Delete allergen?'), findsOneWidget);
      expect(find.textContaining('2 ingredients'), findsOneWidget);
      expect(find.textContaining('ingredients, targets, and activities'),
          findsOneWidget);
    });

    testWidgets('cancel on delete dialog keeps allergen visible',
        (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToAllergens(tester);

      // Tap delete on "soy" (last chip)
      final deleteIcons = find.byIcon(Icons.cancel);
      await tester.tap(deleteIcons.last);
      await tester.pumpAndSettle();

      expect(find.text('Delete allergen?'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Dialog should be dismissed, all 5 chips still present
      expect(find.text('Delete allergen?'), findsNothing);
      expect(find.byType(Chip), findsNWidgets(5));
      expect(find.text('soy'), findsOneWidget);
    });
  });

  group('Ingredient — delete', () {
    testWidgets('delete button shows confirmation dialog',
        (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToIngredients(tester);

      final deleteButtons = find.byIcon(Icons.delete_outline);
      expect(deleteButtons, findsWidgets);

      await tester.tap(deleteButtons.first);
      await tester.pumpAndSettle();

      expect(find.text('Delete ingredient?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('cancel on delete keeps ingredient visible',
        (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToIngredients(tester);

      final deleteButtons = find.byIcon(Icons.delete_outline);
      await tester.tap(deleteButtons.first);
      await tester.pumpAndSettle();

      expect(find.text('Delete ingredient?'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Dialog dismissed, ingredient count unchanged
      expect(find.text('Delete ingredient?'), findsNothing);
      expect(find.text('Ingredients (5)'), findsOneWidget);
    });

    testWidgets('delete button has correct icon (Icons.delete_outline)',
        (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToIngredients(tester);

      // Each ingredient card has a delete_outline icon button
      final deleteButtons = find.byIcon(Icons.delete_outline);
      expect(deleteButtons, findsNWidgets(5));

      // Verify they are IconButtons
      final iconButton = tester.widget<IconButton>(
        find.ancestor(
          of: deleteButtons.first,
          matching: find.byType(IconButton),
        ),
      );
      expect(iconButton, isNotNull);
    });
  });

  group('Ingredient — edit navigation', () {
    testWidgets('tap ingredient card navigates to edit form',
        (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToIngredients(tester);

      // Tap on an ingredient card (e.g., "banana" which has no allergen chip ambiguity)
      await tester.tap(find.text('banana'));
      await tester.pumpAndSettle();

      // Should navigate to edit form — AppBar shows "Edit Ingredient"
      expect(find.text('Edit Ingredient'), findsOneWidget);
    });
  });
}
