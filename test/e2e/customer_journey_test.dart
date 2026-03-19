import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:datababe/models/activity_model.dart';
import 'package:datababe/widgets/progress_ring.dart';
import 'package:datababe/widgets/trend_chart.dart';

import 'test_harness.dart';

/// Activities with dates relative to DateTime.now() for provider computation.
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

  Future<void> scrollToVisible(WidgetTester tester, Finder target) async {
    await tester.dragUntilVisible(
      target,
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
  }

  // =========================================================================
  // Journey 1 — "Weekly review"
  // =========================================================================

  group('Journey 1 — Weekly review', () {
    testWidgets('Home → Insights → verify default period → switch to calendar week → navigate prev week',
        (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _recentMultiDayActivities();
      await pumpApp(tester, harness.buildApp());

      // Start on Home — verify Home screen loaded
      expect(find.text('Home'), findsWidgets);

      // Navigate to Insights tab
      await tester.tap(find.text('Insights'));
      await tester.pumpAndSettle();

      // Verify default period is "Last 7 days"
      expect(find.text('Last 7 days'), findsWidgets);

      // Verify Progress section shows data (not empty state)
      expect(find.text('Progress'), findsOneWidget);
      expect(find.text('Log a few more days to see progress tracking'),
          findsNothing);
      expect(find.byType(ProgressRing), findsWidgets);

      // Switch to calendar mode
      await tester.tap(find.text('Rolling'));
      await tester.pumpAndSettle();

      // Should now show Calendar mode with week range
      expect(find.text('Calendar'), findsOneWidget);
      // Navigation arrows should be present
      expect(find.byIcon(Icons.chevron_left), findsWidgets);

      // Navigate to previous week via period selector's left arrow
      final periodSelectorChevrons = find.descendant(
        of: find.byType(Card).first,
        matching: find.byIcon(Icons.chevron_left),
      );
      await tester.tap(periodSelectorChevrons.first);
      await tester.pumpAndSettle();

      // The label should have changed (no longer "Last 7 days" or current week)
      expect(find.text('Last 7 days'), findsNothing);

      // Progress section should still exist (even if empty due to past data)
      expect(find.text('Progress'), findsOneWidget);
    });
  });

  // =========================================================================
  // Journey 2 — "Allergen coverage check"
  // =========================================================================

  group('Journey 2 — Allergen coverage check', () {
    testWidgets('Insights → Allergen Tracker → coverage visible → period toggle',
        (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _recentMultiDayActivities();
      await pumpApp(tester, harness.buildApp());

      // Navigate to Insights tab
      await tester.tap(find.text('Insights'));
      await tester.pumpAndSettle();

      // Verify Allergen Tracker section visible
      expect(find.text('Allergen Tracker'), findsOneWidget);

      // Verify coverage count visible
      expect(find.textContaining('covered'), findsWidgets);

      // Verify period toggle (7d/14d) present
      expect(find.text('7d'), findsWidgets);
      expect(find.text('14d'), findsWidgets);

      // Switch to 14d period
      await tester.tap(find.text('14d'));
      await tester.pumpAndSettle();

      // Coverage still visible after switching period
      expect(find.textContaining('covered'), findsWidgets);

      // Tap allergen tracker to navigate to AllergenDetail
      await tester.tap(find.text('Allergen Tracker'));
      await tester.pumpAndSettle();

      // Should navigate to allergen detail screen
      // Verify we left the Insights list (no more Progress section heading)
      expect(find.text('Progress'), findsNothing);
    });
  });

  // =========================================================================
  // Journey 3 — "Growth tracking"
  // =========================================================================

  group('Journey 3 — Growth tracking', () {
    testWidgets('Insights → Growth section → tap → GrowthDetail → back',
        (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _recentMultiDayActivities();
      await pumpApp(tester, harness.buildApp());

      // Navigate to Insights tab
      await tester.tap(find.text('Insights'));
      await tester.pumpAndSettle();

      // Scroll to Growth section
      await scrollToVisible(tester, find.text('Growth'));
      expect(find.text('Growth'), findsOneWidget);

      // Verify latest measurements
      expect(find.text('8.5kg'), findsOneWidget);
      expect(find.text('72.0cm'), findsOneWidget);
      expect(find.text('45.0cm'), findsOneWidget);

      // Tap Growth to navigate to GrowthDetail
      await tester.tap(find.text('Growth'));
      await tester.pumpAndSettle();

      // Should be on GrowthDetail screen — verify Weight/Length/Head filter chips
      expect(find.text('Weight'), findsWidgets);

      // Go back using the AppBar back button
      final backButton = find.byTooltip('Back');
      if (backButton.evaluate().isNotEmpty) {
        await tester.tap(backButton.first);
        await tester.pumpAndSettle();
      }

      // Verify we're back on Insights — Growth section still visible
      await scrollToVisible(tester, find.text('Growth'));
      expect(find.text('Growth'), findsOneWidget);
    });
  });

  // =========================================================================
  // Journey 4 — "Metric drill-down with date navigation"
  // =========================================================================

  group('Journey 4 — Metric drill-down with date navigation', () {
    testWidgets(
        'Insights → navigate to metric detail → prev day → verify label change',
        (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _recentMultiDayActivities();
      await pumpApp(tester, harness.buildApp());

      // Navigate to Insights tab
      await tester.tap(find.text('Insights'));
      await tester.pumpAndSettle();

      // Navigate directly to feed volume metric detail (reliable target)
      final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
      router.push(
          '/insights/metric/${Uri.encodeComponent('feedBottle.totalVolumeMl.daily')}');
      await tester.pumpAndSettle();

      // Should be on MetricDetail screen
      expect(find.text("Today's Progress"), findsOneWidget);
      expect(find.text("Today's Entries"), findsOneWidget);

      // Tap prev-day arrow
      final prevArrows = find.byIcon(Icons.chevron_left);
      await tester.tap(prevArrows.first);
      await tester.pumpAndSettle();

      // Label should change to "Yesterday"
      expect(find.text("Yesterday's Progress"), findsOneWidget);
      expect(find.text("Yesterday's Entries"), findsOneWidget);
      expect(find.text("Today's Progress"), findsNothing);

      // Scroll to trend section — verify it's still present
      await scrollToVisible(tester, find.text('7-day trend'));
      expect(find.byType(TrendChart), findsWidgets);

      // Scroll to Target section
      await scrollToVisible(tester, find.text('Target'));
      expect(find.text('Target'), findsOneWidget);
    });
  });

  // =========================================================================
  // Journey 5 — "Home to Timeline to Insights flow"
  // =========================================================================

  group('Journey 5 — Home to Timeline to Insights flow', () {
    testWidgets('Home → Timeline → switch to Week → Insights → switch to 30d',
        (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _recentMultiDayActivities();
      await pumpApp(tester, harness.buildApp());

      // Verify Home screen loaded
      expect(find.text('Home'), findsWidgets);

      // Navigate to Timeline tab
      await tester.tap(find.text('Timeline'));
      await tester.pumpAndSettle();

      // Verify Day/Week/Month selector present in Timeline
      expect(find.text('Day'), findsOneWidget);
      expect(find.text('Week'), findsOneWidget);

      // Switch to Week
      await tester.tap(find.text('Week'));
      await tester.pumpAndSettle();

      // Navigate to Insights tab
      await tester.tap(find.text('Insights'));
      await tester.pumpAndSettle();

      // Verify Insights has its own period selector
      expect(find.text('Day'), findsOneWidget);
      expect(find.text('Week'), findsOneWidget);
      expect(find.text('Month'), findsOneWidget);

      // Default should be "Last 7 days" (independent of Timeline state)
      expect(find.text('Last 7 days'), findsWidgets);

      // Switch to Month
      await tester.tap(find.text('Month'));
      await tester.pumpAndSettle();

      // Should show 30d label
      expect(find.text('Last 30 days'), findsWidgets);
      expect(find.text('Last 7 days'), findsNothing);

      // Trends section should still be present
      await scrollToVisible(tester, find.text('Trends'));
      expect(find.text('Trends'), findsOneWidget);
    });
  });

  // =========================================================================
  // Journey 6 — "Ingredient to insights pipeline"
  // =========================================================================

  group('Journey 6 — Ingredient to insights pipeline', () {
    testWidgets(
        'Settings → Ingredients (5 seeded) → Recipes (3 visible) → Home solids chip → Insights allergen tracker',
        (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _recentMultiDayActivities();
      await pumpApp(tester, harness.buildApp());

      // Navigate to Settings tab
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Tap Manage Ingredients
      await tester.tap(find.text('Manage Ingredients'));
      await tester.pumpAndSettle();

      // Verify 5 ingredients seeded — title shows count
      expect(find.text('Ingredients (5)'), findsOneWidget);

      // Verify individual ingredient names visible (scroll to see all)
      expect(find.text('egg'), findsWidgets);
      expect(find.text('milk'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('banana'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      expect(find.text('banana'), findsOneWidget);

      // Go back to Settings
      final backButton = find.byTooltip('Back');
      await tester.tap(backButton.first);
      await tester.pumpAndSettle();

      // Scroll to and tap Manage Recipes
      final recipesTile = find.text('Manage Recipes');
      await tester.scrollUntilVisible(
        recipesTile,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(recipesTile);
      await tester.pumpAndSettle();

      // Verify 3 recipes visible — title shows count
      expect(find.text('Recipes (3)'), findsOneWidget);

      // Verify individual recipe names visible
      expect(find.text('scrambled eggs'), findsOneWidget);
      expect(find.text('toast with butter'), findsOneWidget);
      expect(find.text('banana mash'), findsOneWidget);

      // Go back to Settings
      await tester.tap(backButton.first);
      await tester.pumpAndSettle();

      // Navigate to Home tab
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      // Verify Solids chip present in quick-log grid
      expect(find.text('Solids'), findsWidgets);

      // Navigate to Insights tab
      await tester.tap(find.text('Insights'));
      await tester.pumpAndSettle();

      // Verify Allergen Tracker section shows coverage data
      expect(find.text('Allergen Tracker'), findsOneWidget);
      expect(find.textContaining('covered'), findsWidgets);
    });
  });

  // =========================================================================
  // Journey 7 — "Goal tracking flow"
  // =========================================================================

  group('Journey 7 — Goal tracking flow', () {
    testWidgets(
        'Settings → Goals (5 targets) → verify specific targets → Home status rings → Insights progress rings',
        (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _recentMultiDayActivities();
      await pumpApp(tester, harness.buildApp());

      // Navigate to Settings tab
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Tap Goals
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

      // Verify Goals screen loaded with "Other Goals" section
      expect(find.text('Other Goals'), findsOneWidget);

      // Verify feed bottle target — shows "Bottle Feed"
      expect(find.text('Bottle Feed'), findsOneWidget);

      // Verify tummy time target — shows "Tummy Time"
      expect(find.text('Tummy Time'), findsOneWidget);

      // Verify allergen goals section present
      expect(find.textContaining('Allergen'), findsWidgets);

      // Go back to Settings
      final backButton = find.byTooltip('Back');
      await tester.tap(backButton.first);
      await tester.pumpAndSettle();

      // Navigate to Home tab
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      // Verify status rings card is present (connected to targets)
      expect(find.byKey(const Key('status-rings')), findsOneWidget);

      // Navigate to Insights tab
      await tester.tap(find.text('Insights'));
      await tester.pumpAndSettle();

      // Verify Progress section shows rings
      expect(find.text('Progress'), findsOneWidget);
      expect(find.byType(ProgressRing), findsWidgets);
    });
  });

  // =========================================================================
  // Journey 8 — "Multi-carer family view"
  // =========================================================================

  group('Journey 8 — Multi-carer family view', () {
    testWidgets(
        'Family tab → 2 members with roles → Home still works → Settings shows account',
        (tester) async {
      await tester.runAsync(() => harness.seedMultiCarer());
      await pumpApp(tester, harness.buildApp());

      // Navigate to Family tab
      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();

      // Verify Members section present
      expect(find.text('Members'), findsOneWidget);

      // Verify both members visible
      expect(find.text('Test User'), findsWidgets);
      expect(find.text('Partner'), findsOneWidget);

      // Verify role chips displayed
      expect(find.widgetWithText(Chip, 'parent'), findsOneWidget);
      expect(find.widgetWithText(Chip, 'carer'), findsOneWidget);

      // Navigate to Home tab — verify app still functional
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      // Home should show the child's name
      expect(find.text('Baby'), findsWidgets);

      // Navigate to Settings tab
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Verify Account section shows current user info
      expect(find.text('Account'), findsOneWidget);
      expect(find.text('Test User'), findsOneWidget);
      expect(find.text('test@example.com'), findsOneWidget);
    });
  });

  // =========================================================================
  // Journey 9 — "Activity detail drill-down"
  // =========================================================================

  group('Journey 9 — Activity detail drill-down', () {
    testWidgets(
        'Home → bottle feed tile → Insights → metric detail → progress + entries + trend',
        (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _recentMultiDayActivities();
      await pumpApp(tester, harness.buildApp());

      // Verify Home screen loaded with bottle feed tile
      expect(find.textContaining('120ml'), findsWidgets);

      // Navigate to Insights tab
      await tester.tap(find.text('Insights'));
      await tester.pumpAndSettle();

      // Navigate to feed volume metric detail via GoRouter
      final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
      router.push(
          '/insights/metric/${Uri.encodeComponent('feedBottle.totalVolumeMl.daily')}');
      await tester.pumpAndSettle();

      // Verify "Today's Progress" section
      expect(find.text("Today's Progress"), findsOneWidget);

      // Verify "Today's Entries" section
      expect(find.text("Today's Entries"), findsOneWidget);

      // Scroll to 7-day trend and verify TrendChart present
      await scrollToVisible(tester, find.text('7-day trend'));
      expect(find.text('7-day trend'), findsOneWidget);
      expect(find.byType(TrendChart), findsWidgets);

      // Go back using AppBar back button
      final backButton = find.byTooltip('Back');
      if (backButton.evaluate().isNotEmpty) {
        await tester.tap(backButton.first);
        await tester.pumpAndSettle();
      }

      // Verify we're back on Insights — Progress section still visible
      expect(find.text('Progress'), findsOneWidget);
    });
  });

  // =========================================================================
  // Journey 10 — "Settings exploration"
  // =========================================================================

  group('Journey 10 — Settings exploration', () {
    testWidgets(
        'Settings → Account + Data + Sync + Diagnostics → Manage Allergens → back',
        (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());

      // Navigate to Settings tab
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Verify Account section
      expect(find.text('Account'), findsOneWidget);
      expect(find.text('Test User'), findsOneWidget);
      expect(find.text('test@example.com'), findsOneWidget);

      // Verify Data section tiles
      expect(find.text('Data'), findsOneWidget);
      expect(find.text('Manage Allergens'), findsOneWidget);
      expect(find.text('Manage Ingredients'), findsOneWidget);

      // Scroll to see more Data tiles
      await tester.scrollUntilVisible(
        find.text('Manage Recipes'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Manage Recipes'), findsOneWidget);

      // Scroll to Sync section — verify Sync Now present
      await tester.scrollUntilVisible(
        find.text('Sync Now'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Sync Now'), findsOneWidget);

      // Verify Diagnostics tile present
      await tester.scrollUntilVisible(
        find.text('Diagnostics'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Diagnostics'), findsOneWidget);

      // Scroll back up and tap Manage Allergens
      await tester.dragUntilVisible(
        find.text('Manage Allergens'),
        find.byType(Scrollable).last,
        const Offset(0, 200),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manage Allergens'));
      await tester.pumpAndSettle();

      // Verify allergen management screen opens
      expect(find.text('Manage Allergens'), findsWidgets);

      // Go back to Settings
      final backButton = find.byTooltip('Back');
      await tester.tap(backButton.first);
      await tester.pumpAndSettle();

      // Verify Settings still shows sections (scroll to top first)
      await tester.dragUntilVisible(
        find.text('Account'),
        find.byType(Scrollable).last,
        const Offset(0, 200),
      );
      await tester.pumpAndSettle();
      expect(find.text('Account'), findsOneWidget);
      expect(find.text('Data'), findsOneWidget);
    });
  });
}
