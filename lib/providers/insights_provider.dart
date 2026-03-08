import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/activity_model.dart';
import '../models/enums.dart';
import '../models/ingredient_model.dart';
import '../models/target_model.dart';
import '../utils/activity_aggregator.dart';
import '../utils/activity_helpers.dart';
import 'activity_provider.dart';
import 'family_provider.dart';
import 'ingredient_provider.dart';
import 'target_provider.dart';

// ==========================================================================
// Data classes
// ==========================================================================

class InferredBaselines {
  final double avgBottleMl;
  final double avgBottleCount;
  final double avgBreastCount;
  final double avgBreastMinutes;
  final double avgDiaperCount;
  final double avgSolidsCount;
  final double avgTummyTimeMinutes;
  final int daysWithData;

  const InferredBaselines({
    required this.avgBottleMl,
    required this.avgBottleCount,
    required this.avgBreastCount,
    required this.avgBreastMinutes,
    required this.avgDiaperCount,
    required this.avgSolidsCount,
    required this.avgTummyTimeMinutes,
    required this.daysWithData,
  });
}

class MetricProgress {
  final String key;
  final String label;
  final double actual;
  final double target;
  final double fraction;
  final bool isExplicit;
  final IconData icon;
  final Color color;
  final String unit;

  const MetricProgress({
    required this.key,
    required this.label,
    required this.actual,
    required this.target,
    required this.fraction,
    required this.isExplicit,
    required this.icon,
    required this.color,
    this.unit = '',
  });
}

enum TrendMetric {
  feedVolume('Feed Volume'),
  diapers('Diapers'),
  solids('Solids'),
  tummyTime('Tummy Time');

  final String label;
  const TrendMetric(this.label);
}

class TrendPoint {
  final DateTime date;
  final double value;

  const TrendPoint({required this.date, required this.value});
}

class AllergenTargetProgress {
  final double actual;
  final double scaledTarget;
  final double fraction;

  const AllergenTargetProgress({
    required this.actual,
    required this.scaledTarget,
    required this.fraction,
  });
}

/// Urgency level for a single allergen relative to its maintenance target.
enum AllergenUrgency { onTrack, due, overdue }

class AllergenUrgencyInfo {
  final int daysSinceExposure;
  final double expectedIntervalDays;
  final AllergenUrgency urgency;

  const AllergenUrgencyInfo({
    required this.daysSinceExposure,
    required this.expectedIntervalDays,
    required this.urgency,
  });
}

class AllergenCoverage {
  final Set<String> covered;
  final Set<String> missing;
  final Map<String, int> exposureCounts;
  final Map<String, DateTime> lastExposed;
  final Map<String, AllergenTargetProgress> targetProgress;
  final Map<String, AllergenUrgencyInfo> urgencyInfo;

  const AllergenCoverage({
    required this.covered,
    required this.missing,
    required this.exposureCounts,
    required this.lastExposed,
    this.targetProgress = const {},
    this.urgencyInfo = const {},
  });
}

class WeeklyAllergenMatrix {
  final List<DateTime> days;
  final List<String> allergens;
  final Map<String, Set<int>> matrix; // allergen -> set of day indices

  const WeeklyAllergenMatrix({
    required this.days,
    required this.allergens,
    required this.matrix,
  });
}

class AllergenIngredientDetail {
  final String ingredientName;
  final DateTime? lastExposure;
  final int exposureCount;

  const AllergenIngredientDetail({
    required this.ingredientName,
    this.lastExposure,
    required this.exposureCount,
  });
}

// ==========================================================================
// Pure computation functions (public for testing)
// ==========================================================================

