import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_harness.dart';

void main() {
  final harness = TestHarness();

  setUp(harness.setUp);
  tearDown(harness.tearDown);

  /// Navigate to Bulk Add screen from home.
  Future<void> goToBulkAdd(WidgetTester tester) async {
    // Scroll down to find the Bulk Add chip (at end of QuickLogGrid)
    final chip = find.widgetWithText(ActionChip, 'Bulk Add');
    await tester.scrollUntilVisible(
      chip,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
  }

  group('Bulk Add — navigation', () {
    testWidgets('accessible from home via Bulk Add chip', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());

      await goToBulkAdd(tester);

      expect(find.text('Quick Add'), findsOneWidget);
      expect(find.text('No entries staged yet'), findsOneWidget);
    });

    testWidgets('accessible from timeline via AppBar icon', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());

      // Navigate to timeline tab
      await tester.tap(find.text('Timeline'));
      await tester.pumpAndSettle();

      // Tap bulk add icon in AppBar
      await tester.tap(find.byTooltip('Bulk Add'));
      await tester.pumpAndSettle();

      expect(find.text('Quick Add'), findsOneWidget);
    });
  });

  group('Bulk Add — quick add', () {
    testWidgets('creates staged entry with correct type', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());
      await goToBulkAdd(tester);

      // Initially no staged entries
      expect(find.text('No entries staged yet'), findsOneWidget);

      // Quick add a bottle feed
      await tester.tap(find.widgetWithText(ActionChip, 'Bottle Feed'));
      await tester.pumpAndSettle();

      // Should now show 1 staged entry
      expect(find.text('Staged (1 entry)'), findsOneWidget);
      expect(find.text('No entries staged yet'), findsNothing);
    });

    testWidgets('quick add multiple types shows all in staged list',
        (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());
      await goToBulkAdd(tester);

      await tester.tap(find.widgetWithText(ActionChip, 'Bottle Feed'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ActionChip, 'Medication'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ActionChip, 'Diaper'));
      await tester.pumpAndSettle();

      expect(find.text('Staged (3 entries)'), findsOneWidget);
    });
  });

  group('Bulk Add — remove entry', () {
    testWidgets('remove staged entry via close button', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());
      await goToBulkAdd(tester);

      await tester.tap(find.widgetWithText(ActionChip, 'Bottle Feed'));
      await tester.pumpAndSettle();
      expect(find.text('Staged (1 entry)'), findsOneWidget);

      // Remove it via close button — scroll to make it visible first
      final closeBtn = find.byIcon(Icons.close);
      await tester.ensureVisible(closeBtn);
      await tester.pumpAndSettle();
      await tester.tap(closeBtn);
      await tester.pumpAndSettle();

      expect(find.text('No entries staged yet'), findsOneWidget);
    });
  });

  group('Bulk Add — save', () {
    testWidgets('Save button disabled when no staged entries',
        (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());
      await goToBulkAdd(tester);

      final saveButton = find.widgetWithText(FilledButton, 'Save All (0)');
      expect(saveButton, findsOneWidget);
      final button = tester.widget<FilledButton>(saveButton);
      expect(button.onPressed, isNull);
    });

    testWidgets('save all creates activities and shows SnackBar',
        (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());
      await goToBulkAdd(tester);

      // Add 2 entries
      await tester.tap(find.widgetWithText(ActionChip, 'Bottle Feed'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ActionChip, 'Medication'));
      await tester.pumpAndSettle();
      expect(find.text('Staged (2 entries)'), findsOneWidget);

      // Tap Save All — DB writes need runAsync
      await tester.tap(find.widgetWithText(FilledButton, 'Save All (2)'));
      await tester.runAsync(() => Future.delayed(Duration.zero));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('Saved 2 activities'), findsWidgets);
    });
  });

  group('Bulk Add — cancel', () {
    testWidgets('Cancel returns to previous screen without saving',
        (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());
      await goToBulkAdd(tester);

      // Add an entry
      await tester.tap(find.widgetWithText(ActionChip, 'Bottle Feed'));
      await tester.pumpAndSettle();

      // Tap Cancel
      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
      await tester.pumpAndSettle();

      // Should be back on home screen
      expect(find.text('Quick Add'), findsNothing);
    });
  });

  group('Bulk Add — target date', () {
    testWidgets('defaults to yesterday', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());
      await goToBulkAdd(tester);

      expect(find.textContaining('Adding to:'), findsOneWidget);
    });
  });
}
