import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_harness.dart';

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
      expect(find.text('Start logging activities to see insights'),
          findsOneWidget);
    });
  });

  group('Insights — with data', () {
    testWidgets('shows Insights title and Goals button', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToInsights(tester);

      expect(find.text('Insights'), findsWidgets);
      expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
    });

    testWidgets('Today section visible', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToInsights(tester);

      expect(find.text('Today'), findsOneWidget);
    });

    testWidgets('Allergen Tracker section visible', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToInsights(tester);

      expect(find.text('Allergen Tracker'), findsOneWidget);
    });

    testWidgets('This Week section visible', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await navigateToInsights(tester);

      await scrollToVisible(tester, find.text('This Week'));
      expect(find.text('This Week'), findsOneWidget);
      expect(find.text('Exposed'), findsOneWidget);
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

      await scrollToVisible(tester, find.text('30d'));
      expect(find.text('30d'), findsOneWidget);
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
}