/// Extract a metric value from an ActivitySummary.
double? extractMetricFromSummary(
  String activityType,
  String metric,
  ActivitySummary summary, {
  String? ingredientName,
  String? allergenName,
}) {
  switch (metric) {
    case 'totalVolumeMl':
      if (activityType == ActivityType.feedBottle.name) {
        return summary.bottleFeedTotalMl;
      }
      if (activityType == ActivityType.pump.name) return summary.pumpTotalMl;
      return null;
    case 'count':
      if (activityType == ActivityType.feedBottle.name) {
        return summary.bottleFeedCount.toDouble();
      }
      if (activityType == ActivityType.feedBreast.name) {
        return summary.breastFeedCount.toDouble();
      }
      if (activityType == ActivityType.diaper.name) {
        return summary.diaperCount.toDouble();
      }
      if (activityType == ActivityType.solids.name) {
        return summary.solidsCount.toDouble();
      }
      if (activityType == ActivityType.pump.name) {
        return summary.pumpCount.toDouble();
      }
      if (activityType == ActivityType.potty.name) {
        return summary.pottyCount.toDouble();
      }
      return summary.durationCounts[activityType]?.toDouble();
    case 'uniqueFoods':
      if (activityType == ActivityType.solids.name) {
        return summary.uniqueFoods.length.toDouble();
      }
      return null;
    case 'totalDurationMinutes':
      if (activityType == ActivityType.feedBreast.name) {
        return summary.breastFeedTotalMinutes.toDouble();
      }
      return summary.durationTotals[activityType]?.toDouble();
    case 'ingredientExposures':
      if (ingredientName != null) {
        return summary
                .ingredientExposures[ingredientName.trim().toLowerCase()]
                ?.toDouble() ??
            0.0;
      }
      return null;
    case 'allergenExposures':
      if (allergenName != null) {
        return summary
                .allergenExposures[allergenName.trim().toLowerCase()]
                ?.toDouble() ??
            0.0;
      }
      return null;
    case 'allergenExposureDays':
      if (allergenName != null) {
        return summary
                .allergenExposureDays[allergenName.trim().toLowerCase()]
                ?.toDouble() ??
            0.0;
      }
      return null;
    default:
      return null;
  }
}

/// Scale a target value to match a coverage period in days.
double _scaleTarget(double targetValue, String period, int periodDays) {
  return switch (period) {
    'daily' => targetValue * periodDays,
    'weekly' => targetValue * (periodDays / 7),
    'monthly' => targetValue * (periodDays / 30),
    _ => targetValue,
  };
}

