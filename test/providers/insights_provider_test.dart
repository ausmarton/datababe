import 'package:flutter_test/flutter_test.dart';
import 'package:datababe/models/activity_model.dart';
import 'package:datababe/models/ingredient_model.dart';
import 'package:datababe/models/target_model.dart';
import 'package:datababe/providers/insights_provider.dart';
import 'package:datababe/utils/activity_aggregator.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ActivityModel _activity({
  required String type,
  DateTime? startTime,
  double? volumeMl,
  int? durationMinutes,
  String? foodDescription,
  String? contents,
  List<String>? ingredientNames,
  List<String>? allergenNames,
  String? recipeId,
  double? weightKg,
  double? lengthCm,
  double? headCircumferenceCm,
  int? rightBreastMinutes,
  int? leftBreastMinutes,
}) {
  final now = startTime ?? DateTime(2026, 3, 6, 10, 0);
  return ActivityModel(
    id: 'id-${now.millisecondsSinceEpoch}-${type.hashCode}',
    childId: 'child-1',
    type: type,
    startTime: now,
    createdAt: now,
    modifiedAt: now,
    volumeMl: volumeMl,
    durationMinutes: durationMinutes,
    foodDescription: foodDescription,
    contents: contents,
    ingredientNames: ingredientNames,
    allergenNames: allergenNames,
    recipeId: recipeId,
    weightKg: weightKg,
    lengthCm: lengthCm,
    headCircumferenceCm: headCircumferenceCm,
    rightBreastMinutes: rightBreastMinutes,
    leftBreastMinutes: leftBreastMinutes,
  );
}

IngredientModel _ingredient(String name, List<String> allergens) {
  final now = DateTime(2026, 3, 1);
  return IngredientModel(
    id: 'ing-$name',
    name: name,
    allergens: allergens,
    createdBy: 'uid-1',
    createdAt: now,
    modifiedAt: now,
  );
}

