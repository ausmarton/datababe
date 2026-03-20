import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:datababe/models/activity_model.dart';
import 'package:datababe/widgets/allergen_matrix.dart';
import 'package:datababe/widgets/progress_ring.dart';
import 'package:datababe/widgets/trend_chart.dart';

import 'test_harness.dart';

/// Activities with dates relative to DateTime.now() so computed providers work.
List<ActivityModel> _recentMultiDayActivities() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final activities = <ActivityModel>[];

  // Today: feeds, diaper, solids with allergens, growth, tummy time
  activities.add(ActivityModel(
    id: 'today-bottle',
    childId: 'c1',
    type: 'feedBottle',
    startTime: today.add(const Duration(hours: 8)),
    feedType: 'formula',
    volumeMl: 120.0,
    createdAt: today.add(const Duration(hours: 8)),
    modifiedAt: today.add(const Duration(hours: 8)),
  ));
  activities.add(ActivityModel(
    id: 'today-breast',
    childId: 'c1',
    type: 'feedBreast',
    startTime: today.add(const Duration(hours: 6)),
    rightBreastMinutes: 10,
    leftBreastMinutes: 8,
    createdAt: today.add(const Duration(hours: 6)),
    modifiedAt: today.add(const Duration(hours: 6)),
  ));
  activities.add(ActivityModel(
    id: 'today-diaper',
    childId: 'c1',
    type: 'diaper',
    startTime: today.add(const Duration(hours: 9)),
    contents: 'both',
    contentSize: 'medium',
    pooColour: 'yellow',
    pooConsistency: 'soft',
    createdAt: today.add(const Duration(hours: 9)),
    modifiedAt: today.add(const Duration(hours: 9)),
  ));
  activities.add(ActivityModel(
    id: 'today-solids',
    childId: 'c1',
    type: 'solids',
    startTime: today.add(const Duration(hours: 10)),
    foodDescription: 'scrambled eggs',
    ingredientNames: ['egg', 'milk'],
    allergenNames: ['egg', 'dairy'],
    createdAt: today.add(const Duration(hours: 10)),
    modifiedAt: today.add(const Duration(hours: 10)),
  ));
  activities.add(ActivityModel(
    id: 'today-growth',
    childId: 'c1',
    type: 'growth',
    startTime: today.add(const Duration(hours: 7)),
    weightKg: 8.5,
    lengthCm: 72.0,
    headCircumferenceCm: 45.0,
    createdAt: today.add(const Duration(hours: 7)),
    modifiedAt: today.add(const Duration(hours: 7)),
  ));
  activities.add(ActivityModel(
    id: 'today-tummy',
    childId: 'c1',
    type: 'tummyTime',
    startTime: today.add(const Duration(hours: 5)),
    durationMinutes: 15,
    createdAt: today.add(const Duration(hours: 5)),
    modifiedAt: today.add(const Duration(hours: 5)),
  ));

  // Today: night sleep + nap
  activities.add(ActivityModel(
    id: 'today-night-sleep',
    childId: 'c1',
    type: 'sleep',
    startTime: today.subtract(const Duration(hours: 4)), // ~8pm previous day
    endTime: today.add(const Duration(hours: 2)),
    durationMinutes: 360,
    createdAt: today,
    modifiedAt: today,
  ));
  activities.add(ActivityModel(
    id: 'today-nap',
    childId: 'c1',
    type: 'sleep',
    startTime: today.add(const Duration(hours: 13)),
    endTime: today.add(const Duration(hours: 14)),
    durationMinutes: 60,
    createdAt: today,
    modifiedAt: today,
  ));

  // 7 previous days of data (for baselines and trends)
  for (int day = 1; day <= 7; day++) {
    final pastDay = today.subtract(Duration(days: day));
    final dayAt8 = pastDay.add(const Duration(hours: 8));
    activities.add(ActivityModel(
      id: 'day$day-bottle',
      childId: 'c1',
      type: 'feedBottle',
      startTime: dayAt8,
      feedType: 'formula',
      volumeMl: 100.0 + day * 10,
      createdAt: dayAt8,
      modifiedAt: dayAt8,
    ));
    activities.add(ActivityModel(
      id: 'day$day-diaper',
      childId: 'c1',
      type: 'diaper',
      startTime: dayAt8.add(const Duration(hours: 1)),
      contents: 'pee',
      contentSize: 'medium',
      createdAt: dayAt8,
      modifiedAt: dayAt8,
    ));
    activities.add(ActivityModel(
      id: 'day$day-tummy',
      childId: 'c1',
      type: 'tummyTime',
      startTime: dayAt8.add(const Duration(hours: 2)),
      durationMinutes: 10 + day,
      createdAt: dayAt8,
      modifiedAt: dayAt8,
    ));
    activities.add(ActivityModel(
      id: 'day$day-solids',
      childId: 'c1',
      type: 'solids',
      startTime: dayAt8.add(const Duration(hours: 3)),
      foodDescription: 'food day $day',
      ingredientNames: ['egg'],
      allergenNames: ['egg'],
      createdAt: dayAt8,
      modifiedAt: dayAt8,
    ));
  }

  return activities;
}

