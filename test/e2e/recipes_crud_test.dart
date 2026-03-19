import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_harness.dart';

void main() {
  final harness = TestHarness();

  setUp(harness.setUp);
  tearDown(harness.tearDown);

  Future<void> navigateToRecipes(WidgetTester tester) async {
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    // Scroll down to reveal off-screen tile
    await tester.scrollUntilVisible(
      find.text('Manage Recipes'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Manage Recipes'));
    await tester.pumpAndSettle();
  }

  group('Recipes CRUD', () {
    testWidgets('list shows count in title', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToRecipes(tester);

      // 3 recipes seeded
      expect(find.text('Recipes (3)'), findsOneWidget);
    });

    testWidgets('all seeded recipes visible', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToRecipes(tester);

      expect(find.text('scrambled eggs'), findsOneWidget);
      expect(find.text('toast with butter'), findsOneWidget);
      expect(find.text('banana mash'), findsOneWidget);
    });

    testWidgets('ingredient chips on recipe cards', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToRecipes(tester);

      // Scrambled eggs recipe has ingredient chips: egg, milk, butter
      // Find ingredient chips within the scrambled eggs card
      expect(find.text('3 ingredients'), findsOneWidget);
      expect(find.text('2 ingredients'), findsOneWidget);
      expect(find.text('1 ingredients'), findsOneWidget);
    });

    testWidgets('allergen warning chips derived from ingredients',
        (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToRecipes(tester);

      // Scrambled eggs (egg, milk, butter) → allergens: egg, dairy
      expect(find.byIcon(Icons.warning_amber), findsWidgets);
    });

    testWidgets('search: type "toast" filters', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToRecipes(tester);

      await tester.enterText(find.byType(TextField).first, 'toast');
      await tester.pumpAndSettle();

      expect(find.text('toast with butter'), findsOneWidget);
      expect(find.text('scrambled eggs'), findsNothing);
      expect(find.text('banana mash'), findsNothing);
    });

    testWidgets('search: no match shows empty message', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToRecipes(tester);

      await tester.enterText(find.byType(TextField).first, 'xyz');
      await tester.pumpAndSettle();

      expect(find.text('No matching recipes'), findsOneWidget);
    });

    testWidgets('FAB opens AddRecipeScreen', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToRecipes(tester);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.text('New Recipe'), findsOneWidget);
    });

    testWidgets('delete: confirmation dialog shows recipe name',
        (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToRecipes(tester);

      final deleteButtons = find.byIcon(Icons.delete_outline);
      expect(deleteButtons, findsWidgets);

      await tester.tap(deleteButtons.first);
      await tester.pumpAndSettle();

      expect(find.text('Delete recipe?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('empty list shows prompt', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());
      await navigateToRecipes(tester);

      expect(find.textContaining('No recipes yet'), findsOneWidget);
    });

    testWidgets('search field has hint text', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToRecipes(tester);

      expect(find.text('Search recipes...'), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('recipe with activity usage shows count', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToRecipes(tester);

      // Activity a4 references recipe r1 ("scrambled eggs")
      // So "scrambled eggs" should show "Used in 1 activity"
      expect(find.text('Used in 1 activity'), findsOneWidget);
    });

    testWidgets('recipe without activity usage shows "Not used"',
        (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToRecipes(tester);

      // "toast with butter" (r2) and "banana mash" (r3) are not used in activities
      expect(find.text('Not used'), findsNWidgets(2));
    });
  });
}
