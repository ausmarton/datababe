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

  /// Type into the ingredient autocomplete field and wait for options overlay.
  Future<void> typeIngredientQuery(
      WidgetTester tester, String query) async {
    // The autocomplete's TextFormField has labelText 'Add ingredient'
    final field = find.widgetWithText(TextFormField, 'Add ingredient');
    expect(field, findsOneWidget);
    await tester.enterText(field, query);
    await tester.pumpAndSettle();
  }

  group('Inline Ingredient Creation', () {
    testWidgets('typing unknown ingredient shows Create option',
        (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToSolids(tester);

      // Type an ingredient name that doesn't exist in the seed data
      await typeIngredientQuery(tester, 'avocado');

      // The autocomplete dropdown should show '+ Create "avocado"'
      expect(find.text('+ Create "avocado"'), findsOneWidget);
    });

    testWidgets('tapping Create opens dialog with allergen chips',
        (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToSolids(tester);

      await typeIngredientQuery(tester, 'avocado');

      // Tap the Create option in the autocomplete dropdown
      await tester.tap(find.text('+ Create "avocado"'));
      await tester.pumpAndSettle();

      // A dialog should appear with the ingredient name in the title
      expect(find.text('Create "avocado"'), findsOneWidget);

      // The dialog should show 'Allergen categories:' label
      expect(find.text('Allergen categories:'), findsOneWidget);

      // Family has 5 allergen categories: egg, dairy, peanut, wheat, soy
      // They appear as FilterChips in the dialog
      expect(find.byType(FilterChip), findsNWidgets(5));
      expect(find.text('egg'), findsOneWidget);
      expect(find.text('dairy'), findsOneWidget);
      expect(find.text('peanut'), findsOneWidget);
      expect(find.text('wheat'), findsOneWidget);
      expect(find.text('soy'), findsOneWidget);

      // Dialog has Cancel and Create buttons
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Create'), findsOneWidget);
    });

    testWidgets(
        'creating ingredient adds it to activity ingredient chip list',
        (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToSolids(tester);

      await typeIngredientQuery(tester, 'avocado');

      // Tap the Create option
      await tester.tap(find.text('+ Create "avocado"'));
      await tester.pumpAndSettle();

      // Dialog is open — tap Create button to create the ingredient
      final createButton = find.widgetWithText(FilledButton, 'Create');
      expect(createButton, findsOneWidget);
      await tester.tap(createButton);
      // Use runAsync to let the async Sembast write complete
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();

      // The dialog should have closed
      expect(find.text('Create "avocado"'), findsNothing);

      // The ingredient 'avocado' should now appear as a Chip in the form
      expect(find.widgetWithText(Chip, 'avocado'), findsOneWidget);
    });

    testWidgets(
        'created ingredient allergens appear in allergen warning section',
        (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToSolids(tester);

      await typeIngredientQuery(tester, 'avocado');

      // Tap Create option
      await tester.tap(find.text('+ Create "avocado"'));
      await tester.pumpAndSettle();

      // In the dialog, select 'peanut' and 'soy' allergen categories
      await tester.tap(find.widgetWithText(FilterChip, 'peanut'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'soy'));
      await tester.pumpAndSettle();

      // Tap Create to save the ingredient with allergens
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      // Let the async Sembast write + stream propagation complete
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
      await tester.pumpAndSettle();
      // Extra pump to let ingredient stream update + allergens recompute
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
      await tester.pumpAndSettle();

      // Dialog should be closed
      expect(find.text('Create "avocado"'), findsNothing);

      // The ingredient chip should be present
      expect(find.widgetWithText(Chip, 'avocado'), findsOneWidget);

      // Allergen warning chips show the selected allergen categories
      expect(find.text('peanut'), findsWidgets);
      expect(find.text('soy'), findsWidgets);
    });
  });
}
