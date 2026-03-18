import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:datababe/models/activity_model.dart';
import 'package:datababe/widgets/activity_tile.dart';
import 'package:datababe/widgets/summary_card.dart';

import 'test_harness.dart';

/// Activities with dates relative to DateTime.now() so summary providers work.
List<ActivityModel> _recentActivities() {
  final now = DateTime.now();
  return [
    ActivityModel(
      id: 'a1',
      childId: 'c1',
      type: 'feedBottle',
      startTime: now.subtract(const Duration(hours: 2)),
      feedType: 'formula',
      volumeMl: 120.0,
      createdAt: now.subtract(const Duration(hours: 2)),
      modifiedAt: now.subtract(const Duration(hours: 2)),
    ),
    ActivityModel(
      id: 'a2',
      childId: 'c1',
      type: 'feedBreast',
      startTime: now.subtract(const Duration(hours: 4)),
      rightBreastMinutes: 10,
      leftBreastMinutes: 8,
      createdAt: now.subtract(const Duration(hours: 4)),
      modifiedAt: now.subtract(const Duration(hours: 4)),
    ),
    ActivityModel(
      id: 'a3',
      childId: 'c1',
      type: 'diaper',
      startTime: now.subtract(const Duration(hours: 3)),
      contents: 'both',
      contentSize: 'medium',
      pooColour: 'yellow',
      pooConsistency: 'soft',
      createdAt: now.subtract(const Duration(hours: 3)),
      modifiedAt: now.subtract(const Duration(hours: 3)),
    ),
    ActivityModel(
      id: 'a4',
      childId: 'c1',
      type: 'solids',
      startTime: now.subtract(const Duration(hours: 1)),
      foodDescription: 'scrambled eggs',
      reaction: 'loved',
      recipeId: 'r1',
      ingredientNames: ['egg', 'milk'],
      allergenNames: ['egg', 'dairy'],
      createdAt: now.subtract(const Duration(hours: 1)),
      modifiedAt: now.subtract(const Duration(hours: 1)),
    ),
    ActivityModel(
      id: 'a5',
      childId: 'c1',
      type: 'meds',
      startTime: now.subtract(const Duration(hours: 5)),
      medicationName: 'Vitamin D',
      dose: '5',
      doseUnit: 'drops',
      createdAt: now.subtract(const Duration(hours: 5)),
      modifiedAt: now.subtract(const Duration(hours: 5)),
    ),
    // Yesterday's activity
    ActivityModel(
      id: 'a6',
      childId: 'c1',
      type: 'feedBottle',
      startTime: now.subtract(const Duration(days: 1, hours: 3)),
      feedType: 'formula',
      volumeMl: 150.0,
      createdAt: now.subtract(const Duration(days: 1, hours: 3)),
      modifiedAt: now.subtract(const Duration(days: 1, hours: 3)),
    ),
  ];
}

void main() {
  final harness = TestHarness();

  setUp(harness.setUp);
  tearDown(harness.tearDown);

  Future<void> navigateToTimeline(WidgetTester tester) async {
    await tester.tap(find.text('Timeline'));
    await tester.pumpAndSettle();
  }

  group('Timeline — empty state', () {
    testWidgets('shows empty message when no activities', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());
      await navigateToTimeline(tester);

      expect(find.text('Timeline'), findsWidgets);
      expect(find.text('No activities in this period'), findsOneWidget);
    });
  });

  group('Timeline — with data', () {
    testWidgets('shows Timeline title and range selector', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _recentActivities();
      await pumpApp(tester, harness.buildApp());
      await navigateToTimeline(tester);

      expect(find.text('Timeline'), findsWidgets);
      // Range selector granularity buttons
      expect(find.text('Day'), findsOneWidget);
      expect(find.text('Week'), findsOneWidget);
      expect(find.text('Month'), findsOneWidget);
    });

    testWidgets('shows Calendar/Rolling toggle', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _recentActivities();
      await pumpApp(tester, harness.buildApp());
      await navigateToTimeline(tester);

      // Default is Calendar mode
      expect(find.text('Calendar'), findsOneWidget);
    });

    testWidgets('shows activity tiles', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _recentActivities();
      await pumpApp(tester, harness.buildApp());
      await navigateToTimeline(tester);

      expect(find.byType(ActivityTile), findsWidgets);
    });

    testWidgets('shows summary card with activities', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _recentActivities();
      await pumpApp(tester, harness.buildApp());
      await navigateToTimeline(tester);

      expect(find.byType(SummaryCard), findsOneWidget);
    });

    testWidgets('summary card shows total count', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _recentActivities();
      await pumpApp(tester, harness.buildApp());
      await navigateToTimeline(tester);

      // SummaryCard shows "N total" chip
      expect(find.textContaining('total'), findsOneWidget);
    });

    testWidgets('shows navigation arrows in calendar mode', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _recentActivities();
      await pumpApp(tester, harness.buildApp());
      await navigateToTimeline(tester);

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('shows filter button in AppBar', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _recentActivities();
      await pumpApp(tester, harness.buildApp());
      await navigateToTimeline(tester);

      expect(find.byIcon(Icons.filter_list), findsOneWidget);
    });

    testWidgets('shows bulk add button in AppBar', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _recentActivities();
      await pumpApp(tester, harness.buildApp());
      await navigateToTimeline(tester);

      expect(find.byIcon(Icons.playlist_add), findsOneWidget);
    });

    testWidgets('groups activities by date', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _recentActivities();
      await pumpApp(tester, harness.buildApp());
      await navigateToTimeline(tester);

      // Should show at least one date header
      expect(find.byType(Divider), findsWidgets);
    });

    testWidgets('target progress bars visible with targets', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _recentActivities();
      await pumpApp(tester, harness.buildApp());
      await navigateToTimeline(tester);

      // SummaryCard should show LinearProgressIndicator for target progress
      expect(find.byType(LinearProgressIndicator), findsWidgets);
    });
  });

  group('Timeline — no child', () {
    testWidgets('shows prompt when no child selected', (tester) async {
      await tester.runAsync(() => harness.setUp());
      harness.families = [];
      harness.children = [];
      await pumpApp(tester, harness.buildApp());
      // Navigate to Timeline tab
      await tester.tap(find.text('Timeline'));
      await tester.pumpAndSettle();

      expect(find.text('Please add a child first'), findsOneWidget);
    });
  });
}
