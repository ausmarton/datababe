import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_harness.dart';

void main() {
  final harness = TestHarness();

  setUp(harness.setUp);
  tearDown(harness.tearDown);

  /// Navigate to Settings and scroll until [target] is visible.
  Future<void> goToSettingsAndScrollTo(
    WidgetTester tester,
    Finder target,
  ) async {
    await tester.runAsync(() => harness.seedMinimal());
    await pumpApp(tester, harness.buildApp());

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
  }

  group('Backup — Export', () {
    testWidgets('Export Backup tile visible with correct title, subtitle, icon',
        (tester) async {
      await goToSettingsAndScrollTo(tester, find.text('Export Backup'));

      expect(find.text('Export Backup'), findsOneWidget);
      expect(find.text('Save family data as JSON'), findsOneWidget);
      expect(find.byIcon(Icons.file_download), findsOneWidget);
    });

    testWidgets('Export Backup tile is tappable', (tester) async {
      await goToSettingsAndScrollTo(tester, find.text('Export Backup'));

      final tile = find.widgetWithText(ListTile, 'Export Backup');
      await tester.ensureVisible(tile);
      await tester.pump();

      // Tap the tile. The async _exportBackup method runs, which either
      // shows "No family selected" or an "Exporting..." dialog followed
      // by a platform error. Use bounded pump to avoid hanging on
      // infinite animations (CircularProgressIndicator).
      await tester.tap(tile);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // If a family IS selected (auto-selection from seed), the
      // "Exporting..." dialog with CircularProgressIndicator appears.
      // If no family is selected, a SnackBar appears.
      // Either way, the tile responded to the tap and we are still
      // on a valid screen.
      final exportingDialog = find.text('Exporting...');
      final noFamilySnackbar = find.text('No family selected');
      expect(
        exportingDialog.evaluate().isNotEmpty ||
            noFamilySnackbar.evaluate().isNotEmpty,
        isTrue,
        reason:
            'Tapping Export Backup should show Exporting dialog or No family SnackBar',
      );
    });
  });

  group('Backup — Restore', () {
    testWidgets(
        'Restore Backup tile visible with correct title, subtitle, icon',
        (tester) async {
      await goToSettingsAndScrollTo(tester, find.text('Restore Backup'));

      expect(find.text('Restore Backup'), findsOneWidget);
      expect(find.text('Merge data from a JSON backup'), findsOneWidget);
      expect(find.byIcon(Icons.restore), findsOneWidget);
    });

    testWidgets('Restore Backup tile opens confirmation dialog',
        (tester) async {
      await goToSettingsAndScrollTo(tester, find.text('Restore Backup'));

      final tile = find.widgetWithText(ListTile, 'Restore Backup');
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();

      await tester.tap(tile);
      await tester.pumpAndSettle();

      // The restore flow shows a confirmation dialog first (before file picker).
      expect(find.text('Restore backup'), findsOneWidget);
      expect(
        find.text(
          'This will merge backup data into your current family. '
          'Newer records win.',
        ),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });
  });

  group('Backup — Settings data section', () {
    testWidgets('Export and Restore tiles both visible after scrolling',
        (tester) async {
      await goToSettingsAndScrollTo(tester, find.text('Restore Backup'));

      expect(find.text('Export Backup'), findsOneWidget);
      expect(find.text('Restore Backup'), findsOneWidget);
    });

    testWidgets('complete Data section tiles all present', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      final scrollable = find.byType(Scrollable).last;

      // Verify each Data section tile by scrolling to it in order.
      // Top tiles are visible first; later ones require scrolling.
      const dataTiles = [
        'Manage Allergens',
        'Manage Ingredients',
        'Manage Recipes',
        'Goals',
        'Import CSV',
        'Export Backup',
        'Restore Backup',
      ];

      for (final title in dataTiles) {
        await tester.scrollUntilVisible(
          find.text(title),
          200,
          scrollable: scrollable,
        );
        await tester.pumpAndSettle();
        expect(find.text(title), findsOneWidget, reason: '$title not found');
      }
    });
  });

  group('Backup — layout', () {
    testWidgets('Export Backup appears before Restore Backup in list',
        (tester) async {
      await goToSettingsAndScrollTo(tester, find.text('Restore Backup'));

      // Find the vertical positions of both tiles — Export should be above
      // Restore (smaller dy value).
      final exportTile = find.widgetWithText(ListTile, 'Export Backup');
      final restoreTile = find.widgetWithText(ListTile, 'Restore Backup');

      expect(exportTile, findsOneWidget);
      expect(restoreTile, findsOneWidget);

      final exportRect = tester.getRect(exportTile);
      final restoreRect = tester.getRect(restoreTile);

      expect(exportRect.top, lessThan(restoreRect.top),
          reason: 'Export Backup should appear above Restore Backup');
    });

    testWidgets('both tiles have correct icons', (tester) async {
      await goToSettingsAndScrollTo(tester, find.text('Restore Backup'));

      // Verify file_download icon is present (for Export Backup)
      final exportIcon = find.byIcon(Icons.file_download);
      expect(exportIcon, findsOneWidget);

      // Verify restore icon is present (for Restore Backup)
      final restoreIcon = find.byIcon(Icons.restore);
      expect(restoreIcon, findsOneWidget);

      // Verify the icons belong to the correct ListTiles by checking that
      // the file_download icon is an ancestor of the Export tile row and
      // restore is an ancestor of the Restore tile row.
      final exportTile = find.ancestor(
        of: find.text('Export Backup'),
        matching: find.byType(ListTile),
      );
      final restoreTileWidget = find.ancestor(
        of: find.text('Restore Backup'),
        matching: find.byType(ListTile),
      );

      // The icon should be a descendant of its respective ListTile
      expect(
        find.descendant(of: exportTile, matching: find.byIcon(Icons.file_download)),
        findsOneWidget,
      );
      expect(
        find.descendant(
            of: restoreTileWidget, matching: find.byIcon(Icons.restore)),
        findsOneWidget,
      );
    });
  });
}
