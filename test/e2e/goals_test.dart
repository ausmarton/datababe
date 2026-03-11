import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_harness.dart';

void main() {
  final harness = TestHarness();

  setUp(harness.setUp);
  tearDown(harness.tearDown);

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

  group('Goals', () {
    testWidgets('empty state: no goals set yet', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());
      await navigateToGoals(tester);

      expect(find.textContaining('No goals set yet'), findsOneWidget);
    });

    testWidgets('allergen goals section header', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToGoals(tester);

      // The allergen targets have period "weekly"
      expect(find.text('Allergen Goals (weekly)'), findsOneWidget);
    });

    testWidgets('other goals section header', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToGoals(tester);

      expect(find.text('Other Goals'), findsOneWidget);
    });

    testWidgets('aggregate progress text visible', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToGoals(tester);

      // Shows "X/Y on track" for allergen group
      expect(find.textContaining('on track'), findsOneWidget);
    });

    testWidgets('LinearProgressIndicator visible', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToGoals(tester);

      expect(find.byType(LinearProgressIndicator), findsWidgets);
    });

    testWidgets('expand/collapse allergen list', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToGoals(tester);

      // Initially collapsed — "Show all" visible
      expect(find.text('Show all'), findsOneWidget);
      expect(find.text('Hide'), findsNothing);

      // Tap to expand
      await tester.tap(find.text('Show all'));
      await tester.pumpAndSettle();

      // Now expanded — "Hide" visible, allergen names visible
      expect(find.text('Hide'), findsOneWidget);
      expect(find.text('Show all'), findsNothing);
      expect(find.text('egg'), findsWidgets);
      expect(find.text('dairy'), findsWidgets);

      // Collapse again
      await tester.tap(find.text('Hide'));
      await tester.pumpAndSettle();

      expect(find.text('Show all'), findsOneWidget);
    });

    testWidgets('other goals render as Cards', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToGoals(tester);

      // Other goals: solids count (daily), bottle volume (daily), tummy time duration (daily)
      expect(find.byType(Card), findsWidgets);
    });

    testWidgets('FAB opens AddTargetScreen', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToGoals(tester);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.text('Add Goal'), findsOneWidget);
    });

    testWidgets('bulk allergen targets button in AppBar', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToGoals(tester);

      expect(find.byIcon(Icons.playlist_add), findsOneWidget);
    });

    testWidgets('edit button navigates to bulk allergens', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToGoals(tester);

      // Edit button on allergen goal section
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Allergen'), findsWidgets);
    });

    testWidgets('delete goal shows confirmation dialog', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToGoals(tester);

      // Find a delete button on one of the "Other Goals" cards
      final deleteButtons = find.byIcon(Icons.delete_outline);
      expect(deleteButtons, findsWidgets);

      await tester.tap(deleteButtons.first);
      await tester.pumpAndSettle();

      expect(find.text('Delete goal?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('goals title in AppBar', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());
      await navigateToGoals(tester);

      expect(find.text('Goals'), findsWidgets);
    });
  });
}