/// Compute allergen coverage from activities over a period.
/// When [targets] are provided, allergens with matching allergenExposures
/// targets use fractional progress (actual/scaled target) for coverage
/// determination instead of the default binary (>0) check.
AllergenCoverage computeAllergenCoverage({
  required List<ActivityModel> activities,
  required List<String> allergenCategories,
  required DateTime referenceDate,
  required int periodDays,
  List<TargetModel> targets = const [],
}) {
  if (allergenCategories.isEmpty) {
    return const AllergenCoverage(
      covered: {},
      missing: {},
      exposureCounts: {},
      lastExposed: {},
    );
  }

  final cutoff = DateTime(
    referenceDate.year,
    referenceDate.month,
    referenceDate.day,
  ).subtract(Duration(days: periodDays));

  final exposureCounts = <String, int>{};
  final lastExposed = <String, DateTime>{};
  final lastExposedAll = <String, DateTime>{}; // regardless of window

  for (final a in activities) {
    if (a.type != ActivityType.solids.name) continue;
    if (a.allergenNames == null) continue;

    for (final allergen in a.allergenNames!) {
      final normalized = allergen.trim().toLowerCase();
      // Track last exposure across all time.
      final existingAll = lastExposedAll[normalized];
      if (existingAll == null || a.startTime.isAfter(existingAll)) {
        lastExposedAll[normalized] = a.startTime;
      }
      // Only count within the window for progress.
      if (a.startTime.isBefore(cutoff)) continue;
      exposureCounts[normalized] = (exposureCounts[normalized] ?? 0) + 1;
      final existing = lastExposed[normalized];
      if (existing == null || a.startTime.isAfter(existing)) {
        lastExposed[normalized] = a.startTime;
      }
    }
  }

  // Count distinct exposure days per allergen within the window.
  final exposureDays = <String, Set<String>>{};
  for (final a in activities) {
    if (a.type != ActivityType.solids.name) continue;
    if (a.allergenNames == null) continue;
    if (a.startTime.isBefore(cutoff)) continue;
    final dayKey =
        '${a.startTime.year}-${a.startTime.month}-${a.startTime.day}';
    for (final allergen in a.allergenNames!) {
      final normalized = allergen.trim().toLowerCase();
      (exposureDays[normalized] ??= {}).add(dayKey);
    }
  }

  // Build target progress map from allergen targets.
  final targetProgress = <String, AllergenTargetProgress>{};
  for (final target in targets) {
    if (target.metric != TargetMetric.allergenExposures.name &&
        target.metric != TargetMetric.allergenExposureDays.name) continue;
    if (target.allergenName == null) continue;
    final normalized = target.allergenName!.trim().toLowerCase();
    // Don't overwrite if already set by a previous target for same allergen.
    if (targetProgress.containsKey(normalized)) continue;
    final scaledTarget =
        _scaleTarget(target.targetValue, target.period, periodDays);
    final actual = target.metric == TargetMetric.allergenExposureDays.name
        ? (exposureDays[normalized]?.length ?? 0).toDouble()
        : (exposureCounts[normalized] ?? 0).toDouble();
    final fraction = scaledTarget > 0 ? actual / scaledTarget : 0.0;
    targetProgress[normalized] = AllergenTargetProgress(
      actual: actual,
      scaledTarget: scaledTarget,
      fraction: fraction.clamp(0.0, 1.0),
    );
  }

  // Build urgency info for allergens with targets.
  final refDay = DateTime(
    referenceDate.year,
    referenceDate.month,
    referenceDate.day,
  );
  final urgencyInfo = <String, AllergenUrgencyInfo>{};
  for (final target in targets) {
    if (target.metric != TargetMetric.allergenExposures.name &&
        target.metric != TargetMetric.allergenExposureDays.name) continue;
    if (target.allergenName == null) continue;
    final normalized = target.allergenName!.trim().toLowerCase();
    if (urgencyInfo.containsKey(normalized)) continue;
    // Compute expected interval: period days / target count.
    final periodDaysForTarget = switch (target.period) {
      'daily' => 1.0,
      'weekly' => 7.0,
      'monthly' => 30.0,
      _ => 7.0,
    };
    final expectedInterval = target.targetValue > 0
        ? periodDaysForTarget / target.targetValue
        : periodDaysForTarget;
    final lastGiven = lastExposedAll[normalized];
    final daysSince = lastGiven != null
        ? refDay
            .difference(
                DateTime(lastGiven.year, lastGiven.month, lastGiven.day))
            .inDays
        : 999;
    final urgency = daysSince > expectedInterval * 1.5
        ? AllergenUrgency.overdue
        : daysSince >= expectedInterval
            ? AllergenUrgency.due
            : AllergenUrgency.onTrack;
    urgencyInfo[normalized] = AllergenUrgencyInfo(
      daysSinceExposure: daysSince,
      expectedIntervalDays: expectedInterval,
      urgency: urgency,
    );
  }

  final categoriesLower =
      allergenCategories.map((c) => c.trim().toLowerCase()).toSet();
  final covered = <String>{};
  final missing = <String>{};

  for (final cat in categoriesLower) {
    final tp = targetProgress[cat];
    if (tp != null) {
      // Target-based: covered when target met.
      if (tp.fraction >= 1.0) {
        covered.add(cat);
      } else {
        missing.add(cat);
      }
    } else {
      // Binary: any exposure counts as covered.
      if ((exposureCounts[cat] ?? 0) > 0) {
        covered.add(cat);
      } else {
        missing.add(cat);
      }
    }
  }

  return AllergenCoverage(
    covered: covered,
    missing: missing,
    exposureCounts: exposureCounts,
    lastExposed: lastExposed,
    targetProgress: targetProgress,
    urgencyInfo: urgencyInfo,
  );
}

