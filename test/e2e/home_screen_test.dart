import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_harness.dart';

void main() {
  final harness = TestHarness();

  setUp(harness.setUp);
  tearDown(harness.tearDown);

  group('Home screen', () {
    testWidgets('child name in app bar', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());

      // "Baby" appears in the SliverAppBar (and possibly elsewhere)
      expect(find.text('Baby'), findsWidgets);
    });

    testWidgets('quick-log grid: all 14 chips present', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());

      const chipLabels = [
        'Bottle Feed',
        'Breast Feed',
        'Diaper',
        'Medication',
        'Solids',
        'Growth',
        'Tummy Time',
        'Pump',
        'Temperature',
        'Bath',
        'Indoor Play',
        'Outdoor Play',
        'Skin to Skin',
        'Potty',
      ];

      for (final label in chipLabels) {
        expect(
          find.widgetWithText(ActionChip, label),
          findsOneWidget,
          reason: 'Expected ActionChip "$label" to be present',
        );
      }
    });

    testWidgets('tap Bottle Feed chip navigates to LogEntryScreen',
        (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());

      await tester.tap(find.widgetWithText(ActionChip, 'Bottle Feed'));
      await tester.pumpAndSettle();

      expect(find.text('Log Bottle Feed'), findsOneWidget);
    });

    testWidgets('tap Solids chip navigates to LogEntryScreen',
        (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());

      await tester.tap(find.widgetWithText(ActionChip, 'Solids'));
      await tester.pumpAndSettle();

      expect(find.text('Log Solids'), findsOneWidget);
    });

    testWidgets('Today section header visible', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());

      expect(find.text('Today'), findsOneWidget);
    });

    testWidgets('today shows activity tiles with descriptions',
        (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());

      // Verify activity tile display names are present (chip + tile)
      expect(find.text('Bottle Feed'), findsWidgets);
      expect(find.text('Solids'), findsWidgets);

      // Verify subtitle content from activity data.
      // Some tiles may be off-screen in the CustomScrollView, so scroll to
      // reveal them before asserting.
      final scrollable = find.byType(Scrollable).first;

      // feedBottle subtitle: "formula - 120ml"
      await tester.scrollUntilVisible(
        find.textContaining('120ml'),
        200,
        scrollable: scrollable,
      );
      expect(find.textContaining('120ml'), findsOneWidget);

      // solids subtitle: "scrambled eggs - 2 ingredients - 2 allergens - loved"
      await tester.scrollUntilVisible(
        find.textContaining('scrambled eggs'),
        200,
        scrollable: scrollable,
      );
      expect(find.textContaining('scrambled eggs'), findsOneWidget);

      // medication subtitle: "Vitamin D - 5"
      await tester.scrollUntilVisible(
        find.textContaining('Vitamin D'),
        200,
        scrollable: scrollable,
      );
      expect(find.textContaining('Vitamin D'), findsOneWidget);
    });

    testWidgets('empty today shows no-activities message', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());

      expect(find.text('No activities logged today'), findsOneWidget);
    });

    testWidgets('setup prompt when no families exist', (tester) async {
      // No seed data — empty database
      await pumpApp(tester, harness.buildApp());

      expect(find.text('Welcome to DataBabe'), findsOneWidget);
      expect(find.text('Add your child to get started'), findsOneWidget);
    });

    testWidgets('initial sync loading shows spinner', (tester) async {
      await pumpApp(tester, harness.buildApp(initialSyncComplete: false));

      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(find.text('Syncing your data...'), findsOneWidget);
    });
  });
}
