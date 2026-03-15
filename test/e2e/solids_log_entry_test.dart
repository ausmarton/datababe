import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_harness.dart';

void main() {
  final harness = TestHarness();

  setUp(harness.setUp);
  tearDown(harness.tearDown);

  Future<void> navigateToSolids(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(ActionChip, 'Solids'));
    await tester.pumpAndSettle();
  }

  group('Solids Log Entry', () {
    testWidgets('Pick a Recipe button visible with recipes', (tester) async {
      // seedFull has 3 recipes
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToSolids(tester);

      // Should see 'Pick a Recipe' button (enabled)
      expect(find.text('Pick a Recipe'), findsOneWidget);
      expect(find.byIcon(Icons.menu_book), findsOneWidget);
    });

    testWidgets('Pick a Recipe disabled when no recipes', (tester) async {
      // seedMinimal has no recipes
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());
      await navigateToSolids(tester);

      // Should see 'No recipes available' (disabled button)
      expect(find.text('No recipes available'), findsOneWidget);
    });

    testWidgets('recipe picker shows all seeded recipes', (tester) async {
      // seedFull has 3 recipes
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToSolids(tester);

      // Tap 'Pick a Recipe' to open bottom sheet
      await tester.tap(find.text('Pick a Recipe'));
      await tester.pumpAndSettle();

      // Bottom sheet shows all 3 recipes
      expect(find.text('scrambled eggs'), findsOneWidget);
      expect(find.text('toast with butter'), findsOneWidget);
      expect(find.text('banana mash'), findsOneWidget);
    });

    testWidgets('selecting recipe populates food description', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToSolids(tester);

      // Open recipe picker
      await tester.tap(find.text('Pick a Recipe'));
      await tester.pumpAndSettle();

      // Select 'scrambled eggs'
      await tester.tap(find.text('scrambled eggs'));
      await tester.pumpAndSettle();

      // Recipe chip should appear with menu_book icon
      expect(find.byIcon(Icons.menu_book), findsOneWidget);

      // Food description field should be populated
      final foodDescField = tester.widget<TextFormField>(
        find.byType(TextFormField).first,
      );
      expect(foodDescField.controller?.text, 'scrambled eggs');

      // Ingredients text should be visible below the chip
      expect(find.textContaining('ingredients'), findsOneWidget);
    });

    testWidgets('ingredient autocomplete field visible', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToSolids(tester);

      // Solids form shows 'Add ingredient' field
      expect(find.text('Add ingredient'), findsOneWidget);
      expect(find.text('Type to search or create ingredients'), findsOneWidget);
    });

    testWidgets('clear recipe button removes selection', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToSolids(tester);

      // Select a recipe first
      await tester.tap(find.text('Pick a Recipe'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('scrambled eggs'));
      await tester.pumpAndSettle();

      // Verify recipe chip is visible (the Chip with delete button)
      expect(find.widgetWithIcon(Chip, Icons.menu_book), findsOneWidget);

      // 'Pick a Recipe' button should be gone (replaced by chip)
      expect(find.text('Pick a Recipe'), findsNothing);

      // Tap the delete button on the chip to clear the recipe
      final deleteIcon = find.descendant(
        of: find.byType(Chip),
        matching: find.byIcon(Icons.cancel),
      );
      await tester.tap(deleteIcon);
      await tester.pumpAndSettle();

      // 'Pick a Recipe' button should reappear
      expect(find.text('Pick a Recipe'), findsOneWidget);
    });
  });
}
