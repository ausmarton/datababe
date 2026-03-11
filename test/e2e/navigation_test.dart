import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:datababe/sync/sync_engine_interface.dart';
import 'test_harness.dart';

void main() {
  final harness = TestHarness();

  setUp(harness.setUp);
  tearDown(harness.tearDown);

  group('Navigation', () {
    testWidgets('bottom nav shows 5 labeled destinations', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Timeline'), findsOneWidget);
      expect(find.text('Insights'), findsOneWidget);
      expect(find.text('Family'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('home tab selected by default', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());

      // Child name visible on home screen
      expect(find.text('Baby'), findsWidgets);
    });

    testWidgets('tap Timeline → shows Timeline in AppBar', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());

      await tester.tap(find.text('Timeline'));
      await tester.pumpAndSettle();

      expect(find.text('Timeline'), findsWidgets);
    });

    testWidgets('tap Insights → shows Insights in AppBar', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());

      await tester.tap(find.text('Insights'));
      await tester.pumpAndSettle();

      expect(find.text('Insights'), findsWidgets);
    });

    testWidgets('tap Family → shows Family in AppBar', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());

      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();

      expect(find.text('Family'), findsWidgets);
    });

    testWidgets('tap Settings → shows Settings in AppBar', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsWidgets);
    });

    testWidgets('tap Home from Settings → returns to home', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      // Child name visible on home screen
      expect(find.text('Baby'), findsWidgets);
    });

    testWidgets('settings → Manage Allergens navigates', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Manage Allergens'));
      await tester.pumpAndSettle();

      expect(find.text('Manage Allergens'), findsWidgets);
    });

    testWidgets('settings → Manage Ingredients navigates', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Manage Ingredients'));
      await tester.pumpAndSettle();

      // Title includes count: "Ingredients (0)"
      expect(find.textContaining('Ingredients'), findsWidgets);
    });

    testWidgets('settings → Manage Recipes navigates', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());

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

      // Title includes count: "Recipes (0)"
      expect(find.textContaining('Recipes'), findsWidgets);
    });

    testWidgets('settings → Goals navigates', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Scroll the Goals tile into view and ensure it's tappable
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

      expect(find.text('Goals'), findsWidgets);
    });

    // --- Sync dot tests ---

    testWidgets('sync dot visible with idle status → green', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester,
          harness.buildApp(initialSyncStatus: SyncStatus.idle));

      // The sync dot is a 10x10 Container with BoxShape.circle
      final dotFinder = find.byWidgetPredicate((widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).shape == BoxShape.circle &&
          (widget.decoration as BoxDecoration).color == Colors.green);
      expect(dotFinder, findsOneWidget);
    });

    testWidgets('sync dot shows grey for offline', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester,
          harness.buildApp(initialSyncStatus: SyncStatus.offline));

      final dotFinder = find.byWidgetPredicate((widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).shape == BoxShape.circle &&
          (widget.decoration as BoxDecoration).color == Colors.grey);
      expect(dotFinder, findsOneWidget);
    });

    testWidgets('sync dot shows red for error', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester,
          harness.buildApp(initialSyncStatus: SyncStatus.error));

      final dotFinder = find.byWidgetPredicate((widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).shape == BoxShape.circle &&
          (widget.decoration as BoxDecoration).color == Colors.red);
      expect(dotFinder, findsOneWidget);
    });

    testWidgets('sync dot shows amber for syncing', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester,
          harness.buildApp(initialSyncStatus: SyncStatus.syncing));

      final dotFinder = find.byWidgetPredicate((widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).shape == BoxShape.circle &&
          (widget.decoration as BoxDecoration).color == Colors.amber);
      expect(dotFinder, findsOneWidget);
    });

    testWidgets('nested modal: Ingredients → Add FAB', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Manage Ingredients'));
      await tester.pumpAndSettle();

      // Tap FAB on IngredientListScreen
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Should show AddIngredientScreen
      expect(find.text('New Ingredient'), findsOneWidget);
    });
  });
}