/// Compute weekly allergen exposure matrix (Mon–Sun of the week containing
/// [referenceDate]).
WeeklyAllergenMatrix computeWeeklyAllergenMatrix({
  required List<ActivityModel> activities,
  required List<String> allergenCategories,
  required DateTime referenceDate,
}) {
  final ref = DateTime(referenceDate.year, referenceDate.month, referenceDate.day);
  final monday = ref.subtract(Duration(days: ref.weekday - 1));
  final days = List.generate(7, (i) => monday.add(Duration(days: i)));

  final categoriesLower =
      allergenCategories.map((c) => c.trim().toLowerCase()).toList();

  final matrix = <String, Set<int>>{
    for (final cat in categoriesLower) cat: {},
  };

  for (final a in activities) {
    if (a.type != ActivityType.solids.name) continue;
    if (a.allergenNames == null) continue;

    final dayStart = DateTime(a.startTime.year, a.startTime.month, a.startTime.day);

    // Find which day index this falls on
    int dayIndex = -1;
    for (int i = 0; i < days.length; i++) {
      if (days[i] == dayStart) {
        dayIndex = i;
        break;
      }
    }
    if (dayIndex < 0) continue;

    for (final allergen in a.allergenNames!) {
      final normalized = allergen.trim().toLowerCase();
      matrix[normalized]?.add(dayIndex);
    }
  }

  return WeeklyAllergenMatrix(
    days: days,
    allergens: categoriesLower,
    matrix: matrix,
  );
}

/// Compute per-ingredient drill-down for a given allergen category.
List<AllergenIngredientDetail> computeAllergenIngredientDrilldown({
  required List<ActivityModel> activities,
  required List<IngredientModel> ingredients,
  required String allergenCategory,
  required DateTime referenceDate,
  required int periodDays,
}) {
  final normalized = allergenCategory.trim().toLowerCase();

  // Find ingredients tagged with this allergen
  final taggedIngredients = ingredients
      .where((i) => i.allergens.any((a) => a.trim().toLowerCase() == normalized))
      .toList();

  if (taggedIngredients.isEmpty) return [];

  final cutoff = DateTime(
    referenceDate.year,
    referenceDate.month,
    referenceDate.day,
  ).subtract(Duration(days: periodDays));

  // Scan activities for ingredient exposures
  final counts = <String, int>{};
  final lastDates = <String, DateTime>{};

  for (final a in activities) {
    if (a.type != ActivityType.solids.name) continue;
    if (a.startTime.isBefore(cutoff)) continue;
    if (a.ingredientNames == null) continue;

    for (final name in a.ingredientNames!) {
      final n = name.trim().toLowerCase();
      counts[n] = (counts[n] ?? 0) + 1;
      final existing = lastDates[n];
      if (existing == null || a.startTime.isAfter(existing)) {
        lastDates[n] = a.startTime;
      }
    }
  }

  return taggedIngredients.map((i) {
    final n = i.name.toLowerCase();
    return AllergenIngredientDetail(
      ingredientName: i.name,
      exposureCount: counts[n] ?? 0,
      lastExposure: lastDates[n],
    );
  }).toList()
    ..sort((a, b) => b.exposureCount.compareTo(a.exposureCount));
}

/// Compute daily trend values for an arbitrary metric key over a period.
List<TrendPoint> computeTrendForMetric({
  required List<ActivityModel> activities,
  required String metricKey,
  required DateTime referenceDate,
  required int days,
}) {
  final dotIndex = metricKey.indexOf('.');
  if (dotIndex < 0) return [];
  final activityType = metricKey.substring(0, dotIndex);
  final metric = metricKey.substring(dotIndex + 1);

  final ref =
      DateTime(referenceDate.year, referenceDate.month, referenceDate.day);
  final points = <TrendPoint>[];

  for (int i = days - 1; i >= 0; i--) {
    final dayStart = ref.subtract(Duration(days: i));
    final dayEnd = dayStart.add(const Duration(days: 1));
    final dayActivities = activities
        .where((a) =>
            !a.startTime.isBefore(dayStart) && a.startTime.isBefore(dayEnd))
        .toList();

    double value = 0;
    if (dayActivities.isNotEmpty) {
      final summary = ActivityAggregator.compute(dayActivities);
      value = extractMetricFromSummary(activityType, metric, summary) ?? 0;
    }
    points.add(TrendPoint(date: dayStart, value: value));
  }

  return points;
}