TargetModel _allergenTarget(String allergenName,
    {double targetValue = 3,
    String period = 'weekly',
    String metric = 'allergenExposures'}) {
  final now = DateTime(2026, 3, 1);
  return TargetModel(
    id: 'target-$allergenName-$metric',
    childId: 'child-1',
    activityType: 'solids',
    metric: metric,
    period: period,
    targetValue: targetValue,
    createdBy: 'uid-1',
    createdAt: now,
    modifiedAt: now,
    allergenName: allergenName,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ========================================================================
  // extractMetricFromSummary
  // ========================================================================
  group('extractMetricFromSummary', () {
    test('totalVolumeMl for feedBottle', () {
      final summary = ActivityAggregator.compute([
        _activity(type: 'feedBottle', volumeMl: 120),
        _activity(type: 'feedBottle', volumeMl: 150),
      ]);
      final result =
          extractMetricFromSummary('feedBottle', 'totalVolumeMl', summary);
      expect(result, 270);
    });

    test('totalVolumeMl for pump', () {
      final summary = ActivityAggregator.compute([
        _activity(type: 'pump', volumeMl: 80),
      ]);
      final result =
          extractMetricFromSummary('pump', 'totalVolumeMl', summary);
      expect(result, 80);
    });

    test('totalVolumeMl returns null for unknown type', () {
      final summary = ActivityAggregator.compute([]);
      final result =
          extractMetricFromSummary('diaper', 'totalVolumeMl', summary);
      expect(result, isNull);
    });

    test('count for various activity types', () {
      final summary = ActivityAggregator.compute([
        _activity(type: 'feedBottle', volumeMl: 100),
        _activity(type: 'feedBottle', volumeMl: 100),
        _activity(type: 'diaper', contents: 'pee'),
        _activity(type: 'diaper', contents: 'poo'),
        _activity(type: 'diaper', contents: 'pee'),
        _activity(type: 'solids', foodDescription: 'banana'),
        _activity(type: 'potty', contents: 'pee'),
      ]);
      expect(
          extractMetricFromSummary('feedBottle', 'count', summary), 2);
      expect(extractMetricFromSummary('diaper', 'count', summary), 3);
      expect(extractMetricFromSummary('solids', 'count', summary), 1);
      expect(extractMetricFromSummary('potty', 'count', summary), 1);
    });

    test('count for duration-tracked types falls back to durationCounts', () {
      final summary = ActivityAggregator.compute([
        _activity(type: 'tummyTime', durationMinutes: 10),
        _activity(type: 'tummyTime', durationMinutes: 15),
      ]);
      expect(
          extractMetricFromSummary('tummyTime', 'count', summary), 2);
    });

    test('uniqueFoods returns food count', () {
      final summary = ActivityAggregator.compute([
        _activity(type: 'solids', foodDescription: 'banana, apple'),
        _activity(type: 'solids', foodDescription: 'banana, pear'),
      ]);
      expect(
          extractMetricFromSummary('solids', 'uniqueFoods', summary), 3);
    });

    test('totalDurationMinutes for feedBreast', () {
      final summary = ActivityAggregator.compute([
        _activity(
            type: 'feedBreast', rightBreastMinutes: 10, leftBreastMinutes: 8),
      ]);
      expect(
          extractMetricFromSummary(
              'feedBreast', 'totalDurationMinutes', summary),
          18);
    });

    test('totalDurationMinutes for tummyTime', () {
      final summary = ActivityAggregator.compute([
        _activity(type: 'tummyTime', durationMinutes: 25),
      ]);
      expect(
          extractMetricFromSummary(
              'tummyTime', 'totalDurationMinutes', summary),
          25);
    });

    test('ingredientExposures with matching name', () {
      final summary = ActivityAggregator.compute([
        _activity(
            type: 'solids',
            ingredientNames: ['egg', 'milk'],
            recipeId: 'r1'),
        _activity(
            type: 'solids',
            ingredientNames: ['egg', 'bread'],
            recipeId: 'r2'),
      ]);
      expect(
          extractMetricFromSummary(
              'solids', 'ingredientExposures', summary,
              ingredientName: 'egg'),
          2);
      expect(
          extractMetricFromSummary(
              'solids', 'ingredientExposures', summary,
              ingredientName: 'milk'),
          1);
    });

    test('ingredientExposures returns null without name', () {
      final summary = ActivityAggregator.compute([]);
      expect(
          extractMetricFromSummary(
              'solids', 'ingredientExposures', summary),
          isNull);
    });

    test('allergenExposures with matching name', () {
      final summary = ActivityAggregator.compute([
        _activity(type: 'solids', allergenNames: ['dairy', 'gluten']),
        _activity(type: 'solids', allergenNames: ['dairy']),
      ]);
      expect(
          extractMetricFromSummary(
              'solids', 'allergenExposures', summary,
              allergenName: 'dairy'),
          2);
      expect(
          extractMetricFromSummary(
              'solids', 'allergenExposures', summary,
              allergenName: 'gluten'),
          1);
    });

    test('unknown metric returns null', () {
      final summary = ActivityAggregator.compute([]);
      expect(
          extractMetricFromSummary('feedBottle', 'unknownMetric', summary),
          isNull);
    });
  });

  // ========================================================================
  // computeAllergenCoverage
  // ========================================================================
  group('computeAllergenCoverage', () {
    final refDate = DateTime(2026, 3, 6);

    test('empty categories returns empty coverage', () {
      final result = computeAllergenCoverage(
        activities: [_activity(type: 'solids', allergenNames: ['dairy'])],
        allergenCategories: [],
        referenceDate: refDate,
        periodDays: 7,
      );
      expect(result.covered, isEmpty);
      expect(result.missing, isEmpty);
    });

    test('all categories covered', () {
      final result = computeAllergenCoverage(
        activities: [
          _activity(
            type: 'solids',
            startTime: DateTime(2026, 3, 5, 10),
            allergenNames: ['dairy', 'egg'],
          ),
          _activity(
            type: 'solids',
            startTime: DateTime(2026, 3, 4, 10),
            allergenNames: ['gluten'],
          ),
        ],
        allergenCategories: ['dairy', 'egg', 'gluten'],
        referenceDate: refDate,
        periodDays: 7,
      );
      expect(result.covered, {'dairy', 'egg', 'gluten'});
      expect(result.missing, isEmpty);
    });

    test('partial coverage identifies missing allergens', () {
      final result = computeAllergenCoverage(
        activities: [
          _activity(
            type: 'solids',
            startTime: DateTime(2026, 3, 5, 10),
            allergenNames: ['dairy'],
          ),
        ],
        allergenCategories: ['dairy', 'egg', 'nuts'],
        referenceDate: refDate,
        periodDays: 7,
      );
      expect(result.covered, {'dairy'});
      expect(result.missing, {'egg', 'nuts'});
    });

    test('activities outside period are excluded', () {
      final result = computeAllergenCoverage(
        activities: [
          // 10 days ago — outside 7-day window
          _activity(
            type: 'solids',
            startTime: DateTime(2026, 2, 24, 10),
            allergenNames: ['egg'],
          ),
          // 3 days ago — within window
          _activity(
            type: 'solids',
            startTime: DateTime(2026, 3, 3, 10),
            allergenNames: ['dairy'],
          ),
        ],
        allergenCategories: ['dairy', 'egg'],
        referenceDate: refDate,
        periodDays: 7,
      );
      expect(result.covered, {'dairy'});
      expect(result.missing, {'egg'});
    });

    test('exposure counts are correct', () {
      final result = computeAllergenCoverage(
        activities: [
          _activity(
              type: 'solids',
              startTime: DateTime(2026, 3, 5, 8),
              allergenNames: ['dairy']),
          _activity(
              type: 'solids',
              startTime: DateTime(2026, 3, 5, 12),
              allergenNames: ['dairy', 'egg']),
          _activity(
              type: 'solids',
              startTime: DateTime(2026, 3, 4, 10),
              allergenNames: ['dairy']),
        ],
        allergenCategories: ['dairy', 'egg'],
        referenceDate: refDate,
        periodDays: 7,
      );
      expect(result.exposureCounts['dairy'], 3);
      expect(result.exposureCounts['egg'], 1);
    });

    test('last exposed dates are correct', () {
      final result = computeAllergenCoverage(
        activities: [
          _activity(
              type: 'solids',
              startTime: DateTime(2026, 3, 3, 8),
              allergenNames: ['dairy']),
          _activity(
              type: 'solids',
              startTime: DateTime(2026, 3, 5, 12),
              allergenNames: ['dairy']),
        ],
        allergenCategories: ['dairy'],
        referenceDate: refDate,
        periodDays: 7,
      );
      expect(result.lastExposed['dairy'], DateTime(2026, 3, 5, 12));
    });

    test('non-solids activities are ignored', () {
      final result = computeAllergenCoverage(
        activities: [
          _activity(type: 'feedBottle', startTime: DateTime(2026, 3, 5)),
          _activity(type: 'diaper', startTime: DateTime(2026, 3, 5)),
        ],
        allergenCategories: ['dairy'],
        referenceDate: refDate,
        periodDays: 7,
      );
      expect(result.covered, isEmpty);
      expect(result.missing, {'dairy'});
    });

    test('activities without allergenNames are ignored', () {
      final result = computeAllergenCoverage(
        activities: [
          _activity(
              type: 'solids',
              startTime: DateTime(2026, 3, 5),
              foodDescription: 'banana'),
        ],
        allergenCategories: ['dairy'],
        referenceDate: refDate,
        periodDays: 7,
      );
      expect(result.covered, isEmpty);
      expect(result.missing, {'dairy'});
    });

    test('case-insensitive matching', () {
      final result = computeAllergenCoverage(
        activities: [
          _activity(
              type: 'solids',
              startTime: DateTime(2026, 3, 5),
              allergenNames: ['Dairy']),
        ],
        allergenCategories: ['dairy'],
        referenceDate: refDate,
        periodDays: 7,
      );
      expect(result.covered, {'dairy'});
    });

    test('14-day period extends further back', () {
      final result = computeAllergenCoverage(
        activities: [
          // 10 days ago — within 14d but outside 7d
          _activity(
            type: 'solids',
            startTime: DateTime(2026, 2, 24, 10),
            allergenNames: ['egg'],
          ),
        ],
        allergenCategories: ['egg'],
        referenceDate: refDate,
        periodDays: 14,
      );
      expect(result.covered, {'egg'});
    });
  });

  // ========================================================================
  // computeWeeklyAllergenMatrix
  // ========================================================================
  group('computeWeeklyAllergenMatrix', () {
    // 2026-03-06 is a Friday. Monday of that week = 2026-03-02.
    final refDate = DateTime(2026, 3, 6);

    test('generates 7 days starting Monday', () {
      final result = computeWeeklyAllergenMatrix(
        activities: [],
        allergenCategories: ['dairy'],
        referenceDate: refDate,
      );
      expect(result.days.length, 7);
      expect(result.days[0], DateTime(2026, 3, 2)); // Monday
      expect(result.days[6], DateTime(2026, 3, 8)); // Sunday
    });

    test('empty activities produce empty matrix', () {
      final result = computeWeeklyAllergenMatrix(
        activities: [],
        allergenCategories: ['dairy', 'egg'],
        referenceDate: refDate,
      );
      expect(result.matrix['dairy'], isEmpty);
      expect(result.matrix['egg'], isEmpty);
    });

    test('activities mark correct day indices', () {
      final result = computeWeeklyAllergenMatrix(
        activities: [
          // Monday (index 0)
          _activity(
            type: 'solids',
            startTime: DateTime(2026, 3, 2, 10),
            allergenNames: ['dairy'],
          ),
          // Wednesday (index 2)
          _activity(
            type: 'solids',
            startTime: DateTime(2026, 3, 4, 12),
            allergenNames: ['dairy', 'egg'],
          ),
          // Friday (index 4)
          _activity(
            type: 'solids',
            startTime: DateTime(2026, 3, 6, 8),
            allergenNames: ['egg'],
          ),
        ],
        allergenCategories: ['dairy', 'egg'],
        referenceDate: refDate,
      );
      expect(result.matrix['dairy'], {0, 2});
      expect(result.matrix['egg'], {2, 4});
    });

    test('activities outside the week are ignored', () {
      final result = computeWeeklyAllergenMatrix(
        activities: [
          // Previous week — Sunday Feb 28 (before Monday Mar 2)
          _activity(
            type: 'solids',
            startTime: DateTime(2026, 3, 1, 10), // Sunday before
            allergenNames: ['dairy'],
          ),
          // Next week — Monday Mar 9
          _activity(
            type: 'solids',
            startTime: DateTime(2026, 3, 9, 10),
            allergenNames: ['dairy'],
          ),
        ],
        allergenCategories: ['dairy'],
        referenceDate: refDate,
      );
      expect(result.matrix['dairy'], isEmpty);
    });

    test('multiple activities on same day deduplicate', () {
      final result = computeWeeklyAllergenMatrix(
        activities: [
          _activity(
            type: 'solids',
            startTime: DateTime(2026, 3, 3, 8),
            allergenNames: ['dairy'],
          ),
          _activity(
            type: 'solids',
            startTime: DateTime(2026, 3, 3, 12),
            allergenNames: ['dairy'],
          ),
        ],
        allergenCategories: ['dairy'],
        referenceDate: refDate,
      );
      // Tuesday = index 1, should appear only once
      expect(result.matrix['dairy'], {1});
    });

    test('allergens not in categories are excluded from matrix keys', () {
      final result = computeWeeklyAllergenMatrix(
        activities: [
          _activity(
            type: 'solids',
            startTime: DateTime(2026, 3, 5, 10),
            allergenNames: ['dairy', 'soy'],
          ),
        ],
        allergenCategories: ['dairy'],
        referenceDate: refDate,
      );
      expect(result.matrix.containsKey('dairy'), isTrue);
      expect(result.matrix.containsKey('soy'), isFalse);
    });

    test('case-insensitive matching for allergens', () {
      final result = computeWeeklyAllergenMatrix(
        activities: [
          _activity(
            type: 'solids',
            startTime: DateTime(2026, 3, 5, 10),
            allergenNames: ['Dairy'],
          ),
        ],
        allergenCategories: ['dairy'],
        referenceDate: refDate,
      );
      expect(result.matrix['dairy'], {3}); // Thursday = index 3
    });
  });

  // ========================================================================
  // computeAllergenIngredientDrilldown
  // ========================================================================
  group('computeAllergenIngredientDrilldown', () {
    final refDate = DateTime(2026, 3, 6);

    final ingredients = [
      _ingredient('whole milk', ['dairy']),
      _ingredient('cheese', ['dairy']),
      _ingredient('yogurt', ['dairy']),
      _ingredient('egg', ['egg']),
      _ingredient('bread', ['gluten']),
    ];

    test('returns only ingredients tagged with the allergen', () {
      final result = computeAllergenIngredientDrilldown(
        activities: [],
        ingredients: ingredients,
        allergenCategory: 'dairy',
        referenceDate: refDate,
        periodDays: 30,
      );
      expect(result.length, 3);
      final names = result.map((d) => d.ingredientName).toSet();
      expect(names, {'whole milk', 'cheese', 'yogurt'});
    });

    test('returns empty for unknown allergen', () {
      final result = computeAllergenIngredientDrilldown(
        activities: [],
        ingredients: ingredients,
        allergenCategory: 'soy',
        referenceDate: refDate,
        periodDays: 30,
      );
      expect(result, isEmpty);
    });

    test('counts exposures per ingredient', () {
      final result = computeAllergenIngredientDrilldown(
        activities: [
          _activity(
            type: 'solids',
            startTime: DateTime(2026, 3, 5, 10),
            ingredientNames: ['whole milk', 'cheese'],
            recipeId: 'r1',
          ),
          _activity(
            type: 'solids',
            startTime: DateTime(2026, 3, 4, 10),
            ingredientNames: ['whole milk'],
            recipeId: 'r2',
          ),
          _activity(
            type: 'solids',
            startTime: DateTime(2026, 3, 3, 10),
            ingredientNames: ['yogurt'],
            recipeId: 'r3',
          ),
        ],
        ingredients: ingredients,
        allergenCategory: 'dairy',
        referenceDate: refDate,
        periodDays: 30,
      );
      final byName = {for (final d in result) d.ingredientName: d};
      expect(byName['whole milk']!.exposureCount, 2);
      expect(byName['cheese']!.exposureCount, 1);
      expect(byName['yogurt']!.exposureCount, 1);
    });

    test('tracks last exposure date', () {
      final result = computeAllergenIngredientDrilldown(
        activities: [
          _activity(
            type: 'solids',
            startTime: DateTime(2026, 3, 3, 10),
            ingredientNames: ['whole milk'],
            recipeId: 'r1',
          ),
          _activity(
            type: 'solids',
            startTime: DateTime(2026, 3, 5, 14),
            ingredientNames: ['whole milk'],
            recipeId: 'r2',
          ),
        ],
        ingredients: ingredients,
        allergenCategory: 'dairy',
        referenceDate: refDate,
        periodDays: 30,
      );
      final milk = result.firstWhere((d) => d.ingredientName == 'whole milk');
      expect(milk.lastExposure, DateTime(2026, 3, 5, 14));
    });

    test('ingredients with zero exposures still appear', () {
      final result = computeAllergenIngredientDrilldown(
        activities: [],
        ingredients: ingredients,
        allergenCategory: 'dairy',
        referenceDate: refDate,
        periodDays: 30,
      );
      expect(result.length, 3);
      for (final d in result) {
        expect(d.exposureCount, 0);
        expect(d.lastExposure, isNull);
      }
    });

    test('results sorted by exposure count descending', () {
      final result = computeAllergenIngredientDrilldown(
        activities: [
          _activity(
              type: 'solids',
              startTime: DateTime(2026, 3, 5),
              ingredientNames: ['cheese'],
              recipeId: 'r1'),
          _activity(
              type: 'solids',
              startTime: DateTime(2026, 3, 4),
              ingredientNames: ['whole milk'],
              recipeId: 'r2'),
          _activity(
              type: 'solids',
              startTime: DateTime(2026, 3, 3),
              ingredientNames: ['whole milk'],
              recipeId: 'r3'),
          _activity(
              type: 'solids',
              startTime: DateTime(2026, 3, 2),
              ingredientNames: ['whole milk'],
              recipeId: 'r4'),
        ],
        ingredients: ingredients,
        allergenCategory: 'dairy',
        referenceDate: refDate,
        periodDays: 30,
      );
      expect(result[0].ingredientName, 'whole milk');
      expect(result[0].exposureCount, 3);
      expect(result[1].ingredientName, 'cheese');
      expect(result[1].exposureCount, 1);
      expect(result[2].ingredientName, 'yogurt');
      expect(result[2].exposureCount, 0);
    });

    test('activities outside period are excluded', () {
      final result = computeAllergenIngredientDrilldown(
        activities: [
          // 40 days ago — outside 30-day window
          _activity(
            type: 'solids',
            startTime: DateTime(2026, 1, 25, 10),
            ingredientNames: ['whole milk'],
            recipeId: 'r1',
          ),
        ],
        ingredients: ingredients,
        allergenCategory: 'dairy',
        referenceDate: refDate,
        periodDays: 30,
      );
      final milk = result.firstWhere((d) => d.ingredientName == 'whole milk');
      expect(milk.exposureCount, 0);
    });

    test('case-insensitive allergen matching', () {
      final result = computeAllergenIngredientDrilldown(
        activities: [],
        ingredients: ingredients,
        allergenCategory: 'DAIRY',
        referenceDate: refDate,
        periodDays: 30,
      );
      expect(result.length, 3);
    });

    test('non-solids activities are ignored', () {
      final result = computeAllergenIngredientDrilldown(
        activities: [
          _activity(type: 'feedBottle', startTime: DateTime(2026, 3, 5)),
        ],
        ingredients: ingredients,
        allergenCategory: 'dairy',
        referenceDate: refDate,
        periodDays: 30,
      );
      for (final d in result) {
        expect(d.exposureCount, 0);
      }
    });
  });

  // ========================================================================
  // computeTrendForMetric
  // ========================================================================
  group('computeTrendForMetric', () {
    final refDate = DateTime(2026, 3, 6);

    test('returns empty for invalid metric key (no dot)', () {
      final result = computeTrendForMetric(
        activities: [],
        metricKey: 'invalidKey',
        referenceDate: refDate,
        days: 7,
      );
      expect(result, isEmpty);
    });

    test('returns correct number of points for 7 days', () {
      final result = computeTrendForMetric(
        activities: [],
        metricKey: 'feedBottle.totalVolumeMl',
        referenceDate: refDate,
        days: 7,
      );
      expect(result.length, 7);
    });

    test('returns correct number of points for 30 days', () {
      final result = computeTrendForMetric(
        activities: [],
        metricKey: 'feedBottle.totalVolumeMl',
        referenceDate: refDate,
        days: 30,
      );
      expect(result.length, 30);
    });

    test('dates go from oldest to most recent', () {
      final result = computeTrendForMetric(
        activities: [],
        metricKey: 'feedBottle.totalVolumeMl',
        referenceDate: refDate,
        days: 7,
      );
      // First point is 6 days ago, last is today
      expect(result.first.date, DateTime(2026, 2, 28));
      expect(result.last.date, DateTime(2026, 3, 6));
    });

    test('computes feed volume per day correctly', () {
      final result = computeTrendForMetric(
        activities: [
          _activity(
            type: 'feedBottle',
            startTime: DateTime(2026, 3, 5, 8),
            volumeMl: 120,
          ),
          _activity(
            type: 'feedBottle',
            startTime: DateTime(2026, 3, 5, 14),
            volumeMl: 150,
          ),
          _activity(
            type: 'feedBottle',
            startTime: DateTime(2026, 3, 6, 9),
            volumeMl: 100,
          ),
        ],
        metricKey: 'feedBottle.totalVolumeMl',
        referenceDate: refDate,
        days: 7,
      );
      // Mar 5 = index 5 (day 6 of 7)
      expect(result[5].value, 270); // 120 + 150
      // Mar 6 = index 6 (last day)
      expect(result[6].value, 100);
    });

    test('computes diaper count per day', () {
      final result = computeTrendForMetric(
        activities: [
          _activity(
            type: 'diaper',
            startTime: DateTime(2026, 3, 4, 8),
            contents: 'pee',
          ),
          _activity(
            type: 'diaper',
            startTime: DateTime(2026, 3, 4, 12),
            contents: 'poo',
          ),
          _activity(
            type: 'diaper',
            startTime: DateTime(2026, 3, 4, 18),
            contents: 'pee',
          ),
        ],
        metricKey: 'diaper.count',
        referenceDate: refDate,
        days: 7,
      );
      // Mar 4 = index 4
      expect(result[4].value, 3);
    });

    test('days without activities show zero', () {
      final result = computeTrendForMetric(
        activities: [
          _activity(
            type: 'feedBottle',
            startTime: DateTime(2026, 3, 6, 10),
            volumeMl: 100,
          ),
        ],
        metricKey: 'feedBottle.totalVolumeMl',
        referenceDate: refDate,
        days: 7,
      );
      // All days except the last should be zero
      for (int i = 0; i < 6; i++) {
        expect(result[i].value, 0, reason: 'Day $i should be zero');
      }
      expect(result[6].value, 100);
    });

    test('activities outside period are excluded', () {
      final result = computeTrendForMetric(
        activities: [
          _activity(
            type: 'feedBottle',
            startTime: DateTime(2026, 2, 20, 10), // way before 7-day window
            volumeMl: 500,
          ),
        ],
        metricKey: 'feedBottle.totalVolumeMl',
        referenceDate: refDate,
        days: 7,
      );
      for (final p in result) {
        expect(p.value, 0);
      }
    });

    test('computes solids count per day', () {
      final result = computeTrendForMetric(
        activities: [
          _activity(
            type: 'solids',
            startTime: DateTime(2026, 3, 3, 12),
            foodDescription: 'banana',
          ),
          _activity(
            type: 'solids',
            startTime: DateTime(2026, 3, 3, 18),
            foodDescription: 'avocado',
          ),
        ],
        metricKey: 'solids.count',
        referenceDate: refDate,
        days: 7,
      );
      // Mar 3 = index 3
      expect(result[3].value, 2);
    });

    test('computes tummy time duration per day', () {
      final result = computeTrendForMetric(
        activities: [
          _activity(
            type: 'tummyTime',
            startTime: DateTime(2026, 3, 6, 9),
            durationMinutes: 15,
          ),
          _activity(
            type: 'tummyTime',
            startTime: DateTime(2026, 3, 6, 14),
            durationMinutes: 20,
          ),
        ],
        metricKey: 'tummyTime.totalDurationMinutes',
        referenceDate: refDate,
        days: 7,
      );
      expect(result[6].value, 35); // 15 + 20
    });

    test('does not mix activity types', () {
      final result = computeTrendForMetric(
        activities: [
          _activity(
            type: 'feedBottle',
            startTime: DateTime(2026, 3, 5, 10),
            volumeMl: 200,
          ),
          _activity(
            type: 'diaper',
            startTime: DateTime(2026, 3, 5, 12),
            contents: 'pee',
          ),
        ],
        metricKey: 'feedBottle.totalVolumeMl',
        referenceDate: refDate,
        days: 7,
      );
      // Should only count feedBottle volume, not diaper
      expect(result[5].value, 200);
    });

    test('boundary: activity at exactly midnight counts for that day', () {
      final result = computeTrendForMetric(
        activities: [
          _activity(
            type: 'feedBottle',
            startTime: DateTime(2026, 3, 5, 0, 0, 0), // midnight
            volumeMl: 100,
          ),
        ],
        metricKey: 'feedBottle.totalVolumeMl',
        referenceDate: refDate,
        days: 7,
      );
      expect(result[5].value, 100); // Mar 5
    });

    test('boundary: activity at 23:59:59 counts for that day', () {
      final result = computeTrendForMetric(
        activities: [
          _activity(
            type: 'feedBottle',
            startTime: DateTime(2026, 3, 5, 23, 59, 59),
            volumeMl: 100,
          ),
        ],
        metricKey: 'feedBottle.totalVolumeMl',
        referenceDate: refDate,
        days: 7,
      );
      expect(result[5].value, 100); // Mar 5
    });

    test('single day period returns one point', () {
      final result = computeTrendForMetric(
        activities: [
          _activity(
            type: 'feedBottle',
            startTime: DateTime(2026, 3, 6, 10),
            volumeMl: 200,
          ),
        ],
        metricKey: 'feedBottle.totalVolumeMl',
        referenceDate: refDate,
        days: 1,
      );
      expect(result.length, 1);
      expect(result[0].date, DateTime(2026, 3, 6));
      expect(result[0].value, 200);
    });

    test('unknown metric in valid key returns zero values', () {
      final result = computeTrendForMetric(
        activities: [
          _activity(
            type: 'feedBottle',
            startTime: DateTime(2026, 3, 6, 10),
            volumeMl: 200,
          ),
        ],
        metricKey: 'feedBottle.unknownMetric',
        referenceDate: refDate,
        days: 3,
      );
      expect(result.length, 3);
      for (final p in result) {
        expect(p.value, 0);
      }
    });
  });

  // ========================================================================
  // Edge cases
  // ========================================================================
  group('edge cases', () {
    test('allergen coverage with empty activities', () {
      final result = computeAllergenCoverage(
        activities: [],
        allergenCategories: ['dairy', 'egg'],
        referenceDate: DateTime(2026, 3, 6),
        periodDays: 7,
      );
      expect(result.covered, isEmpty);
      expect(result.missing, {'dairy', 'egg'});
      expect(result.exposureCounts, isEmpty);
    });

    test('weekly matrix with empty categories', () {
      final result = computeWeeklyAllergenMatrix(
        activities: [],
        allergenCategories: [],
        referenceDate: DateTime(2026, 3, 6),
      );
      expect(result.allergens, isEmpty);
      expect(result.matrix, isEmpty);
    });

    test('allergen coverage boundary — activity exactly at cutoff', () {
      final refDate = DateTime(2026, 3, 6);
      // Cutoff is midnight Mar 6 - 7 days = midnight Feb 27.
      // Activity at Feb 27 00:00:00 should be excluded (isBefore cutoff is false
      // but it IS the cutoff boundary).
      final result = computeAllergenCoverage(
        activities: [
          _activity(
            type: 'solids',
            startTime: DateTime(2026, 2, 27, 0, 0, 0),
            allergenNames: ['dairy'],
          ),
        ],
        allergenCategories: ['dairy'],
        referenceDate: refDate,
        periodDays: 7,
      );
      // Feb 27 is exactly 7 days before Mar 6 — it's at the cutoff boundary.
      // isBefore(cutoff) returns false for equal timestamps, so it IS included.
      expect(result.covered, {'dairy'});
    });

    test('drilldown with ingredientNames containing whitespace', () {
      final ingredients = [_ingredient('egg', ['egg'])];
      final result = computeAllergenIngredientDrilldown(
        activities: [
          _activity(
            type: 'solids',
            startTime: DateTime(2026, 3, 5),
            ingredientNames: [' egg ', 'Egg'],
            recipeId: 'r1',
          ),
        ],
        ingredients: ingredients,
        allergenCategory: 'egg',
        referenceDate: DateTime(2026, 3, 6),
        periodDays: 30,
      );
      final egg = result.firstWhere((d) => d.ingredientName == 'egg');
      // Both ' egg ' and 'Egg' normalize to 'egg' and should count
      expect(egg.exposureCount, 2);
    });
  });

  // ========================================================================
  // computeAllergenCoverage with targets
  // ========================================================================
  group('computeAllergenCoverage with targets', () {
    final refDate = DateTime(2026, 3, 6);

    test('weekly target met → covered', () {
      final result = computeAllergenCoverage(
        activities: [
          _activity(type: 'solids', startTime: DateTime(2026, 3, 3, 8),
              allergenNames: ['dairy']),
          _activity(type: 'solids', startTime: DateTime(2026, 3, 4, 8),
              allergenNames: ['dairy']),
          _activity(type: 'solids', startTime: DateTime(2026, 3, 5, 8),
              allergenNames: ['dairy']),
        ],
        allergenCategories: ['dairy'],
        referenceDate: refDate,
        periodDays: 7,
        targets: [_allergenTarget('dairy', targetValue: 3, period: 'weekly')],
      );
      expect(result.covered, {'dairy'});
      expect(result.missing, isEmpty);
      expect(result.targetProgress['dairy']!.fraction, 1.0);
    });

    test('weekly target not met → missing', () {
      final result = computeAllergenCoverage(
        activities: [
          _activity(type: 'solids', startTime: DateTime(2026, 3, 5, 8),
              allergenNames: ['dairy']),
        ],
        allergenCategories: ['dairy'],
        referenceDate: refDate,
        periodDays: 7,
        targets: [_allergenTarget('dairy', targetValue: 3, period: 'weekly')],
      );
      expect(result.missing, {'dairy'});
      expect(result.covered, isEmpty);
      final tp = result.targetProgress['dairy']!;
      expect(tp.actual, 1.0);
      expect(tp.scaledTarget, 3.0);
      expect(tp.fraction, closeTo(0.333, 0.01));
    });

    test('daily target scaled to period', () {
      final result = computeAllergenCoverage(
        activities: [
          _activity(type: 'solids', startTime: DateTime(2026, 3, 3, 8),
              allergenNames: ['egg']),
          _activity(type: 'solids', startTime: DateTime(2026, 3, 5, 8),
              allergenNames: ['egg']),
        ],
        allergenCategories: ['egg'],
        referenceDate: refDate,
        periodDays: 7,
        targets: [_allergenTarget('egg', targetValue: 1, period: 'daily')],
      );
      // daily target 1 * 7 days = 7, actual = 2
      final tp = result.targetProgress['egg']!;
      expect(tp.scaledTarget, 7.0);
      expect(tp.actual, 2.0);
      expect(tp.fraction, closeTo(0.286, 0.01));
    });

    test('allergens without targets use binary coverage', () {
      final result = computeAllergenCoverage(
        activities: [
          _activity(type: 'solids', startTime: DateTime(2026, 3, 5, 8),
              allergenNames: ['dairy', 'egg']),
        ],
        allergenCategories: ['dairy', 'egg', 'nuts'],
        referenceDate: refDate,
        periodDays: 7,
        targets: [_allergenTarget('dairy', targetValue: 5, period: 'weekly')],
      );
      // dairy: has target (1/5 < 1.0) → missing
      expect(result.missing, contains('dairy'));
      // egg: no target, has exposure → covered (binary)
      expect(result.covered, contains('egg'));
      // nuts: no target, no exposure → missing
      expect(result.missing, contains('nuts'));
    });

    test('non-allergenExposures targets are ignored', () {
      final now = DateTime(2026, 3, 1);
      final countTarget = TargetModel(
        id: 'target-count',
        childId: 'child-1',
        activityType: 'solids',
        metric: 'count',
        period: 'weekly',
        targetValue: 10,
        createdBy: 'uid-1',
        createdAt: now,
        modifiedAt: now,
      );
      final result = computeAllergenCoverage(
        activities: [
          _activity(type: 'solids', startTime: DateTime(2026, 3, 5, 8),
              allergenNames: ['dairy']),
        ],
        allergenCategories: ['dairy'],
        referenceDate: refDate,
        periodDays: 7,
        targets: [countTarget],
      );
      // No allergen target → binary coverage
      expect(result.targetProgress, isEmpty);
      expect(result.covered, {'dairy'});
    });

    test('target progress fraction clamped to 1.0', () {
      final result = computeAllergenCoverage(
        activities: List.generate(
          10,
          (i) => _activity(
            type: 'solids',
            startTime: DateTime(2026, 3, 5, i),
            allergenNames: ['dairy'],
          ),
        ),
        allergenCategories: ['dairy'],
        referenceDate: refDate,
        periodDays: 7,
        targets: [_allergenTarget('dairy', targetValue: 3, period: 'weekly')],
      );
      expect(result.targetProgress['dairy']!.fraction, 1.0);
      expect(result.targetProgress['dairy']!.actual, 10.0);
    });

    test('14-day period scales weekly target', () {
      final result = computeAllergenCoverage(
        activities: [
          _activity(type: 'solids', startTime: DateTime(2026, 3, 3, 8),
              allergenNames: ['dairy']),
          _activity(type: 'solids', startTime: DateTime(2026, 3, 4, 8),
              allergenNames: ['dairy']),
          _activity(type: 'solids', startTime: DateTime(2026, 3, 5, 8),
              allergenNames: ['dairy']),
        ],
        allergenCategories: ['dairy'],
        referenceDate: refDate,
        periodDays: 14,
        targets: [_allergenTarget('dairy', targetValue: 3, period: 'weekly')],
      );
      // weekly target 3 * (14/7) = 6, actual = 3
      final tp = result.targetProgress['dairy']!;
      expect(tp.scaledTarget, 6.0);
      expect(tp.actual, 3.0);
      expect(tp.fraction, 0.5);
    });

    test('zero exposures with target → missing with fraction 0', () {
      final result = computeAllergenCoverage(
        activities: [],
        allergenCategories: ['dairy'],
        referenceDate: refDate,
        periodDays: 7,
        targets: [_allergenTarget('dairy', targetValue: 3, period: 'weekly')],
      );
      expect(result.missing, {'dairy'});
      expect(result.covered, isEmpty);
      final tp = result.targetProgress['dairy']!;
      expect(tp.actual, 0.0);
      expect(tp.scaledTarget, 3.0);
      expect(tp.fraction, 0.0);
    });

    test('monthly target scaled to 7-day period', () {
      final result = computeAllergenCoverage(
        activities: [
          _activity(type: 'solids', startTime: DateTime(2026, 3, 5, 8),
              allergenNames: ['sesame']),
        ],
        allergenCategories: ['sesame'],
        referenceDate: refDate,
        periodDays: 7,
        targets: [
          _allergenTarget('sesame', targetValue: 6, period: 'monthly')
        ],
      );
      // monthly target 6 * (7/30) = 1.4
      final tp = result.targetProgress['sesame']!;
      expect(tp.scaledTarget, closeTo(1.4, 0.01));
      expect(tp.actual, 1.0);
      expect(tp.fraction, closeTo(0.714, 0.01));
    });

    test('case-insensitive target allergen matching', () {
      final result = computeAllergenCoverage(
        activities: [
          _activity(type: 'solids', startTime: DateTime(2026, 3, 5, 8),
              allergenNames: ['Dairy']),
        ],
        allergenCategories: ['dairy'],
        referenceDate: refDate,
        periodDays: 7,
        targets: [_allergenTarget('Dairy', targetValue: 1, period: 'weekly')],
      );
      expect(result.targetProgress['dairy'], isNotNull);
      expect(result.targetProgress['dairy']!.actual, 1.0);
      expect(result.covered, {'dairy'});
    });

    test('urgency: on track when recently given', () {
      final result = computeAllergenCoverage(
        activities: [
          // Given today
          _activity(type: 'solids', startTime: DateTime(2026, 3, 6, 8),
              allergenNames: ['dairy']),
          _activity(type: 'solids', startTime: DateTime(2026, 3, 5, 8),
              allergenNames: ['dairy']),
          _activity(type: 'solids', startTime: DateTime(2026, 3, 4, 8),
              allergenNames: ['dairy']),
        ],
        allergenCategories: ['dairy'],
        referenceDate: refDate,
        periodDays: 7,
        targets: [_allergenTarget('dairy', targetValue: 3, period: 'weekly')],
      );
      final u = result.urgencyInfo['dairy']!;
      expect(u.urgency, AllergenUrgency.onTrack);
      expect(u.daysSinceExposure, 0);
      // Expected interval: 7/3 ≈ 2.33 days
      expect(u.expectedIntervalDays, closeTo(2.33, 0.01));
    });

    test('urgency: due when approaching interval', () {
      final result = computeAllergenCoverage(
        activities: [
          // Last given 3 days ago (interval = 7/3 ≈ 2.33)
          _activity(type: 'solids', startTime: DateTime(2026, 3, 3, 8),
              allergenNames: ['dairy']),
        ],
        allergenCategories: ['dairy'],
        referenceDate: refDate,
        periodDays: 7,
        targets: [_allergenTarget('dairy', targetValue: 3, period: 'weekly')],
      );
      final u = result.urgencyInfo['dairy']!;
      expect(u.urgency, AllergenUrgency.due);
      expect(u.daysSinceExposure, 3);
    });

    test('urgency: overdue when exceeding 1.5x interval', () {
      final result = computeAllergenCoverage(
        activities: [
          // Last given 5 days ago (interval = 7/3 ≈ 2.33, 1.5x = 3.5)
          _activity(type: 'solids', startTime: DateTime(2026, 3, 1, 8),
              allergenNames: ['dairy']),
        ],
        allergenCategories: ['dairy'],
        referenceDate: refDate,
        periodDays: 7,
        targets: [_allergenTarget('dairy', targetValue: 3, period: 'weekly')],
      );
      final u = result.urgencyInfo['dairy']!;
      expect(u.urgency, AllergenUrgency.overdue);
      expect(u.daysSinceExposure, 5);
    });

    test('urgency: never given → overdue with 999 days', () {
      final result = computeAllergenCoverage(
        activities: [],
        allergenCategories: ['dairy'],
        referenceDate: refDate,
        periodDays: 7,
        targets: [_allergenTarget('dairy', targetValue: 3, period: 'weekly')],
      );
      final u = result.urgencyInfo['dairy']!;
      expect(u.urgency, AllergenUrgency.overdue);
      expect(u.daysSinceExposure, 999);
    });

    test('urgency: uses all-time last exposure not just window', () {
      final result = computeAllergenCoverage(
        activities: [
          // Given 10 days ago — outside 7-day window but still the last exposure
          _activity(type: 'solids', startTime: DateTime(2026, 2, 24, 8),
              allergenNames: ['dairy']),
        ],
        allergenCategories: ['dairy'],
        referenceDate: refDate,
        periodDays: 7,
        targets: [_allergenTarget('dairy', targetValue: 3, period: 'weekly')],
      );
      final u = result.urgencyInfo['dairy']!;
      expect(u.daysSinceExposure, 10);
      expect(u.urgency, AllergenUrgency.overdue);
      // The activity should be outside the window so count is 0
      expect(result.exposureCounts['dairy'], isNull);
    });

    test('urgency: not computed for allergens without targets', () {
      final result = computeAllergenCoverage(
        activities: [
          _activity(type: 'solids', startTime: DateTime(2026, 3, 5, 8),
              allergenNames: ['dairy']),
        ],
        allergenCategories: ['dairy'],
        referenceDate: refDate,
        periodDays: 7,
      );
      expect(result.urgencyInfo, isEmpty);
    });

    test('multiple allergens with mixed target and binary coverage', () {
      final result = computeAllergenCoverage(
        activities: [
          _activity(type: 'solids', startTime: DateTime(2026, 3, 5, 8),
              allergenNames: ['dairy', 'egg', 'soy']),
          _activity(type: 'solids', startTime: DateTime(2026, 3, 4, 8),
              allergenNames: ['dairy', 'egg']),
          _activity(type: 'solids', startTime: DateTime(2026, 3, 3, 8),
              allergenNames: ['dairy']),
        ],
        allergenCategories: ['dairy', 'egg', 'soy', 'nuts', 'sesame'],
        referenceDate: refDate,
        periodDays: 7,
        targets: [
          _allergenTarget('dairy', targetValue: 3, period: 'weekly'),
          _allergenTarget('egg', targetValue: 3, period: 'weekly'),
          _allergenTarget('nuts', targetValue: 2, period: 'weekly'),
        ],
      );
      // dairy: 3/3 → covered
      expect(result.covered, contains('dairy'));
      expect(result.targetProgress['dairy']!.fraction, 1.0);
      // egg: 2/3 → missing (partial)
      expect(result.missing, contains('egg'));
      expect(result.targetProgress['egg']!.fraction, closeTo(0.667, 0.01));
      // soy: no target, 1 exposure → covered (binary)
      expect(result.covered, contains('soy'));
      // nuts: 0/2 → missing (zero)
      expect(result.missing, contains('nuts'));
      expect(result.targetProgress['nuts']!.actual, 0.0);
      // sesame: no target, 0 exposure → missing (binary)
      expect(result.missing, contains('sesame'));
      expect(result.targetProgress.containsKey('sesame'), isFalse);
    });
  });

  // ========================================================================
  // allergenExposureDays metric
  // ========================================================================
  group('allergenExposureDays', () {
    test('extractMetricFromSummary counts distinct days', () {
      final summary = ActivityAggregator.compute([
        // Two solids on same day with dairy
        _activity(
          type: 'solids',
          startTime: DateTime(2026, 3, 6, 8, 0),
          allergenNames: ['dairy'],
        ),
        _activity(
          type: 'solids',
          startTime: DateTime(2026, 3, 6, 12, 0),
          allergenNames: ['dairy'],
        ),
        // One solid on different day
        _activity(
          type: 'solids',
          startTime: DateTime(2026, 3, 5, 10, 0),
          allergenNames: ['dairy'],
        ),
      ]);
      final result = extractMetricFromSummary(
        'solids',
        'allergenExposureDays',
        summary,
        allergenName: 'dairy',
      );
      // 3 exposures but only 2 distinct days
      expect(result, 2.0);
    });

    test('extractMetricFromSummary returns 0 for unseen allergen', () {
      final summary = ActivityAggregator.compute([
        _activity(
          type: 'solids',
          startTime: DateTime(2026, 3, 6),
          allergenNames: ['dairy'],
        ),
      ]);
      final result = extractMetricFromSummary(
        'solids',
        'allergenExposureDays',
        summary,
        allergenName: 'egg',
      );
      expect(result, 0.0);
    });

    test('extractMetricFromSummary requires allergenName', () {
      final summary = ActivityAggregator.compute([
        _activity(
          type: 'solids',
          startTime: DateTime(2026, 3, 6),
          allergenNames: ['dairy'],
        ),
      ]);
      final result = extractMetricFromSummary(
        'solids',
        'allergenExposureDays',
        summary,
      );
      expect(result, isNull);
    });

    test('computeAllergenCoverage uses day-based target for progress', () {
      final ref = DateTime(2026, 3, 7);
      final result = computeAllergenCoverage(
        activities: [
          // 3 exposures on 2 distinct days
          _activity(
            type: 'solids',
            startTime: DateTime(2026, 3, 6, 8, 0),
            allergenNames: ['dairy'],
          ),
          _activity(
            type: 'solids',
            startTime: DateTime(2026, 3, 6, 18, 0),
            allergenNames: ['dairy'],
          ),
          _activity(
            type: 'solids',
            startTime: DateTime(2026, 3, 5, 10, 0),
            allergenNames: ['dairy'],
          ),
        ],
        allergenCategories: ['dairy'],
        referenceDate: ref,
        periodDays: 7,
        targets: [
          _allergenTarget('dairy',
              targetValue: 3,
              period: 'weekly',
              metric: 'allergenExposureDays'),
        ],
      );
      // 2 days / 3 target → fraction ~0.667
      expect(result.targetProgress['dairy'], isNotNull);
      expect(
          result.targetProgress['dairy']!.actual, 2.0); // distinct days, not 3
      expect(
          result.targetProgress['dairy']!.fraction, closeTo(0.667, 0.01));
      expect(result.missing, contains('dairy')); // not met yet
    });

    test('computeAllergenCoverage marks day target as covered when met', () {
      final ref = DateTime(2026, 3, 7);
      final result = computeAllergenCoverage(
        activities: [
          _activity(
            type: 'solids',
            startTime: DateTime(2026, 3, 6, 8, 0),
            allergenNames: ['egg'],
          ),
          _activity(
            type: 'solids',
            startTime: DateTime(2026, 3, 5, 10, 0),
            allergenNames: ['egg'],
          ),
        ],
        allergenCategories: ['egg'],
        referenceDate: ref,
        periodDays: 7,
        targets: [
          _allergenTarget('egg',
              targetValue: 2,
              period: 'weekly',
              metric: 'allergenExposureDays'),
        ],
      );
      expect(result.targetProgress['egg']!.fraction, 1.0);
      expect(result.covered, contains('egg'));
    });

    test('urgencyInfo works with allergenExposureDays targets', () {
      final ref = DateTime(2026, 3, 7);
      final result = computeAllergenCoverage(
        activities: [
          _activity(
            type: 'solids',
            startTime: DateTime(2026, 3, 4, 10, 0), // 3 days ago
            allergenNames: ['dairy'],
          ),
        ],
        allergenCategories: ['dairy'],
        referenceDate: ref,
        periodDays: 7,
        targets: [
          // weekly target of 7 → expected interval = 1 day
          _allergenTarget('dairy',
              targetValue: 7,
              period: 'weekly',
              metric: 'allergenExposureDays'),
        ],
      );
      expect(result.urgencyInfo['dairy'], isNotNull);
      expect(result.urgencyInfo['dairy']!.daysSinceExposure, 3);
      // 3 > 1*1.5 → overdue
      expect(result.urgencyInfo['dairy']!.urgency, AllergenUrgency.overdue);
    });

    test('ActivityAggregator allergenExposureDays is case-insensitive', () {
      final summary = ActivityAggregator.compute([
        _activity(
          type: 'solids',
          startTime: DateTime(2026, 3, 6, 8, 0),
          allergenNames: ['Dairy'],
        ),
        _activity(
          type: 'solids',
          startTime: DateTime(2026, 3, 5, 10, 0),
          allergenNames: ['dairy'],
        ),
      ]);
      expect(summary.allergenExposureDays['dairy'], 2);
    });
  });
}
