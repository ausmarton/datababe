import 'package:flutter_test/flutter_test.dart';
import 'package:datababe/models/activity_model.dart';
import 'package:datababe/utils/activity_aggregator.dart';

ActivityModel _activity({
  required String type,
  DateTime? startTime,
  double? volumeMl,
  String? feedType,
  int? rightBreastMinutes,
  int? leftBreastMinutes,
  int? durationMinutes,
  String? contents,
  String? foodDescription,
  String? reaction,
  String? medicationName,
  double? weightKg,
  double? lengthCm,
  double? headCircumferenceCm,
  double? tempCelsius,
  String? recipeId,
  List<String>? ingredientNames,
}) {
  final now = startTime ?? DateTime(2026, 2, 26, 10, 0);
  return ActivityModel(
    id: 'id-${now.millisecondsSinceEpoch}',
    childId: 'child-1',
    type: type,
    startTime: now,
    createdAt: now,
    modifiedAt: now,
    volumeMl: volumeMl,
    feedType: feedType,
    rightBreastMinutes: rightBreastMinutes,
    leftBreastMinutes: leftBreastMinutes,
    durationMinutes: durationMinutes,
    contents: contents,
    foodDescription: foodDescription,
    reaction: reaction,
    medicationName: medicationName,
    weightKg: weightKg,
    lengthCm: lengthCm,
    headCircumferenceCm: headCircumferenceCm,
    tempCelsius: tempCelsius,
    recipeId: recipeId,
    ingredientNames: ingredientNames,
  );
}