// ==========================================================================
// Phase 1 providers
// ==========================================================================

/// Today's activity summary.
final todaySummaryProvider = Provider<ActivitySummary?>((ref) {
  final activities = ref.watch(activitiesProvider).valueOrNull;
  if (activities == null) return null;
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final todayActivities =
      activities.where((a) => !a.startTime.isBefore(todayStart)).toList();
  if (todayActivities.isEmpty) return null;
  return ActivityAggregator.compute(todayActivities);
});

/// 7-day trailing averages for key metrics (excluding today).
final inferredBaselinesProvider = Provider<InferredBaselines?>((ref) {
  final activities = ref.watch(activitiesProvider).valueOrNull;
  if (activities == null) return null;
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);

  double totalBottleMl = 0,
      totalBottleCount = 0,
      totalBreastCount = 0,
      totalBreastMinutes = 0,
      totalDiaperCount = 0,
      totalSolidsCount = 0,
      totalTummyMinutes = 0;
  int daysWithData = 0;

  for (int i = 1; i <= 7; i++) {
    final dayStart = todayStart.subtract(Duration(days: i));
    final dayEnd = dayStart.add(const Duration(days: 1));
    final dayActivities = activities
        .where((a) =>
            !a.startTime.isBefore(dayStart) && a.startTime.isBefore(dayEnd))
        .toList();
    if (dayActivities.isEmpty) continue;
    daysWithData++;
    final summary = ActivityAggregator.compute(dayActivities);
    totalBottleMl += summary.bottleFeedTotalMl;
    totalBottleCount += summary.bottleFeedCount;
    totalBreastCount += summary.breastFeedCount;
    totalBreastMinutes += summary.breastFeedTotalMinutes;
    totalDiaperCount += summary.diaperCount;
    totalSolidsCount += summary.solidsCount;
    totalTummyMinutes +=
        (summary.durationTotals[ActivityType.tummyTime.name] ?? 0);
  }

  if (daysWithData == 0) return null;

  return InferredBaselines(
    avgBottleMl: totalBottleMl / daysWithData,
    avgBottleCount: totalBottleCount / daysWithData,
    avgBreastCount: totalBreastCount / daysWithData,
    avgBreastMinutes: totalBreastMinutes / daysWithData,
    avgDiaperCount: totalDiaperCount / daysWithData,
    avgSolidsCount: totalSolidsCount / daysWithData,
    avgTummyTimeMinutes: totalTummyMinutes / daysWithData,
    daysWithData: daysWithData,
  );
});

