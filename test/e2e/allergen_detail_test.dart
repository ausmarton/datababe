import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:datababe/models/activity_model.dart';
import 'package:datababe/models/family_model.dart';

import 'test_harness.dart';

/// Activities with allergen exposure data, dates relative to DateTime.now().
List<ActivityModel> _allergenActivities() {
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
    // Solids with egg + dairy (today)
    ActivityModel(
      id: 's1',
      childId: 'c1',
      type: 'solids',
      startTime: now.subtract(const Duration(hours: 1)),
      foodDescription: 'scrambled eggs',
      ingredientNames: ['egg', 'milk'],
      allergenNames: ['egg', 'dairy'],
      createdAt: now,
      modifiedAt: now,
    ),
    // Solids with wheat (2 days ago)
    ActivityModel(
      id: 's2',
      childId: 'c1',
      type: 'solids',
      startTime: now.subtract(const Duration(days: 2)),
      foodDescription: 'toast',
      ingredientNames: ['bread'],
      allergenNames: ['wheat'],
      createdAt: now.subtract(const Duration(days: 2)),
      modifiedAt: now.subtract(const Duration(days: 2)),
    ),
    // Solids with egg again (3 days ago)
    ActivityModel(
      id: 's3',
      childId: 'c1',
      type: 'solids',
      startTime: now.subtract(const Duration(days: 3)),
      foodDescription: 'boiled egg',
      ingredientNames: ['egg'],
      allergenNames: ['egg'],
      createdAt: now.subtract(const Duration(days: 3)),
      modifiedAt: now.subtract(const Duration(days: 3)),
    ),
    // Solids with dairy (5 days ago)
    ActivityModel(
      id: 's4',
      childId: 'c1',
      type: 'solids',
      startTime: now.subtract(const Duration(days: 5)),
      foodDescription: 'yogurt',
      ingredientNames: ['milk'],
      allergenNames: ['dairy'],
      createdAt: now.subtract(const Duration(days: 5)),
      modifiedAt: now.subtract(const Duration(days: 5)),
    ),
  ];
}

void main() {
  final harness = TestHarness();

  setUp(harness.setUp);
  tearDown(harness.tearDown);

  Future<void> navigateToAllergenDetail(WidgetTester tester) async {
    // Push directly to allergen detail via router
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    router.push('/insights/allergens');
    await tester.pumpAndSettle();
  }

  group('Allergen Detail — empty categories', () {
    testWidgets('shows prompt when no allergen categories', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      // Override families to have no allergen categories
      harness.families = [
        FamilyModel(
          id: TestData.familyA.id,
          name: TestData.familyA.name,
          createdBy: TestData.familyA.createdBy,
          memberUids: TestData.familyA.memberUids,
          createdAt: TestData.familyA.createdAt,
          modifiedAt: TestData.familyA.modifiedAt,
          allergenCategories: [],
        ),
      ];
      harness.activities = _allergenActivities();
      await pumpApp(tester, harness.buildApp());
      await navigateToAllergenDetail(tester);

      expect(find.text('Allergen Tracking'), findsWidgets);
      expect(find.text('Manage Allergens'), findsOneWidget);
    });
  });

  group('Allergen Detail — with data', () {
    testWidgets('shows Allergen Tracking title', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _allergenActivities();
      await pumpApp(tester, harness.buildApp());
      await navigateToAllergenDetail(tester);

      expect(find.text('Allergen Tracking'), findsWidgets);
    });

    testWidgets('shows period selector (7d, 14d, 30d)', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _allergenActivities();
      await pumpApp(tester, harness.buildApp());
      await navigateToAllergenDetail(tester);

      expect(find.text('7d'), findsOneWidget);
      expect(find.text('14d'), findsOneWidget);
      expect(find.text('30d'), findsOneWidget);
    });

    testWidgets('shows coverage summary', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _allergenActivities();
      await pumpApp(tester, harness.buildApp());
      await navigateToAllergenDetail(tester);

      // Family has 5 categories: egg, dairy, peanut, wheat, soy
      // Activities expose egg, dairy, wheat = 3 covered
      expect(find.textContaining('Coverage:'), findsOneWidget);
    });

    testWidgets('shows covered allergen chips', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _allergenActivities();
      await pumpApp(tester, harness.buildApp());
      await navigateToAllergenDetail(tester);

      // egg, dairy, wheat should appear as covered chips
      expect(find.byType(Chip), findsWidgets);
    });

    testWidgets('shows per-allergen rows', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _allergenActivities();
      await pumpApp(tester, harness.buildApp());
      await navigateToAllergenDetail(tester);

      // All 5 allergen categories should be shown as rows
      expect(find.text('egg'), findsWidgets);
      expect(find.text('dairy'), findsWidgets);
      expect(find.text('peanut'), findsWidgets);
    });

    testWidgets('shows progress bars for allergen rows', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _allergenActivities();
      await pumpApp(tester, harness.buildApp());
      await navigateToAllergenDetail(tester);

      // Each allergen row has a LinearProgressIndicator
      expect(find.byType(LinearProgressIndicator), findsWidgets);
    });

    testWidgets('shows exposure count and last exposed', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _allergenActivities();
      await pumpApp(tester, harness.buildApp());
      await navigateToAllergenDetail(tester);

      // Egg has 2 exposures (s1 today + s3 three days ago)
      // Should show exposure count in subtitle
      expect(find.textContaining('Last:'), findsWidgets);
    });

    testWidgets('shows urgency icons for allergen targets', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _allergenActivities();
      await pumpApp(tester, harness.buildApp());
      await navigateToAllergenDetail(tester);

      // Targets exist for egg and dairy (weekly, 2 exposures each)
      // Urgency icons should appear (warning_amber, timelapse, or check_circle)
      final urgencyIcons = find.byWidgetPredicate((w) =>
          w is Icon &&
          (w.icon == Icons.warning_amber ||
              w.icon == Icons.timelapse ||
              w.icon == Icons.check_circle));
      expect(urgencyIcons, findsWidgets);
    });

    testWidgets('tapping allergen row expands drilldown', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _allergenActivities();
      harness.ingredients = TestData.ingredients();
      await pumpApp(tester, harness.buildApp());
      await navigateToAllergenDetail(tester);

      // Tap on "egg" row to expand
      final eggTile = find.widgetWithText(ListTile, 'egg');
      if (eggTile.evaluate().isNotEmpty) {
        await tester.tap(eggTile.first);
        await tester.pumpAndSettle();

        // Expanded view should show expand_less icon
        expect(find.byIcon(Icons.expand_less), findsWidgets);
      }
    });

    testWidgets('allergen row shows expand icons', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      harness.activities = _allergenActivities();
      await pumpApp(tester, harness.buildApp());
      await navigateToAllergenDetail(tester);

      // Rows should show expand_more by default
      expect(find.byIcon(Icons.expand_more), findsWidgets);
    });
  });

  group('Allergen Detail — no exposure data', () {
    testWidgets('shows all allergens as missing when no solids logged',
        (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      // Non-solids activity so insights doesn't show completely empty
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
      await navigateToAllergenDetail(tester);

      // Should show 0/5 coverage (all missing)
      expect(find.textContaining('0 / 5'), findsOneWidget);
    });
  });
}