void main() {
  group('ActivityAggregator.compute', () {
    test('empty list returns zeroed summary', () {
      final summary = ActivityAggregator.compute([]);
      expect(summary.totalCount, 0);
      expect(summary.bottleFeedCount, 0);
      expect(summary.bottleFeedTotalMl, 0);
      expect(summary.diaperCount, 0);
    });

    test('bottle feed stats', () {
      final activities = [
        _activity(type: 'feedBottle', volumeMl: 120, feedType: 'formula'),
        _activity(type: 'feedBottle', volumeMl: 150, feedType: 'breastMilk'),
        _activity(type: 'feedBottle', volumeMl: 100, feedType: 'formula'),
      ];
      final summary = ActivityAggregator.compute(activities);
      expect(summary.totalCount, 3);
      expect(summary.bottleFeedCount, 3);
      expect(summary.bottleFeedTotalMl, 370);
    });

    test('breast feed stats with individual breast minutes', () {
      final activities = [
        _activity(
            type: 'feedBreast', rightBreastMinutes: 10, leftBreastMinutes: 8),
        _activity(
            type: 'feedBreast', rightBreastMinutes: 12, leftBreastMinutes: 5),
      ];
      final summary = ActivityAggregator.compute(activities);
      expect(summary.breastFeedCount, 2);
      expect(summary.breastFeedTotalMinutes, 35); // 10+8+12+5
    });

    test('breast feed fallback to durationMinutes', () {
      final activities = [
        _activity(type: 'feedBreast', durationMinutes: 20),
      ];
      final summary = ActivityAggregator.compute(activities);
      expect(summary.breastFeedTotalMinutes, 20);
    });

    test('diaper breakdown', () {
      final activities = [
        _activity(type: 'diaper', contents: 'pee'),
        _activity(type: 'diaper', contents: 'poo'),
        _activity(type: 'diaper', contents: 'pee'),
        _activity(type: 'diaper', contents: 'both'),
      ];
      final summary = ActivityAggregator.compute(activities);
      expect(summary.diaperCount, 4);
      expect(summary.diaperBreakdown['pee'], 2);
      expect(summary.diaperBreakdown['poo'], 1);
      expect(summary.diaperBreakdown['both'], 1);
    });

    test('unique foods dedup', () {
      final activities = [
        _activity(type: 'solids', foodDescription: 'banana, Apple'),
        _activity(type: 'solids', foodDescription: 'Banana, pear'),
      ];
      final summary = ActivityAggregator.compute(activities);
      expect(summary.solidsCount, 2);
      expect(summary.uniqueFoods, {'banana', 'apple', 'pear'});
    });

    test('reaction breakdown', () {
      final activities = [
        _activity(type: 'solids', reaction: 'loved'),
        _activity(type: 'solids', reaction: 'loved'),
        _activity(type: 'solids', reaction: 'meh'),
      ];
      final summary = ActivityAggregator.compute(activities);
      expect(summary.reactionBreakdown['loved'], 2);
      expect(summary.reactionBreakdown['meh'], 1);
    });

    test('meds breakdown', () {
      final activities = [
        _activity(type: 'meds', medicationName: 'Paracetamol'),
        _activity(type: 'meds', medicationName: 'Paracetamol'),
        _activity(type: 'meds', medicationName: 'Vitamin D'),
      ];
      final summary = ActivityAggregator.compute(activities);
      expect(summary.medsBreakdown['Paracetamol'], 2);
      expect(summary.medsBreakdown['Vitamin D'], 1);
    });

    test('growth latest by time', () {
      final activities = [
        _activity(
          type: 'growth',
          startTime: DateTime(2026, 2, 20),
          weightKg: 5.5,
          lengthCm: 58,
        ),
        _activity(
          type: 'growth',
          startTime: DateTime(2026, 2, 26),
          weightKg: 6.0,
          lengthCm: 60,
          headCircumferenceCm: 40,
        ),
      ];
      final summary = ActivityAggregator.compute(activities);
      expect(summary.latestWeightKg, 6.0);
      expect(summary.latestLengthCm, 60);
      expect(summary.latestHeadCm, 40);
    });

    test('temperature min/max', () {
      final activities = [
        _activity(type: 'temperature', tempCelsius: 36.5),
        _activity(type: 'temperature', tempCelsius: 37.2),
        _activity(type: 'temperature', tempCelsius: 36.8),
      ];
      final summary = ActivityAggregator.compute(activities);
      expect(summary.latestTempC, 36.8);
      expect(summary.minTempC, 36.5);
      expect(summary.maxTempC, 37.2);
    });

    test('duration totals for tummyTime', () {
      final activities = [
        _activity(type: 'tummyTime', durationMinutes: 15),
        _activity(type: 'tummyTime', durationMinutes: 20),
      ];
      final summary = ActivityAggregator.compute(activities);
      expect(summary.durationTotals['tummyTime'], 35);
      expect(summary.durationCounts['tummyTime'], 2);
    });

    test('pump stats', () {
      final activities = [
        _activity(type: 'pump', volumeMl: 80, durationMinutes: 15),
        _activity(type: 'pump', volumeMl: 100, durationMinutes: 20),
      ];
      final summary = ActivityAggregator.compute(activities);
      expect(summary.pumpCount, 2);
      expect(summary.pumpTotalMl, 180);
    });

    test('potty breakdown', () {
      final activities = [
        _activity(type: 'potty', contents: 'pee'),
        _activity(type: 'potty', contents: 'poo'),
      ];
      final summary = ActivityAggregator.compute(activities);
      expect(summary.pottyCount, 2);
      expect(summary.pottyBreakdown['pee'], 1);
      expect(summary.pottyBreakdown['poo'], 1);
    });

    test('mixed activities', () {
      final activities = [
        _activity(type: 'feedBottle', volumeMl: 120),
        _activity(type: 'diaper', contents: 'pee'),
        _activity(type: 'tummyTime', durationMinutes: 10),
      ];
      final summary = ActivityAggregator.compute(activities);
      expect(summary.totalCount, 3);
      expect(summary.bottleFeedCount, 1);
      expect(summary.diaperCount, 1);
      expect(summary.durationCounts['tummyTime'], 1);
    });

    test('ingredient exposures from recipe-based activities', () {
      final activities = [
        _activity(
          type: 'solids',
          foodDescription: 'Banana Porridge',
          recipeId: 'recipe-1',
          ingredientNames: ['oats', "cow's milk", 'banana'],
        ),
        _activity(
          type: 'solids',
          foodDescription: 'Egg Toast',
          recipeId: 'recipe-2',
          ingredientNames: ['egg', "cow's milk", 'bread'],
        ),
      ];
      final summary = ActivityAggregator.compute(activities);
      expect(summary.ingredientExposures['oats'], 1);
      expect(summary.ingredientExposures["cow's milk"], 2);
      expect(summary.ingredientExposures['banana'], 1);
      expect(summary.ingredientExposures['egg'], 1);
      expect(summary.ingredientExposures['bread'], 1);
    });

    test('ingredient exposures legacy fallback from foodDescription', () {
      final activities = [
        _activity(type: 'solids', foodDescription: 'banana, Apple'),
        _activity(type: 'solids', foodDescription: 'Banana, pear'),
      ];
      final summary = ActivityAggregator.compute(activities);
      expect(summary.ingredientExposures['banana'], 2);
      expect(summary.ingredientExposures['apple'], 1);
      expect(summary.ingredientExposures['pear'], 1);
    });

    test('ingredient exposures mixed recipe and legacy', () {
      final activities = [
        _activity(
          type: 'solids',
          foodDescription: 'Banana Porridge',
          recipeId: 'recipe-1',
          ingredientNames: ['oats', 'banana'],
        ),
        _activity(type: 'solids', foodDescription: 'banana, egg'),
      ];
      final summary = ActivityAggregator.compute(activities);
      // Recipe: oats=1, banana=1
      // Legacy: banana=1, egg=1
      expect(summary.ingredientExposures['oats'], 1);
      expect(summary.ingredientExposures['banana'], 2);
      expect(summary.ingredientExposures['egg'], 1);
    });
  });
}
