import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:datababe/import/import_preview.dart';
import 'package:datababe/import/csv_parser.dart';
import 'package:datababe/models/activity_model.dart';
import 'package:datababe/models/enums.dart';
import 'package:datababe/screens/import/import_preview_screen.dart';

void main() {
  final now = DateTime(2026, 3, 10, 10, 0);

  ActivityModel makeModel(String id, ActivityType type, DateTime time,
      {double? volumeMl, String? feedType, String? foodDescription}) {
    return ActivityModel(
      id: id,
      childId: 'child-1',
      type: type.name,
      startTime: time,
      createdAt: now,
      modifiedAt: now,
      volumeMl: volumeMl,
      feedType: feedType,
      foodDescription: foodDescription,
    );
  }

  ImportCandidate newCandidate(
    int row,
    ActivityType type,
    DateTime time, {
    double? volumeMl,
    String? feedType,
    String? foodDescription,
  }) {
    return ImportCandidate(
      rowNumber: row,
      status: CandidateStatus.newActivity,
      model: makeModel('new-$row', type, time,
          volumeMl: volumeMl,
          feedType: feedType,
          foodDescription: foodDescription),
      parsed: ParsedActivity(type: type, startTime: time),
      type: type,
      startTime: time,
    );
  }

  ImportCandidate dupCandidate(
      int row, ActivityType type, DateTime time) {
    return ImportCandidate(
      rowNumber: row,
      status: CandidateStatus.duplicate,
      model: makeModel('dup-$row', type, time),
      parsed: ParsedActivity(type: type, startTime: time),
      type: type,
      startTime: time,
    );
  }

  ImportCandidate errCandidate(int row, String reason) {
    return ImportCandidate(
      rowNumber: row,
      status: CandidateStatus.parseError,
      error: ParseError(rowNumber: row, rawType: 'Bad', reason: reason),
    );
  }

  ImportPreview buildPreview(List<ImportCandidate> candidates) {
    return ImportPreview(
      candidates: candidates,
      childId: 'child-1',
      familyId: 'fam-1',
    );
  }

  /// Pump the ImportPreviewScreen wrapped in a minimal app with GoRouter.
  Future<void> pumpPreviewScreen(
      WidgetTester tester, ImportPreview preview) async {
    final router = GoRouter(
      initialLocation: '/import/preview',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/import/preview',
          builder: (context, state) =>
              ImportPreviewScreen(preview: preview),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  group('Rendering', () {
    testWidgets('summary card shows correct counts', (tester) async {
      final preview = buildPreview([
        newCandidate(1, ActivityType.feedBottle, DateTime(2026, 3, 10, 8, 0),
            volumeMl: 120, feedType: 'formula'),
        newCandidate(2, ActivityType.solids, DateTime(2026, 3, 10, 10, 0),
            foodDescription: 'banana'),
        dupCandidate(3, ActivityType.feedBottle, DateTime(2026, 3, 10, 12, 0)),
        errCandidate(4, 'unknown type'),
      ]);

      await pumpPreviewScreen(tester, preview);

      expect(find.textContaining('4 rows'), findsOneWidget);
      expect(find.textContaining('2 new'), findsOneWidget);
      expect(find.textContaining('1 duplicates'), findsOneWidget);
      expect(find.textContaining('1 errors'), findsOneWidget);
    });

    testWidgets('new tab shows correct number of items', (tester) async {
      final preview = buildPreview([
        newCandidate(1, ActivityType.feedBottle, DateTime(2026, 3, 10, 8, 0)),
        newCandidate(2, ActivityType.solids, DateTime(2026, 3, 10, 10, 0)),
        newCandidate(3, ActivityType.diaper, DateTime(2026, 3, 10, 12, 0)),
      ]);

      await pumpPreviewScreen(tester, preview);

      // The "New (3)" tab should be selected by default.
      expect(find.text('New (3)'), findsOneWidget);
      // All 3 items should be rendered as CheckboxListTile.
      expect(find.byType(CheckboxListTile), findsNWidgets(3));
    });

    testWidgets('duplicates tab shows correct number of items',
        (tester) async {
      final preview = buildPreview([
        newCandidate(1, ActivityType.feedBottle, DateTime(2026, 3, 10, 8, 0)),
        dupCandidate(2, ActivityType.solids, DateTime(2026, 3, 10, 10, 0)),
        dupCandidate(3, ActivityType.diaper, DateTime(2026, 3, 10, 12, 0)),
      ]);

      await pumpPreviewScreen(tester, preview);

      // Switch to Duplicates tab.
      await tester.tap(find.text('Duplicates (2)'));
      await tester.pumpAndSettle();

      expect(find.text('Duplicate'), findsNWidgets(2));
    });

    testWidgets('errors tab shows row number and reason', (tester) async {
      final preview = buildPreview([
        errCandidate(5, 'unknown type: Foo'),
        errCandidate(12, 'invalid date'),
      ]);

      await pumpPreviewScreen(tester, preview);

      // Switch to Errors tab.
      await tester.tap(find.text('Errors (2)'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Row 5'), findsOneWidget);
      expect(find.textContaining('unknown type: Foo'), findsOneWidget);
      expect(find.textContaining('Row 12'), findsOneWidget);
      expect(find.textContaining('invalid date'), findsOneWidget);
    });

    testWidgets('import button shows "Import All (N)" by default',
        (tester) async {
      final preview = buildPreview([
        newCandidate(1, ActivityType.feedBottle, DateTime(2026, 3, 10, 8, 0)),
        newCandidate(2, ActivityType.solids, DateTime(2026, 3, 10, 10, 0)),
      ]);

      await pumpPreviewScreen(tester, preview);

      expect(find.text('Import All (2)'), findsOneWidget);
    });
  });

  group('Filter controls', () {
    testWidgets('filter bar is collapsed by default', (tester) async {
      final preview = buildPreview([
        newCandidate(1, ActivityType.feedBottle, DateTime(2026, 3, 10, 8, 0)),
      ]);

      await pumpPreviewScreen(tester, preview);

      expect(find.text('Filters'), findsOneWidget);
      // Filter chips should not be visible (collapsed).
      expect(find.byType(FilterChip), findsNothing);
    });

    testWidgets('expanding shows type chips', (tester) async {
      final preview = buildPreview([
        newCandidate(1, ActivityType.feedBottle, DateTime(2026, 3, 10, 8, 0)),
        newCandidate(2, ActivityType.solids, DateTime(2026, 3, 10, 10, 0)),
      ]);

      await pumpPreviewScreen(tester, preview);

      // Expand filter bar.
      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();

      expect(find.byType(FilterChip), findsNWidgets(2));
      expect(find.text('Bottle Feed'), findsOneWidget);
      expect(find.text('Solids'), findsOneWidget);
    });

    testWidgets('type chips correspond to presentTypes from preview',
        (tester) async {
      final preview = buildPreview([
        newCandidate(1, ActivityType.feedBottle, DateTime(2026, 3, 10, 8, 0)),
        newCandidate(2, ActivityType.diaper, DateTime(2026, 3, 10, 10, 0)),
        newCandidate(3, ActivityType.bath, DateTime(2026, 3, 10, 12, 0)),
      ]);

      await pumpPreviewScreen(tester, preview);

      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();

      expect(find.byType(FilterChip), findsNWidgets(3));
    });

    testWidgets('toggling a type chip updates filtered count',
        (tester) async {
      final preview = buildPreview([
        newCandidate(1, ActivityType.feedBottle, DateTime(2026, 3, 10, 8, 0)),
        newCandidate(2, ActivityType.solids, DateTime(2026, 3, 10, 10, 0)),
        newCandidate(3, ActivityType.diaper, DateTime(2026, 3, 10, 12, 0)),
      ]);

      await pumpPreviewScreen(tester, preview);

      // Initially: Import All (3).
      expect(find.text('Import All (3)'), findsOneWidget);

      // Expand and toggle off one type.
      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();

      // Tap the "Diaper" chip to exclude it.
      await tester.tap(find.text('Diaper'));
      await tester.pumpAndSettle();

      // Now should be 2 remaining, and tab says New (2).
      expect(find.text('New (2)'), findsOneWidget);
      expect(find.text('Import All (2)'), findsOneWidget);
    });

    testWidgets('clearing filters restores original count',
        (tester) async {
      final preview = buildPreview([
        newCandidate(1, ActivityType.feedBottle, DateTime(2026, 3, 10, 8, 0)),
        newCandidate(2, ActivityType.solids, DateTime(2026, 3, 10, 10, 0)),
      ]);

      await pumpPreviewScreen(tester, preview);

      // Expand and toggle off one type.
      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bottle Feed'));
      await tester.pumpAndSettle();
      expect(find.text('New (1)'), findsOneWidget);

      // Toggle it back on.
      await tester.tap(find.text('Bottle Feed'));
      await tester.pumpAndSettle();
      expect(find.text('New (2)'), findsOneWidget);
    });
  });

  group('Selection', () {
    testWidgets('all new candidates have checkboxes checked by default',
        (tester) async {
      final preview = buildPreview([
        newCandidate(1, ActivityType.feedBottle, DateTime(2026, 3, 10, 8, 0)),
        newCandidate(2, ActivityType.solids, DateTime(2026, 3, 10, 10, 0)),
      ]);

      await pumpPreviewScreen(tester, preview);

      final checkboxes = tester.widgetList<CheckboxListTile>(
          find.byType(CheckboxListTile));
      for (final cb in checkboxes) {
        expect(cb.value, isTrue);
      }
    });

    testWidgets(
        'unchecking a candidate changes button to "Import Selected (N-1)"',
        (tester) async {
      final preview = buildPreview([
        newCandidate(1, ActivityType.feedBottle, DateTime(2026, 3, 10, 8, 0)),
        newCandidate(2, ActivityType.solids, DateTime(2026, 3, 10, 10, 0)),
        newCandidate(3, ActivityType.diaper, DateTime(2026, 3, 10, 12, 0)),
      ]);

      await pumpPreviewScreen(tester, preview);

      // Uncheck the first item.
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pump();

      expect(find.text('Import Selected (2)'), findsOneWidget);
    });

    testWidgets('Select All / Deselect All toggle works', (tester) async {
      final preview = buildPreview([
        newCandidate(1, ActivityType.feedBottle, DateTime(2026, 3, 10, 8, 0)),
        newCandidate(2, ActivityType.solids, DateTime(2026, 3, 10, 10, 0)),
      ]);

      await pumpPreviewScreen(tester, preview);

      // Initially all selected → button says "Deselect All".
      expect(find.text('Deselect All'), findsOneWidget);

      // Tap Deselect All.
      await tester.tap(find.text('Deselect All'));
      await tester.pump();

      // All deselected → button label changes to "Select All".
      expect(find.text('Select All'), findsOneWidget);
      expect(find.text('Import Selected (0)'), findsOneWidget);

      // Tap Select All.
      await tester.tap(find.text('Select All'));
      await tester.pump();

      expect(find.text('Deselect All'), findsOneWidget);
      expect(find.text('Import All (2)'), findsOneWidget);
    });

    testWidgets('duplicate/error rows are not selectable', (tester) async {
      final preview = buildPreview([
        newCandidate(1, ActivityType.feedBottle, DateTime(2026, 3, 10, 8, 0)),
        dupCandidate(2, ActivityType.solids, DateTime(2026, 3, 10, 10, 0)),
        errCandidate(3, 'unknown type'),
      ]);

      await pumpPreviewScreen(tester, preview);

      // New tab: should have 1 checkbox.
      expect(find.byType(CheckboxListTile), findsOneWidget);

      // Duplicates tab: no checkboxes.
      await tester.tap(find.text('Duplicates (1)'));
      await tester.pumpAndSettle();
      expect(find.byType(CheckboxListTile), findsNothing);

      // Errors tab: no checkboxes.
      await tester.tap(find.text('Errors (1)'));
      await tester.pumpAndSettle();
      expect(find.byType(CheckboxListTile), findsNothing);
    });
  });

  group('Import flow', () {
    testWidgets('cancel button returns to previous screen', (tester) async {
      final preview = buildPreview([
        newCandidate(1, ActivityType.feedBottle, DateTime(2026, 3, 10, 8, 0)),
      ]);

      // Start at '/' and push to '/import/preview' so there's a nav stack.
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                const Scaffold(body: Text('Home')),
          ),
          GoRoute(
            path: '/import/preview',
            builder: (context, state) =>
                ImportPreviewScreen(preview: preview),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();

      // Navigate to the preview screen.
      router.push('/import/preview');
      await tester.pumpAndSettle();

      // Verify we're on the preview screen.
      expect(find.text('Import Preview'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Should navigate back to home.
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('all-duplicates preview disables import button',
        (tester) async {
      final preview = buildPreview([
        dupCandidate(1, ActivityType.feedBottle, DateTime(2026, 3, 10, 8, 0)),
        dupCandidate(2, ActivityType.solids, DateTime(2026, 3, 10, 10, 0)),
      ]);

      await pumpPreviewScreen(tester, preview);

      // The import button should show 0 and be disabled.
      final importButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Import All (0)'),
      );
      expect(importButton.onPressed, isNull);
    });

    testWidgets('all deselected disables import button', (tester) async {
      final preview = buildPreview([
        newCandidate(1, ActivityType.feedBottle, DateTime(2026, 3, 10, 8, 0)),
        newCandidate(2, ActivityType.solids, DateTime(2026, 3, 10, 10, 0)),
      ]);

      await pumpPreviewScreen(tester, preview);

      // Deselect all.
      await tester.tap(find.text('Deselect All'));
      await tester.pump();

      final importButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Import Selected (0)'),
      );
      expect(importButton.onPressed, isNull);
    });

    testWidgets('empty new tab after filter shows disabled import',
        (tester) async {
      final preview = buildPreview([
        newCandidate(1, ActivityType.feedBottle, DateTime(2026, 3, 10, 8, 0)),
      ]);

      await pumpPreviewScreen(tester, preview);

      // Expand filters and exclude the only type.
      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bottle Feed'));
      await tester.pumpAndSettle();

      final importButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Import All (0)'),
      );
      expect(importButton.onPressed, isNull);
    });
  });
}