void main() {
  final harness = TestHarness();

  setUp(harness.setUp);
  tearDown(harness.tearDown);

  Future<void> navigateToInsights(WidgetTester tester) async {
    await tester.tap(find.text('Insights'));
    await tester.pumpAndSettle();
  }

  Future<void> scrollToVisible(WidgetTester tester, Finder target) async {
    await tester.dragUntilVisible(
      target,
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
  }

  group('Insights — empty state', () {
    testWidgets('shows empty message when no activities', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());
      await navigateToInsights(tester);

      expect(find.text('Insights'), findsWidgets);
      expect(find.text('No insights yet'), findsOneWidget);
      expect(find.text('Start Logging'), findsOneWidget);
    });
  });

  group('Insights — section visibility', () {
    testWidgets('shows Insights title and Goals button', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToInsights(tester);

      expect(find.text('Insights'), findsWidgets);
      expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
    });

    testWidgets('period selector present with Day/Week/Month',
        (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToInsights(tester);

      expect(find.text('Day'), findsOneWidget);
      expect(find.text('Week'), findsOneWidget);
      expect(find.text('Month'), findsOneWidget);
    });

    testWidgets('default period is Last 7 days', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToInsights(tester);

      // Appears in period selector and progress subtitle
      expect(find.text('Last 7 days'), findsWidgets);
    });

    testWidgets('Progress section visible with period label',
        (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToInsights(tester);

      expect(find.text('Progress'), findsOneWidget);
    });

    testWidgets('Feeding Overview section visible with feeds',
        (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _recentMultiDayActivities();
      await pumpApp(tester, harness.buildApp());
      await navigateToInsights(tester);

      await scrollToVisible(tester, find.text('Feeding Overview'));
      expect(find.text('Feeding Overview'), findsOneWidget);
      expect(find.textContaining('Bottle'), findsWidgets);
    });

    testWidgets('Sleep Overview section visible with sleep data',
        (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _recentMultiDayActivities();
      await pumpApp(tester, harness.buildApp());
      await navigateToInsights(tester);

      await scrollToVisible(tester, find.text('Sleep Overview'));
      expect(find.text('Sleep Overview'), findsOneWidget);
      expect(find.textContaining('Night'), findsWidgets);
      expect(find.textContaining('Naps'), findsWidgets);
      expect(find.textContaining('Longest stretch'), findsOneWidget);
      expect(find.textContaining('Avg wakings'), findsOneWidget);
    });

    testWidgets('Allergen Tracker section visible', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToInsights(tester);

      expect(find.text('Allergen Tracker'), findsOneWidget);
    });

    testWidgets('Weekly allergen section shows week range label',
        (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToInsights(tester);

      await scrollToVisible(tester, find.text('Exposed'));
      // The matrix section should show a date range like "10 Mar – 16 Mar"
      // instead of "This Week"
      expect(find.text('Exposed'), findsOneWidget);
      // Should NOT find "This Week" anymore
      expect(find.text('This Week'), findsNothing);
    });

    testWidgets('Trends section shows metric selectors', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToInsights(tester);

      await scrollToVisible(tester, find.text('Trends'));
      expect(find.text('Trends'), findsOneWidget);
      expect(find.text('Feed Volume'), findsOneWidget);
    });

    testWidgets('Trends section shows period toggles', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToInsights(tester);

      await scrollToVisible(tester, find.text('Trends'));
      // 30d appears in both the trend section and possibly period selector
      expect(find.text('30d'), findsWidgets);
    });

    testWidgets('Growth section shows latest measurements', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToInsights(tester);

      await scrollToVisible(tester, find.text('Growth'));
      expect(find.text('Growth'), findsOneWidget);
      // TestData has growth: 8.5kg, 72.0cm, 45.0cm
      expect(find.text('8.5kg'), findsOneWidget);
      expect(find.text('72.0cm'), findsOneWidget);
      expect(find.text('45.0cm'), findsOneWidget);
    });

    testWidgets('Growth section shows labels', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToInsights(tester);

      await scrollToVisible(tester, find.text('Weight'));
      expect(find.text('Weight'), findsOneWidget);
      expect(find.text('Length'), findsOneWidget);
      expect(find.text('Head'), findsOneWidget);
    });
  });

  group('Insights — period selector interaction', () {
    testWidgets('changing to Day mode updates period label', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToInsights(tester);

      // Default is "Last 7 days" (Week rolling)
      expect(find.text('Last 7 days'), findsWidgets);

      // Tap Day button
      await tester.tap(find.text('Day'));
      await tester.pumpAndSettle();

      // Should show "Last 24 hours" (rolling day)
      expect(find.text('Last 24 hours'), findsWidgets);
      expect(find.text('Last 7 days'), findsNothing);
    });

    testWidgets('changing to Month mode updates period label',
        (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToInsights(tester);

      await tester.tap(find.text('Month'));
      await tester.pumpAndSettle();

      // Appears in period selector and progress subtitle
      expect(find.text('Last 30 days'), findsWidgets);
    });

    testWidgets('switching to calendar mode shows navigation arrows',
        (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToInsights(tester);

      // Toggle to calendar mode
      await tester.tap(find.text('Rolling'));
      await tester.pumpAndSettle();

      // Should show navigation arrows
      expect(find.byIcon(Icons.chevron_left), findsWidgets);
    });
  });

  group('Insights — with one activity', () {
    testWidgets('shows allergen tracker with single non-solids activity',
        (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      harness.activities = [TestData.todayActivities().first];
      await pumpApp(tester, harness.buildApp());
      await navigateToInsights(tester);

      expect(find.text('Allergen Tracker'), findsOneWidget);
    });
  });

  // --- Data-content tests: verify providers compute real values ---

  group('Insights — Progress section with real-time data', () {
    testWidgets('shows ProgressRing widgets with targets', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _recentMultiDayActivities();
      await pumpApp(tester, harness.buildApp());
      await navigateToInsights(tester);

      // insightsProgressProvider should compute metrics from recent activities
      expect(find.byType(ProgressRing), findsWidgets);
    });

    testWidgets('ProgressRings not showing empty state', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _recentMultiDayActivities();
      await pumpApp(tester, harness.buildApp());
      await navigateToInsights(tester);

      // With recent data, should NOT show "Log a few more days..." message
      expect(find.text('Log a few more days to see progress tracking'),
          findsNothing);
    });
  });

  group('Insights — Allergen Tracker data', () {
    testWidgets('shows coverage count with recent allergen data',
        (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _recentMultiDayActivities();
      await pumpApp(tester, harness.buildApp());
      await navigateToInsights(tester);

      // Today's solids has egg+dairy allergens. Family has 5 categories.
      // Allergen Tracker section shows "N/M covered" text
      expect(find.textContaining('covered'), findsWidgets);
    });

    testWidgets('shows allergen period toggle (7d/14d)', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _recentMultiDayActivities();
      await pumpApp(tester, harness.buildApp());
      await navigateToInsights(tester);

      expect(find.text('7d'), findsWidgets);
      expect(find.text('14d'), findsWidgets);
    });
  });

  group('Insights — Weekly Allergen Matrix data', () {
    testWidgets('shows AllergenMatrix widget with exposure data',
        (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _recentMultiDayActivities();
      await pumpApp(tester, harness.buildApp());
      await navigateToInsights(tester);

      await scrollToVisible(tester, find.text('Exposed'));
      expect(find.byType(AllergenMatrix), findsOneWidget);
    });

    testWidgets('shows allergen names in matrix', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _recentMultiDayActivities();
      await pumpApp(tester, harness.buildApp());
      await navigateToInsights(tester);

      await scrollToVisible(tester, find.text('Exposed'));
      // "egg" should appear in the matrix (exposed this week)
      expect(find.text('egg'), findsWidgets);
    });

    testWidgets('matrix section has week navigation arrows', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _recentMultiDayActivities();
      await pumpApp(tester, harness.buildApp());
      await navigateToInsights(tester);

      await scrollToVisible(tester, find.text('Exposed'));
      // Matrix section has its own chevron_left for week navigation
      expect(find.byIcon(Icons.chevron_left), findsWidgets);
    });
  });

  group('Insights — Trend chart data', () {
    testWidgets('shows TrendChart with bar data', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _recentMultiDayActivities();
      await pumpApp(tester, harness.buildApp());
      await navigateToInsights(tester);

      await scrollToVisible(tester, find.text('Trends'));
      expect(find.byType(TrendChart), findsOneWidget);
      expect(find.byType(BarChart), findsOneWidget);
    });

    testWidgets('trend chart not showing "No data" with activities',
        (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _recentMultiDayActivities();
      await pumpApp(tester, harness.buildApp());
      await navigateToInsights(tester);

      await scrollToVisible(tester, find.text('Trends'));
      // TrendChart shows "No data" when data is empty — should NOT appear
      expect(find.text('No data'), findsNothing);
    });
  });

  group('Insights — Growth section data', () {
    testWidgets('shows growth values with recent data', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _recentMultiDayActivities();
      await pumpApp(tester, harness.buildApp());
      await navigateToInsights(tester);

      await scrollToVisible(tester, find.text('Growth'));
      expect(find.text('8.5kg'), findsOneWidget);
      expect(find.text('72.0cm'), findsOneWidget);
      expect(find.text('45.0cm'), findsOneWidget);
    });

    testWidgets('shows chevron indicating tappable', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _recentMultiDayActivities();
      await pumpApp(tester, harness.buildApp());
      await navigateToInsights(tester);

      await scrollToVisible(tester, find.text('Growth'));
      expect(find.byIcon(Icons.chevron_right), findsWidgets);
    });
  });
}
