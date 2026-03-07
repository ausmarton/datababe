import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:datababe/models/enums.dart';
import 'package:datababe/models/target_model.dart';
import 'package:datababe/utils/activity_aggregator.dart';
import 'package:datababe/widgets/summary_card.dart';

/// Helper to create an ActivitySummary with sensible defaults.
ActivitySummary makeSummary({
  int totalCount = 0,
  int bottleFeedCount = 0,
  double bottleFeedTotalMl = 0,
  int breastFeedCount = 0,
  int breastFeedTotalMinutes = 0,
  int diaperCount = 0,
  Map<String, int> diaperBreakdown = const {},
  int solidsCount = 0,
  Set<String> uniqueFoods = const {},
  Map<String, int> reactionBreakdown = const {},
  Map<String, int> medsBreakdown = const {},
  double? latestWeightKg,
  double? latestLengthCm,
  double? latestHeadCm,
  double? latestTempC,
  double? minTempC,
  double? maxTempC,
  Map<String, int> durationTotals = const {},
  Map<String, int> durationCounts = const {},
  int pumpCount = 0,
  double pumpTotalMl = 0,
  int pottyCount = 0,
  Map<String, int> pottyBreakdown = const {},
  Map<String, int> ingredientExposures = const {},
  Map<String, int> allergenExposures = const {},
}) =>
    ActivitySummary(
      totalCount: totalCount,
      bottleFeedCount: bottleFeedCount,
      bottleFeedTotalMl: bottleFeedTotalMl,
      breastFeedCount: breastFeedCount,
      breastFeedTotalMinutes: breastFeedTotalMinutes,
      diaperCount: diaperCount,
      diaperBreakdown: diaperBreakdown,
      solidsCount: solidsCount,
      uniqueFoods: uniqueFoods,
      reactionBreakdown: reactionBreakdown,
      medsBreakdown: medsBreakdown,
      latestWeightKg: latestWeightKg,
      latestLengthCm: latestLengthCm,
      latestHeadCm: latestHeadCm,
      latestTempC: latestTempC,
      minTempC: minTempC,
      maxTempC: maxTempC,
      durationTotals: durationTotals,
      durationCounts: durationCounts,
      pumpCount: pumpCount,
      pumpTotalMl: pumpTotalMl,
      pottyCount: pottyCount,
      pottyBreakdown: pottyBreakdown,
      ingredientExposures: ingredientExposures,
      allergenExposures: allergenExposures,
    );

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('SummaryCard overview (no filter)', () {
    testWidgets('shows total count', (tester) async {
      await tester.pumpWidget(wrap(SummaryCard(
        summary: makeSummary(totalCount: 5),
      )));

      expect(find.text('5 total'), findsOneWidget);
    });

    testWidgets('shows bottle feed count when > 0', (tester) async {
      await tester.pumpWidget(wrap(SummaryCard(
        summary: makeSummary(totalCount: 3, bottleFeedCount: 3),
      )));

      expect(find.text('3'), findsAtLeast(1));
    });

    testWidgets('hides bottle feed chip when count is 0', (tester) async {
      await tester.pumpWidget(wrap(SummaryCard(
        summary: makeSummary(totalCount: 2, diaperCount: 2),
      )));

      // Should only see total and diaper chips.
      expect(find.text('2 total'), findsOneWidget);
    });

    testWidgets('shows duration activity chip', (tester) async {
      await tester.pumpWidget(wrap(SummaryCard(
        summary: makeSummary(
          totalCount: 1,
          durationCounts: {'tummyTime': 1},
          durationTotals: {'tummyTime': 15},
        ),
      )));

      expect(find.text('1'), findsAtLeast(1));
    });
  });

  group('SummaryCard filtered views', () {
    testWidgets('bottle feed: shows count and total ml', (tester) async {
      await tester.pumpWidget(wrap(SummaryCard(
        summary: makeSummary(
          totalCount: 3,
          bottleFeedCount: 3,
          bottleFeedTotalMl: 360,
        ),
        filter: ActivityType.feedBottle,
      )));

      expect(find.textContaining('3 feeds'), findsOneWidget);
      expect(find.textContaining('360ml'), findsOneWidget);
    });

    testWidgets('bottle feed: shows average when count > 0', (tester) async {
      await tester.pumpWidget(wrap(SummaryCard(
        summary: makeSummary(
          totalCount: 2,
          bottleFeedCount: 2,
          bottleFeedTotalMl: 240,
        ),
        filter: ActivityType.feedBottle,
      )));

      expect(find.textContaining('Avg: 120ml'), findsOneWidget);
    });

    testWidgets('breast feed: shows count and total duration', (tester) async {
      await tester.pumpWidget(wrap(SummaryCard(
        summary: makeSummary(
          totalCount: 2,
          breastFeedCount: 2,
          breastFeedTotalMinutes: 30,
        ),
        filter: ActivityType.feedBreast,
      )));

      expect(find.textContaining('2 feeds'), findsOneWidget);
      expect(find.textContaining('30min'), findsOneWidget);
    });

    testWidgets('diaper: shows count and breakdown', (tester) async {
      await tester.pumpWidget(wrap(SummaryCard(
        summary: makeSummary(
          totalCount: 5,
          diaperCount: 5,
          diaperBreakdown: {'poo': 3, 'pee': 2},
        ),
        filter: ActivityType.diaper,
      )));

      expect(find.textContaining('5 diapers'), findsOneWidget);
      expect(find.textContaining('poo: 3'), findsOneWidget);
    });

    testWidgets('solids: shows count and unique foods', (tester) async {
      await tester.pumpWidget(wrap(SummaryCard(
        summary: makeSummary(
          totalCount: 3,
          solidsCount: 3,
          uniqueFoods: {'banana', 'avocado'},
        ),
        filter: ActivityType.solids,
      )));

      expect(find.textContaining('3 meals'), findsOneWidget);
      expect(find.textContaining('2 unique foods'), findsOneWidget);
    });

    testWidgets('solids: shows ingredient exposures', (tester) async {
      await tester.pumpWidget(wrap(SummaryCard(
        summary: makeSummary(
          totalCount: 2,
          solidsCount: 2,
          uniqueFoods: {'egg'},
          ingredientExposures: {'egg': 3, 'milk': 1},
        ),
        filter: ActivityType.solids,
      )));

      expect(find.textContaining('Top exposures'), findsOneWidget);
      expect(find.textContaining('egg: 3x'), findsOneWidget);
    });

    testWidgets('solids: shows allergen exposures', (tester) async {
      await tester.pumpWidget(wrap(SummaryCard(
        summary: makeSummary(
          totalCount: 1,
          solidsCount: 1,
          uniqueFoods: {'egg'},
          allergenExposures: {'egg': 2},
        ),
        filter: ActivityType.solids,
      )));

      expect(find.textContaining('Allergens'), findsOneWidget);
      expect(find.textContaining('egg: 2x'), findsOneWidget);
    });

    testWidgets('meds: shows breakdown', (tester) async {
      await tester.pumpWidget(wrap(SummaryCard(
        summary: makeSummary(
          totalCount: 3,
          medsBreakdown: {'Paracetamol': 2, 'Ibuprofen': 1},
        ),
        filter: ActivityType.meds,
      )));

      expect(find.textContaining('Paracetamol: 2x'), findsOneWidget);
      expect(find.textContaining('Ibuprofen: 1x'), findsOneWidget);
    });

    testWidgets('growth: shows latest measurements', (tester) async {
      await tester.pumpWidget(wrap(SummaryCard(
        summary: makeSummary(
          totalCount: 1,
          latestWeightKg: 5.2,
          latestLengthCm: 55.0,
          latestHeadCm: 37.5,
        ),
        filter: ActivityType.growth,
      )));

      expect(find.textContaining('5.2kg'), findsOneWidget);
      expect(find.textContaining('55.0cm'), findsOneWidget);
      expect(find.textContaining('37.5cm'), findsOneWidget);
    });

    testWidgets('temperature: shows latest and range', (tester) async {
      await tester.pumpWidget(wrap(SummaryCard(
        summary: makeSummary(
          totalCount: 3,
          latestTempC: 36.8,
          minTempC: 36.5,
          maxTempC: 37.2,
        ),
        filter: ActivityType.temperature,
      )));

      expect(find.textContaining('36.8'), findsOneWidget);
      expect(find.textContaining('36.5'), findsOneWidget);
      expect(find.textContaining('37.2'), findsOneWidget);
    });

    testWidgets('pump: shows count and total ml', (tester) async {
      await tester.pumpWidget(wrap(SummaryCard(
        summary: makeSummary(
          totalCount: 2,
          pumpCount: 2,
          pumpTotalMl: 160,
        ),
        filter: ActivityType.pump,
      )));

      expect(find.textContaining('2 sessions'), findsOneWidget);
      expect(find.textContaining('160ml'), findsOneWidget);
    });

    testWidgets('potty: shows count and breakdown', (tester) async {
      await tester.pumpWidget(wrap(SummaryCard(
        summary: makeSummary(
          totalCount: 3,
          pottyCount: 3,
          pottyBreakdown: {'pee': 2, 'poo': 1},
        ),
        filter: ActivityType.potty,
      )));

      expect(find.textContaining('3 potty'), findsOneWidget);
      expect(find.textContaining('pee: 2'), findsOneWidget);
    });

    testWidgets('duration activity: shows count and total', (tester) async {
      await tester.pumpWidget(wrap(SummaryCard(
        summary: makeSummary(
          totalCount: 2,
          durationCounts: {'tummyTime': 2},
          durationTotals: {'tummyTime': 30},
        ),
        filter: ActivityType.tummyTime,
      )));

      expect(find.textContaining('2 sessions'), findsOneWidget);
      expect(find.textContaining('30min'), findsOneWidget);
    });
  });

  group('SummaryCard target progress', () {
    testWidgets('shows target progress bar', (tester) async {
      final now = DateTime(2026, 3, 6);
      final target = TargetModel(
        id: 'tgt-1',
        childId: 'child-1',
        activityType: 'feedBottle',
        metric: 'count',
        period: 'daily',
        targetValue: 6,
        createdBy: 'uid-1',
        createdAt: now,
        modifiedAt: now,
      );

      await tester.pumpWidget(wrap(SummaryCard(
        summary: makeSummary(totalCount: 4, bottleFeedCount: 4),
        targetProgress: [
          TargetProgress(target: target, actual: 4, fraction: 4 / 6),
        ],
      )));

      expect(find.textContaining('4 of 6'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('no progress section when targetProgress is null',
        (tester) async {
      await tester.pumpWidget(wrap(SummaryCard(
        summary: makeSummary(totalCount: 1),
      )));

      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('no progress section when targetProgress is empty',
        (tester) async {
      await tester.pumpWidget(wrap(SummaryCard(
        summary: makeSummary(totalCount: 1),
        targetProgress: const [],
      )));

      expect(find.byType(LinearProgressIndicator), findsNothing);
    });
  });
}