/// Merges explicit daily goals + inferred baselines into progress metrics.
final todayProgressProvider = Provider<List<MetricProgress>>((ref) {
  final summary = ref.watch(todaySummaryProvider);
  final targets = ref.watch(targetsProvider).valueOrNull ?? [];
  final baselines = ref.watch(inferredBaselinesProvider);
  final results = <MetricProgress>[];
  final coveredKeys = <String>{};

  // 1. Explicit daily targets
  for (final target in targets) {
    if (target.period != 'daily') continue;
    final key = '${target.activityType}.${target.metric}';
    final type = parseActivityType(target.activityType);

    double actual = 0;
    if (summary != null) {
      actual = extractMetricFromSummary(
            target.activityType,
            target.metric,
            summary,
            ingredientName: target.ingredientName,
            allergenName: target.allergenName,
          ) ??
          0;
    }
    final fraction =
        target.targetValue > 0 ? (actual / target.targetValue) : 0.0;
    results.add(MetricProgress(
      key: key,
      label: _metricLabel(target),
      actual: actual,
      target: target.targetValue,
      fraction: fraction.clamp(0.0, 1.0),
      isExplicit: true,
      icon: type != null ? activityIcon(type) : Icons.track_changes,
      color: type != null ? activityColor(type) : Colors.grey,
      unit: _metricUnit(target.metric),
    ));
    coveredKeys.add(key);
  }

  // 2. Inferred baselines for key types without explicit targets
  if (baselines != null && baselines.daysWithData >= 3) {
    final inferredMetrics = [
      (
        key: 'feedBottle.totalVolumeMl',
        label: 'Feed Volume',
        actual: summary?.bottleFeedTotalMl ?? 0.0,
        target: baselines.avgBottleMl,
        icon: activityIcon(ActivityType.feedBottle),
        color: activityColor(ActivityType.feedBottle),
        unit: 'ml',
      ),
      (
        key: 'diaper.count',
        label: 'Diapers',
        actual: (summary?.diaperCount ?? 0).toDouble(),
        target: baselines.avgDiaperCount,
        icon: activityIcon(ActivityType.diaper),
        color: activityColor(ActivityType.diaper),
        unit: '',
      ),
      (
        key: 'solids.count',
        label: 'Solids',
        actual: (summary?.solidsCount ?? 0).toDouble(),
        target: baselines.avgSolidsCount,
        icon: activityIcon(ActivityType.solids),
        color: activityColor(ActivityType.solids),
        unit: '',
      ),
      (
        key: 'tummyTime.totalDurationMinutes',
        label: 'Tummy Time',
        actual: (summary?.durationTotals[ActivityType.tummyTime.name] ?? 0)
            .toDouble(),
        target: baselines.avgTummyTimeMinutes,
        icon: activityIcon(ActivityType.tummyTime),
        color: activityColor(ActivityType.tummyTime),
        unit: 'min',
      ),
    ];
    for (final m in inferredMetrics) {
      if (coveredKeys.contains(m.key)) continue;
      if (m.target < 0.5) continue;
      final fraction = m.target > 0 ? (m.actual / m.target) : 0.0;
      results.add(MetricProgress(
        key: m.key,
        label: m.label,
        actual: m.actual,
        target: m.target,
        fraction: fraction.clamp(0.0, 1.0),
        isExplicit: false,
        icon: m.icon,
        color: m.color,
        unit: m.unit,
      ));
    }
  }

  return results;
});

// ==========================================================================
// Trend providers
// ==========================================================================

final selectedTrendMetricProvider =
    StateProvider<TrendMetric>((ref) => TrendMetric.feedVolume);

final selectedTrendPeriodProvider = StateProvider<int>((ref) => 7);

/// Daily trend data for the selected metric and period.
final trendDataProvider = Provider<List<TrendPoint>>((ref) {
  final activities = ref.watch(activitiesProvider).valueOrNull;
  final metric = ref.watch(selectedTrendMetricProvider);
  final days = ref.watch(selectedTrendPeriodProvider);
  if (activities == null) return [];

  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final points = <TrendPoint>[];

  for (int i = days - 1; i >= 0; i--) {
    final dayStart = todayStart.subtract(Duration(days: i));
    final dayEnd = dayStart.add(const Duration(days: 1));
    final dayActivities = activities
        .where((a) =>
            !a.startTime.isBefore(dayStart) && a.startTime.isBefore(dayEnd))
        .toList();

    double value = 0;
    if (dayActivities.isNotEmpty) {
      final s = ActivityAggregator.compute(dayActivities);
      value = switch (metric) {
        TrendMetric.feedVolume => s.bottleFeedTotalMl,
        TrendMetric.diapers => s.diaperCount.toDouble(),
        TrendMetric.solids => s.solidsCount.toDouble(),
        TrendMetric.tummyTime =>
          (s.durationTotals[ActivityType.tummyTime.name] ?? 0).toDouble(),
      };
    }
    points.add(TrendPoint(date: dayStart, value: value));
  }

  return points;
});

