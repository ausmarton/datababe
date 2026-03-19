import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_harness.dart';

void main() {
  final harness = TestHarness();

  setUp(harness.setUp);
  tearDown(harness.tearDown);

  // --- Navigation helpers ---

  Future<void> navigateToIngredients(WidgetTester tester) async {
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage Ingredients'));
    await tester.pumpAndSettle();
  }

  Future<void> navigateToRecipes(WidgetTester tester) async {
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Manage Recipes'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Manage Recipes'));
    await tester.pumpAndSettle();
  }

  Future<void> navigateToGoals(WidgetTester tester) async {
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    final goalsTile = find.widgetWithText(ListTile, 'Goals');
    await tester.scrollUntilVisible(
      goalsTile,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(goalsTile);
    await tester.pumpAndSettle();
    await tester.tap(goalsTile);
    await tester.pumpAndSettle();
  }

  // --- Empty state rendering ---

  group('Empty state rendering', () {
    testWidgets('home with no activities shows empty message', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());

      expect(find.text('No activities logged today'), findsOneWidget);
    });

    testWidgets('home with no families shows setup prompt', (tester) async {
      // No seed — empty database. Families list defaults to [] from setUp.
      await pumpApp(tester, harness.buildApp());

      expect(find.text('Welcome to DataBabe'), findsOneWidget);
      expect(find.text('Add your child to get started'), findsOneWidget);
    });

    testWidgets('timeline with no activities shows empty message',
        (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());

      await tester.tap(find.text('Timeline'));
      await tester.pumpAndSettle();

      expect(find.text('No activities in this period'), findsOneWidget);
    });

    testWidgets('insights with no data shows empty message', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());

      await tester.tap(find.text('Insights'));
      await tester.pumpAndSettle();

      expect(
        find.text('Start logging activities to see insights'),
        findsOneWidget,
      );
    });

    testWidgets('goals with no targets shows empty state', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());
      await navigateToGoals(tester);

      expect(find.textContaining('No goals set yet'), findsOneWidget);
    });

    testWidgets('ingredients with none shows empty state', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());
      await navigateToIngredients(tester);

      expect(find.textContaining('No ingredients yet'), findsOneWidget);
    });
  });

  // --- Form validation ---

  group('Form validation', () {
    testWidgets('add ingredient: save with empty name shows validation error',
        (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());
      await navigateToIngredients(tester);

      // Tap FAB to open add ingredient form
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Tap Save without entering a name
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Name is required'), findsOneWidget);
    });

    testWidgets('add recipe: save with empty name shows validation error',
        (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());
      await navigateToRecipes(tester);

      // Tap FAB to open add recipe form
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Tap Save without entering a name
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Name is required'), findsOneWidget);
    });
  });

  // --- Initial sync states ---

  group('Initial sync states', () {
    testWidgets('initial sync not complete shows spinner and syncing text',
        (tester) async {
      await pumpApp(
        tester,
        harness.buildApp(initialSyncComplete: false),
      );

      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(find.text('Syncing your data...'), findsOneWidget);
    });

    testWidgets('initial sync error shows snackbar with error message',
        (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(
        tester,
        harness.buildApp(
          initialSyncComplete: true,
          initialSyncError: 'Network error',
        ),
      );

      // The error is shown via a SnackBar scheduled in addPostFrameCallback.
      // Pump to allow the post-frame callback to fire.
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('Sync error'), findsOneWidget);
      expect(find.textContaining('Network error'), findsOneWidget);
    });
  });
}
