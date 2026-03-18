import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:datababe/models/activity_model.dart';
import 'package:datababe/widgets/activity_tile.dart';
import 'package:datababe/widgets/trend_chart.dart';

import 'test_harness.dart';

/// Activities spread across multiple days so trend data and baselines populate.
/// Uses explicit DateTime construction to avoid midnight boundary issues.
List<ActivityModel> _multiDayActivities() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final activities = <ActivityModel>[];

  // Today's feeds — use explicit hours safely within today
  activities.add(ActivityModel(
    id: 'today-bottle-1',
    childId: 'c1',
    type: 'feedBottle',
    startTime: today.add(const Duration(hours: 8)),
    feedType: 'formula',
    volumeMl: 120.0,
    createdAt: today.add(const Duration(hours: 8)),
    modifiedAt: today.add(const Duration(hours: 8)),
  ));
  activities.add(ActivityModel(
    id: 'today-bottle-2',
    childId: 'c1',
    type: 'feedBottle',
    startTime: today.add(const Duration(hours: 10)),
    feedType: 'formula',
    volumeMl: 150.0,
    createdAt: today.add(const Duration(hours: 10)),
    modifiedAt: today.add(const Duration(hours: 10)),
  ));
  // Today's diaper
  activities.add(ActivityModel(
    id: 'today-diaper-1',
    childId: 'c1',
    type: 'diaper',
    startTime: today.add(const Duration(hours: 9)),
    contents: 'pee',
    contentSize: 'medium',
    createdAt: today.add(const Duration(hours: 9)),
    modifiedAt: today.add(const Duration(hours: 9)),
  ));
  // Today's tummy time
  activities.add(ActivityModel(
    id: 'today-tummy',
    childId: 'c1',
    type: 'tummyTime',
    startTime: today.add(const Duration(hours: 7)),
    durationMinutes: 15,
    createdAt: today.add(const Duration(hours: 7)),
    modifiedAt: today.add(const Duration(hours: 7)),
  ));

  // Activities for 7 previous days (to establish baselines)
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
      contents: 'both',
      contentSize: 'medium',
      pooColour: 'yellow',
      pooConsistency: 'soft',
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

  group('Metric Detail — explicit target', () {
    testWidgets('shows Feed Vol. detail with day progress heading',
        (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _multiDayActivities();
      await pumpApp(tester, harness.buildApp());

      // Navigate directly to metric detail for feedBottle.totalVolumeMl.daily
      final router =
          GoRouter.of(tester.element(find.byType(Scaffold).first));
      router.push(
          '/insights/metric/${Uri.encodeComponent('feedBottle.totalVolumeMl.daily')}');
      await tester.pumpAndSettle();

      // Title should show "Today's Progress" with day navigation
      expect(find.text("Today's Progress"), findsOneWidget);
    });

    testWidgets('shows actual volume and target info', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _multiDayActivities();
      await pumpApp(tester, harness.buildApp());

      final router =
          GoRouter.of(tester.element(find.byType(Scaffold).first));
      router.push(
          '/insights/metric/${Uri.encodeComponent('feedBottle.totalVolumeMl.daily')}');
      await tester.pumpAndSettle();

      // Should show actual ml value (120 + 150 = 270ml)
      expect(find.text('270ml'), findsOneWidget);
      // Target is 600ml
      expect(find.textContaining('600ml'), findsOneWidget);
    });

    testWidgets('shows progress bar', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _multiDayActivities();
      await pumpApp(tester, harness.buildApp());

      final router =
          GoRouter.of(tester.element(find.byType(Scaffold).first));
      router.push(
          '/insights/metric/${Uri.encodeComponent('feedBottle.totalVolumeMl.daily')}');
      await tester.pumpAndSettle();

      expect(find.byType(LinearProgressIndicator), findsWidgets);
    });

    testWidgets('shows today entries section with filtered activities',
        (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _multiDayActivities();
      await pumpApp(tester, harness.buildApp());

      final router =
          GoRouter.of(tester.element(find.byType(Scaffold).first));
      router.push(
          '/insights/metric/${Uri.encodeComponent('feedBottle.totalVolumeMl.daily')}');
      await tester.pumpAndSettle();

      expect(find.text("Today's Entries"), findsOneWidget);
      // Should show ActivityTile for today's bottle feeds
      expect(find.byType(ActivityTile), findsWidgets);
    });

    testWidgets('shows prev/next day navigation arrows', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _multiDayActivities();
      await pumpApp(tester, harness.buildApp());

      final router =
          GoRouter.of(tester.element(find.byType(Scaffold).first));
      router.push(
          '/insights/metric/${Uri.encodeComponent('feedBottle.totalVolumeMl.daily')}');
      await tester.pumpAndSettle();

      // Should have prev/next arrows
      expect(find.byIcon(Icons.chevron_left), findsWidgets);
      expect(find.byIcon(Icons.chevron_right), findsWidgets);
    });

    testWidgets('navigating to previous day changes label to Yesterday',
        (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _multiDayActivities();
      await pumpApp(tester, harness.buildApp());

      final router =
          GoRouter.of(tester.element(find.byType(Scaffold).first));
      router.push(
          '/insights/metric/${Uri.encodeComponent('feedBottle.totalVolumeMl.daily')}');
      await tester.pumpAndSettle();

      // Tap the prev arrow (first chevron_left in the _DateNavRow)
      final prevArrows = find.byIcon(Icons.chevron_left);
      await tester.tap(prevArrows.first);
      await tester.pumpAndSettle();

      expect(find.text("Yesterday's Progress"), findsOneWidget);
      expect(find.text("Yesterday's Entries"), findsOneWidget);
    });

    testWidgets('shows 7-day and 30-day trend cards', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _multiDayActivities();
      await pumpApp(tester, harness.buildApp());

      final router =
          GoRouter.of(tester.element(find.byType(Scaffold).first));
      router.push(
          '/insights/metric/${Uri.encodeComponent('feedBottle.totalVolumeMl.daily')}');
      await tester.pumpAndSettle();

      await tester.dragUntilVisible(
        find.text('7-day trend'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      expect(find.text('7-day trend'), findsOneWidget);

      await tester.dragUntilVisible(
        find.text('30-day trend'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      expect(find.text('30-day trend'), findsOneWidget);
    });

    testWidgets('shows TrendChart widgets (bar charts)', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _multiDayActivities();
      await pumpApp(tester, harness.buildApp());

      final router =
          GoRouter.of(tester.element(find.byType(Scaffold).first));
      router.push(
          '/insights/metric/${Uri.encodeComponent('feedBottle.totalVolumeMl.daily')}');
      await tester.pumpAndSettle();

      // Scroll to make trend charts visible
      await tester.dragUntilVisible(
        find.text('30-day trend'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TrendChart), findsWidgets);
      expect(find.byType(BarChart), findsWidgets);
    });

    testWidgets('shows Target section with Edit button', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _multiDayActivities();
      await pumpApp(tester, harness.buildApp());

      final router =
          GoRouter.of(tester.element(find.byType(Scaffold).first));
      router.push(
          '/insights/metric/${Uri.encodeComponent('feedBottle.totalVolumeMl.daily')}');
      await tester.pumpAndSettle();

      // Scroll to Target section at the bottom
      await tester.dragUntilVisible(
        find.text('Target'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();

      expect(find.text('Target'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
    });
  });

  group('Metric Detail — inferred baseline', () {
    testWidgets('shows inferred diaper metric with avg label', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _multiDayActivities();
      await pumpApp(tester, harness.buildApp());

      // Diaper has no explicit target → should use inferred baseline
      final router =
          GoRouter.of(tester.element(find.byType(Scaffold).first));
      router.push(
          '/insights/metric/${Uri.encodeComponent('diaper.count.daily')}');
      await tester.pumpAndSettle();

      expect(find.text("Today's Progress"), findsOneWidget);
      // Should show "avg" label for inferred baseline
      expect(find.textContaining('avg'), findsOneWidget);
    });

    testWidgets('shows "Set an explicit goal" button for inferred',
        (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _multiDayActivities();
      await pumpApp(tester, harness.buildApp());

      final router =
          GoRouter.of(tester.element(find.byType(Scaffold).first));
      router.push(
          '/insights/metric/${Uri.encodeComponent('diaper.count.daily')}');
      await tester.pumpAndSettle();

      // Scroll to bottom for target info
      await tester.dragUntilVisible(
        find.text('Set an explicit goal'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();

      expect(find.text('Set an explicit goal'), findsOneWidget);
    });
  });

  group('Metric Detail — no data today', () {
    testWidgets('shows no data message for unknown metric', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _multiDayActivities();
      await pumpApp(tester, harness.buildApp());

      // Navigate to a metric key that doesn't exist in progress
      final router =
          GoRouter.of(tester.element(find.byType(Scaffold).first));
      router.push(
          '/insights/metric/${Uri.encodeComponent('nonexistent.metric.daily')}');
      await tester.pumpAndSettle();

      expect(find.text('No data for this day'), findsOneWidget);
    });
  });
}