/// Baseline/target value for the trend chart's reference line.
final trendBaselineProvider = Provider<double?>((ref) {
  final metric = ref.watch(selectedTrendMetricProvider);
  final targets = ref.watch(targetsProvider).valueOrNull ?? [];
  final baselines = ref.watch(inferredBaselinesProvider);

  for (final t in targets) {
    if (t.period != 'daily') continue;
    final matches = switch (metric) {
      TrendMetric.feedVolume =>
        t.activityType == ActivityType.feedBottle.name &&
            t.metric == 'totalVolumeMl',
      TrendMetric.diapers =>
        t.activityType == ActivityType.diaper.name && t.metric == 'count',
      TrendMetric.solids =>
        t.activityType == ActivityType.solids.name && t.metric == 'count',
      TrendMetric.tummyTime =>
        t.activityType == ActivityType.tummyTime.name &&
            t.metric == 'totalDurationMinutes',
    };
    if (matches) return t.targetValue;
  }

  if (baselines == null) return null;
  return switch (metric) {
    TrendMetric.feedVolume => baselines.avgBottleMl,
    TrendMetric.diapers => baselines.avgDiaperCount,
    TrendMetric.solids => baselines.avgSolidsCount,
    TrendMetric.tummyTime => baselines.avgTummyTimeMinutes,
  };
});

/// Trend data for an arbitrary metric key over a given number of days.
final metricTrendDataProvider =
    Provider.family<List<TrendPoint>, ({String metricKey, int days})>(
        (ref, query) {
  final activities = ref.watch(activitiesProvider).valueOrNull;
  if (activities == null) return [];
  return computeTrendForMetric(
    activities: activities,
    metricKey: query.metricKey,
    referenceDate: DateTime.now(),
    days: query.days,
  );
});

// ==========================================================================
// Phase 2: Allergen providers
// ==========================================================================

/// Selected period for allergen coverage (7 or 14 days).
final allergenCoveragePeriodProvider = StateProvider<int>((ref) => 7);

/// Allergen coverage for the selected period.
final allergenCoverageProvider = Provider<AllergenCoverage?>((ref) {
  final activities = ref.watch(activitiesProvider).valueOrNull;
  final categories = ref.watch(allergenCategoriesProvider);
  final period = ref.watch(allergenCoveragePeriodProvider);
  final targets = ref.watch(targetsProvider).valueOrNull ?? [];
  if (activities == null || categories.isEmpty) return null;

  return computeAllergenCoverage(
    activities: activities,
    allergenCategories: categories,
    referenceDate: DateTime.now(),
    periodDays: period,
    targets: targets,
  );
});

/// Weekly allergen exposure matrix for the current week.
final weeklyAllergenMatrixProvider = Provider<WeeklyAllergenMatrix?>((ref) {
  final activities = ref.watch(activitiesProvider).valueOrNull;
  final categories = ref.watch(allergenCategoriesProvider);
  if (activities == null || categories.isEmpty) return null;

  return computeWeeklyAllergenMatrix(
    activities: activities,
    allergenCategories: categories,
    referenceDate: DateTime.now(),
  );
});

/// Drill-down: per-ingredient details for a given allergen category.
final allergenIngredientDrilldownProvider = Provider.family<
    List<AllergenIngredientDetail>, String>((ref, allergenCategory) {
  final activities = ref.watch(activitiesProvider).valueOrNull ?? [];
  final ingredients = ref.watch(ingredientsProvider).valueOrNull ?? [];

  return computeAllergenIngredientDrilldown(
    activities: activities,
    ingredients: ingredients,
    allergenCategory: allergenCategory,
    referenceDate: DateTime.now(),
    periodDays: 30,
  );
});

// ==========================================================================
// Helpers
// ==========================================================================

String _metricLabel(TargetModel target) {
  final type = parseActivityType(target.activityType);
  final typeName =
      type != null ? activityDisplayName(type) : target.activityType;
  return switch (target.metric) {
    'totalVolumeMl' => '$typeName Vol.',
    'count' => typeName,
    'uniqueFoods' => 'Unique Foods',
    'totalDurationMinutes' => '$typeName Time',
    'ingredientExposures' => target.ingredientName ?? 'Exposures',
    'allergenExposures' => target.allergenName ?? 'Allergens',
    'allergenExposureDays' => target.allergenName != null
        ? '${target.allergenName} days'
        : 'Allergen days',
    _ => target.metric,
  };
}

String _metricUnit(String metric) {
  return switch (metric) {
    'totalVolumeMl' => 'ml',
    'totalDurationMinutes' => 'min',
    'allergenExposureDays' => 'days',
    _ => '',
  };
}
