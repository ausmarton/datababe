import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:datababe/models/activity_model.dart';

import 'test_harness.dart';

/// Multiple growth entries spread across dates so charts have data points.
List<ActivityModel> _growthActivities() {
  final now = DateTime.now();
  return [
    // Feed to prevent empty insights screen
    ActivityModel(
      id: 'feed1',
      childId: 'c1',
      type: 'feedBottle',
      startTime: now.subtract(const Duration(hours: 2)),
      feedType: 'formula',
      volumeMl: 120.0,
      createdAt: now,
      modifiedAt: now,
    ),
    // Growth entry from 2 weeks ago
    ActivityModel(
      id: 'g1',
      childId: 'c1',
      type: 'growth',
      startTime: now.subtract(const Duration(days: 14)),
      weightKg: 7.8,
      lengthCm: 69.0,
      headCircumferenceCm: 43.5,
      createdAt: now.subtract(const Duration(days: 14)),
      modifiedAt: now.subtract(const Duration(days: 14)),
    ),
    // Growth entry from 1 week ago
    ActivityModel(
      id: 'g2',
      childId: 'c1',
      type: 'growth',
      startTime: now.subtract(const Duration(days: 7)),
      weightKg: 8.1,
      lengthCm: 70.5,
      headCircumferenceCm: 44.2,
      createdAt: now.subtract(const Duration(days: 7)),
      modifiedAt: now.subtract(const Duration(days: 7)),
    ),
    // Latest growth entry (today)
    ActivityModel(
      id: 'g3',
      childId: 'c1',
      type: 'growth',
      startTime: now.subtract(const Duration(hours: 1)),
      weightKg: 8.5,
      lengthCm: 72.0,
      headCircumferenceCm: 45.0,
      createdAt: now,
      modifiedAt: now,
    ),
  ];
}

void main() {
  final harness = TestHarness();

  setUp(harness.setUp);
  tearDown(harness.tearDown);

  Future<void> navigateToGrowthDetail(WidgetTester tester) async {
    // Navigate to Insights tab
    await tester.tap(find.text('Insights'));
    await tester.pumpAndSettle();

    // Scroll to Growth section and tap it
    final growthFinder = find.text('Growth');
    await tester.dragUntilVisible(
      growthFinder,
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    await tester.tap(growthFinder);
    await tester.pumpAndSettle();
  }

  group('Growth Detail — empty state', () {
    testWidgets('shows empty message when no growth entries', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      // Provide a non-growth activity so insights screen doesn't show empty state
      final now = DateTime.now();
      harness.activities = [
        ActivityModel(
          id: 'feed1',
          childId: 'c1',
          type: 'feedBottle',
          startTime: now.subtract(const Duration(hours: 1)),
          feedType: 'formula',
          volumeMl: 120.0,
          createdAt: now,
          modifiedAt: now,
        ),
      ];
      await pumpApp(tester, harness.buildApp());

      // Navigate to insights then push /insights/growth directly
      await tester.tap(find.text('Insights'));
      await tester.pumpAndSettle();

      // Growth section won't appear (no growth entries), so navigate directly
      final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
      router.push('/insights/growth');
      await tester.pumpAndSettle();

      expect(find.text('No growth entries yet'), findsOneWidget);
    });
  });

  group('Growth Detail — with data', () {
    testWidgets('shows Growth title', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _growthActivities();
      await pumpApp(tester, harness.buildApp());
      await navigateToGrowthDetail(tester);

      // AppBar should show "Growth"
      expect(find.text('Growth'), findsWidgets);
    });

    testWidgets('shows latest weight, length, head values', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _growthActivities();
      await pumpApp(tester, harness.buildApp());
      await navigateToGrowthDetail(tester);

      expect(find.text('8.5kg'), findsOneWidget);
      expect(find.text('72.0cm'), findsOneWidget);
      expect(find.text('45.0cm'), findsOneWidget);
    });

    testWidgets('shows stat labels', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _growthActivities();
      await pumpApp(tester, harness.buildApp());
      await navigateToGrowthDetail(tester);

      expect(find.text('Weight'), findsWidgets);
      expect(find.text('Length'), findsWidgets);
      expect(find.text('Head'), findsWidgets);
    });

    testWidgets('shows delta from previous measurement', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _growthActivities();
      await pumpApp(tester, harness.buildApp());
      await navigateToGrowthDetail(tester);

      // Delta: 8.5 - 8.1 = +0.4kg
      expect(find.text('+0.4kg'), findsOneWidget);
      // Delta: 72.0 - 70.5 = +1.5cm
      expect(find.text('+1.5cm'), findsOneWidget);
      // Delta: 45.0 - 44.2 = +0.8cm
      expect(find.text('+0.8cm'), findsOneWidget);
    });

    testWidgets('shows filter chips for Weight, Length, Head', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _growthActivities();
      await pumpApp(tester, harness.buildApp());
      await navigateToGrowthDetail(tester);

      expect(find.byType(FilterChip), findsNWidgets(3));
    });

    testWidgets('shows line charts with data', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _growthActivities();
      await pumpApp(tester, harness.buildApp());
      await navigateToGrowthDetail(tester);

      // At least some LineChart widgets should be visible
      expect(find.byType(LineChart), findsWidgets);

      // Scroll to see more charts
      await tester.dragUntilVisible(
        find.text('Head circumference (cm)'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      expect(find.text('Head circumference (cm)'), findsOneWidget);
    });

    testWidgets('shows chart labels', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _growthActivities();
      await pumpApp(tester, harness.buildApp());
      await navigateToGrowthDetail(tester);

      expect(find.text('Weight (kg)'), findsOneWidget);

      // Scroll to see more labels
      await tester.dragUntilVisible(
        find.text('Length (cm)'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      expect(find.text('Length (cm)'), findsOneWidget);
    });

    testWidgets('shows WHO percentile labels on stats', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _growthActivities();
      await pumpApp(tester, harness.buildApp());
      await navigateToGrowthDetail(tester);

      // Child DOB is set in TestData (~6 months old), so percentiles should appear
      // Look for any "P" + number text indicating percentile
      expect(find.textContaining(RegExp(r'P\d+')), findsWidgets);
    });

    testWidgets('shows WHO percentiles label on chart', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _growthActivities();
      await pumpApp(tester, harness.buildApp());
      await navigateToGrowthDetail(tester);

      expect(find.text('WHO percentiles'), findsWidgets);
    });

    testWidgets('shows percentile legend below chart', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _growthActivities();
      await pumpApp(tester, harness.buildApp());
      await navigateToGrowthDetail(tester);

      expect(find.textContaining('50th (median)'), findsWidgets);
    });

    testWidgets('toggling filter chip hides corresponding chart',
        (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _growthActivities();
      await pumpApp(tester, harness.buildApp());
      await navigateToGrowthDetail(tester);

      // Weight chart should be visible
      expect(find.text('Weight (kg)'), findsOneWidget);

      // Find and tap the Weight FilterChip to deselect it
      final weightChip = find.widgetWithText(FilterChip, 'Weight');
      await tester.tap(weightChip.first);
      await tester.pumpAndSettle();

      // Weight chart label should disappear
      expect(find.text('Weight (kg)'), findsNothing);
      // Length chart should still be visible
      expect(find.text('Length (cm)'), findsOneWidget);
    });
  });
}
