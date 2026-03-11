import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:datababe/sync/sync_engine_interface.dart';
import 'test_harness.dart';

void main() {
  final harness = TestHarness();

  setUp(harness.setUp);
  tearDown(harness.tearDown);

  group('Settings', () {
    testWidgets('account section: user info displayed', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Test User'), findsOneWidget);
      expect(find.text('test@example.com'), findsOneWidget);
    });

    testWidgets('account section: Sign Out tile', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Sign Out'), findsOneWidget);
      expect(find.byIcon(Icons.logout), findsOneWidget);
    });

    testWidgets('data section: all tiles present', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Manage Allergens'), findsOneWidget);
      expect(find.text('Manage Ingredients'), findsOneWidget);

      // Scroll to see remaining tiles
      await tester.scrollUntilVisible(
        find.text('Restore Backup'),
        200,
        scrollable: find.byType(Scrollable).last,
      );

      expect(find.text('Manage Recipes'), findsOneWidget);
      expect(find.text('Goals'), findsOneWidget);
      expect(find.text('Import CSV'), findsOneWidget);
      expect(find.text('Export Backup'), findsOneWidget);
      expect(find.text('Restore Backup'), findsOneWidget);
    });

    testWidgets('sync section: Sync Now tile', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Scroll to sync section
      await tester.scrollUntilVisible(
        find.text('Sync Now'),
        200,
        scrollable: find.byType(Scrollable).last,
      );

      expect(find.text('Sync Now'), findsOneWidget);
      expect(find.byIcon(Icons.sync), findsOneWidget);
    });

    testWidgets('sync section: status shows "Synced" when idle',
        (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester,
          harness.buildApp(initialSyncStatus: SyncStatus.idle));

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Scroll to sync section
      await tester.scrollUntilVisible(
        find.text('Sync Now'),
        200,
        scrollable: find.byType(Scrollable).last,
      );

      expect(find.textContaining('Synced'), findsOneWidget);
    });

    testWidgets('diagnostics tile visible', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Scroll to diagnostics
      await tester.scrollUntilVisible(
        find.text('Diagnostics'),
        200,
        scrollable: find.byType(Scrollable).last,
      );

      expect(find.text('Diagnostics'), findsOneWidget);
      expect(find.text('Check local DB state'), findsOneWidget);
      expect(find.byIcon(Icons.bug_report), findsOneWidget);
    });

    testWidgets('navigate to Manage Allergens', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Manage Allergens'));
      await tester.pumpAndSettle();

      // ManageAllergensScreen AppBar title
      expect(find.text('Manage Allergens'), findsWidgets);
    });

    testWidgets('navigate to Goals', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());

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

      expect(find.text('Goals'), findsWidgets);
    });

    testWidgets('sync dot reflects idle status', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester,
          harness.buildApp(initialSyncStatus: SyncStatus.idle));

      // Navigate to settings to ensure shell is visible
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Green dot for idle status
      final dotFinder = find.byWidgetPredicate((widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).shape == BoxShape.circle &&
          (widget.decoration as BoxDecoration).color == Colors.green);
      expect(dotFinder, findsOneWidget);
    });

    testWidgets('section headers visible', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Account'), findsOneWidget);
      expect(find.text('Data'), findsOneWidget);

      // Scroll to Sync section
      await tester.scrollUntilVisible(
        find.text('Sync'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Sync'), findsOneWidget);
    });
  });
}
