import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/activity_model.dart';
import '../models/enums.dart';
import '../models/ingredient_model.dart';
import '../models/target_model.dart';
import '../utils/activity_aggregator.dart';
import '../utils/activity_helpers.dart';
import '../utils/date_range_helpers.dart';
import 'activity_provider.dart';
import 'family_provider.dart';
import 'ingredient_provider.dart';
import 'settings_provider.dart';
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
  final String? periodLabel; // null for daily, "7d" for weekly, "30d" for monthly

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
    this.periodLabel,
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

  /// Allergens from [missing] that need attention (overdue or due).
  List<String> get attentionAllergens {
    final list = missing.where((a) {
      final u = urgencyInfo[a];
      return u != null &&
          (u.urgency == AllergenUrgency.overdue ||
              u.urgency == AllergenUrgency.due);
    }).toList();
    list.sort((a, b) {
      final ua = urgencyInfo[a]!;
      final ub = urgencyInfo[b]!;
      final orderA = ua.urgency == AllergenUrgency.overdue ? 0 : 1;
      final orderB = ub.urgency == AllergenUrgency.overdue ? 0 : 1;
      if (orderA != orderB) return orderA.compareTo(orderB);
      return ub.daysSinceExposure.compareTo(ua.daysSinceExposure);
    });
    return list;
  }

  /// Count of allergens from [missing] that need attention.
  int get attentionCount => attentionAllergens.length;

  /// Total allergen count.
  int get totalCount => covered.length + missing.length;

  /// Fraction of allergens that are covered.
  double get coveredFraction =>
      totalCount > 0 ? covered.length / totalCount : 0.0;
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
  final exposureDays = <String, Set<String>>{};

  // Single pass: collect exposure counts, last exposure dates, and distinct
  // exposure days instead of scanning activities twice.
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
      // Track distinct exposure days within the window.
      final dayKey =
          '${a.startTime.year}-${a.startTime.month}-${a.startTime.day}';
      (exposureDays[normalized] ??= {}).add(dayKey);
    }
  }

  // Build target progress map from allergen targets.
  final targetProgress = <String, AllergenTargetProgress>{};
  for (final target in targets) {
    if (target.metric != TargetMetric.allergenExposures.name &&
        target.metric != TargetMetric.allergenExposureDays.name) {
      continue;
    }
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
        target.metric != TargetMetric.allergenExposureDays.name) {
      continue;
    }
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

/// Compute per-ingredient drilldowns for ALL allergen categories at once.
/// Single activity scan instead of N scans for N allergens.
Map<String, List<AllergenIngredientDetail>> computeAllAllergenDrilldowns({
  required List<ActivityModel> activities,
  required List<IngredientModel> ingredients,
  required DateTime referenceDate,
  required int periodDays,
}) {
  // Build allergen -> [ingredient] lookup
  final allergenToIngredients = <String, List<IngredientModel>>{};
  for (final i in ingredients) {
    for (final a in i.allergens) {
      final normalized = a.trim().toLowerCase();
      (allergenToIngredients[normalized] ??= []).add(i);
    }
  }

  if (allergenToIngredients.isEmpty) return {};

  final cutoff = DateTime(
    referenceDate.year,
    referenceDate.month,
    referenceDate.day,
  ).subtract(Duration(days: periodDays));

  // Single scan: collect counts and dates for all ingredient names
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

  // Build result map
  final result = <String, List<AllergenIngredientDetail>>{};
  for (final entry in allergenToIngredients.entries) {
    final details = entry.value.map((i) {
      final n = i.name.toLowerCase();
      return AllergenIngredientDetail(
        ingredientName: i.name,
        exposureCount: counts[n] ?? 0,
        lastExposure: lastDates[n],
      );
    }).toList()
      ..sort((a, b) => b.exposureCount.compareTo(a.exposureCount));
    result[entry.key] = details;
  }
  return result;
}

/// Compute daily trend values for an arbitrary metric key over a period.
/// If [dailySummaryMap] is provided, uses pre-computed summaries instead of
/// recomputing from activities (much faster for multiple calls).
List<TrendPoint> computeTrendForMetric({
  required List<ActivityModel> activities,
  required String metricKey,
  required DateTime referenceDate,
  required int days,
  Map<String, ActivitySummary>? dailySummaryMap,
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
    double value = 0;

    if (dailySummaryMap != null) {
      final summary = dailySummaryMap[_dayKey(dayStart)];
      if (summary != null) {
        value = extractMetricFromSummary(activityType, metric, summary) ?? 0;
      }
    } else {
      final dayEnd = dayStart.add(const Duration(days: 1));
      final dayActivities = activities
          .where((a) =>
              !a.startTime.isBefore(dayStart) && a.startTime.isBefore(dayEnd))
          .toList();
      if (dayActivities.isNotEmpty) {
        final summary = ActivityAggregator.compute(dayActivities);
        value = extractMetricFromSummary(activityType, metric, summary) ?? 0;
      }
    }
    points.add(TrendPoint(date: dayStart, value: value));
  }

  return points;
}

// ==========================================================================
// Shared daily summary cache
// ==========================================================================

/// Date key for the daily summary map.
String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

/// Pre-computed daily summaries for the trailing 30 days (+ today).
/// All providers that need per-day aggregation should read from this map
/// instead of calling ActivityAggregator.compute() per day.
final dailySummaryMapProvider =
    Provider<Map<String, ActivitySummary>>((ref) {
  final activities = ref.watch(activitiesProvider).valueOrNull;
  if (activities == null) return {};
  final sodHour = ref.watch(startOfDayHourProvider).valueOrNull ?? 0;
  final todayStart = startOfDay(DateTime.now(), sodHour);

  // Bucket activities into days
  final buckets = <String, List<ActivityModel>>{};
  final oldest = todayStart.subtract(const Duration(days: 30));
  for (final a in activities) {
    if (a.startTime.isBefore(oldest)) continue;
    final dayStart = startOfDay(a.startTime, sodHour);
    final key = _dayKey(dayStart);
    (buckets[key] ??= []).add(a);
  }

  // Compute summary for each day
  return {
    for (final e in buckets.entries)
      e.key: ActivityAggregator.compute(e.value),
  };
});

// ==========================================================================
// Phase 1 providers
// ==========================================================================

/// Today's activity summary, respecting start-of-day preference.
final todaySummaryProvider = Provider<ActivitySummary?>((ref) {
  final activities = ref.watch(activitiesProvider).valueOrNull;
  if (activities == null) return null;
  final sodHour = ref.watch(startOfDayHourProvider).valueOrNull ?? 0;
  final todayStart = startOfDay(DateTime.now(), sodHour);
  final todayEnd = todayStart.add(const Duration(days: 1));
  final todayActivities = activities
      .where((a) =>
          !a.startTime.isBefore(todayStart) && a.startTime.isBefore(todayEnd))
      .toList();
  if (todayActivities.isEmpty) return null;
  return ActivityAggregator.compute(todayActivities);
});

// ==========================================================================
// Insights period providers
// ==========================================================================

/// Selected time window mode for the insights screen.
final insightsWindowModeProvider = StateProvider<TimeWindowMode>(
    (ref) => TimeWindowMode.last7Days);

/// Anchor date for insights navigation.
final insightsAnchorProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// Activity summary for the insights window.
final insightsSummaryProvider = Provider<ActivitySummary?>((ref) {
  final activities = ref.watch(activitiesProvider).valueOrNull;
  if (activities == null) return null;
  final mode = ref.watch(insightsWindowModeProvider);
  final anchor = ref.watch(insightsAnchorProvider);
  final sodHour = ref.watch(startOfDayHourProvider).valueOrNull ?? 0;
  final (start, end) = computeRange(mode, anchor, startOfDayHour: sodHour);
  final filtered = activities
      .where((a) => !a.startTime.isBefore(start) && a.startTime.isBefore(end))
      .toList();
  if (filtered.isEmpty) return null;
  return ActivityAggregator.compute(filtered);
});

/// Weekly summary anchored to the insights window (for weekly targets).
final insightsWeeklySummaryProvider = Provider<ActivitySummary?>((ref) {
  final activities = ref.watch(activitiesProvider).valueOrNull;
  if (activities == null) return null;
  final mode = ref.watch(insightsWindowModeProvider);
  final anchor = ref.watch(insightsAnchorProvider);
  final sodHour = ref.watch(startOfDayHourProvider).valueOrNull ?? 0;

  // For week/month modes, use the window itself; for day mode, expand to rolling 7d
  final DateTime start;
  final DateTime end;
  if (mode == TimeWindowMode.calendarWeek || mode == TimeWindowMode.last7Days) {
    final range = computeRange(mode, anchor, startOfDayHour: sodHour);
    start = range.$1;
    end = range.$2;
  } else if (mode == TimeWindowMode.calendarMonth || mode == TimeWindowMode.last30Days) {
    final range = computeRange(mode, anchor, startOfDayHour: sodHour);
    start = range.$1;
    end = range.$2;
  } else {
    // Day mode: rolling 7 days ending at the anchor
    final dayEnd = computeRange(mode, anchor, startOfDayHour: sodHour).$2;
    start = dayEnd.subtract(const Duration(days: 7));
    end = dayEnd;
  }
  final filtered = activities
      .where((a) => !a.startTime.isBefore(start) && a.startTime.isBefore(end))
      .toList();
  if (filtered.isEmpty) return null;
  return ActivityAggregator.compute(filtered);
});

/// Monthly summary anchored to the insights window (for monthly targets).
final insightsMonthlySummaryProvider = Provider<ActivitySummary?>((ref) {
  final activities = ref.watch(activitiesProvider).valueOrNull;
  if (activities == null) return null;
  final mode = ref.watch(insightsWindowModeProvider);
  final anchor = ref.watch(insightsAnchorProvider);
  final sodHour = ref.watch(startOfDayHourProvider).valueOrNull ?? 0;

  // For month mode, use the window; otherwise expand to rolling 30d
  final DateTime start;
  final DateTime end;
  if (mode == TimeWindowMode.calendarMonth || mode == TimeWindowMode.last30Days) {
    final range = computeRange(mode, anchor, startOfDayHour: sodHour);
    start = range.$1;
    end = range.$2;
  } else {
    final dayEnd = computeRange(mode, anchor, startOfDayHour: sodHour).$2;
    start = dayEnd.subtract(const Duration(days: 30));
    end = dayEnd;
  }
  final filtered = activities
      .where((a) => !a.startTime.isBefore(start) && a.startTime.isBefore(end))
      .toList();
  if (filtered.isEmpty) return null;
  return ActivityAggregator.compute(filtered);
});

/// Rolling 7-day activity summary (for weekly targets).
final rollingWeekSummaryProvider = Provider<ActivitySummary?>((ref) {
  final activities = ref.watch(activitiesProvider).valueOrNull;
  if (activities == null) return null;
  final sodHour = ref.watch(startOfDayHourProvider).valueOrNull ?? 0;
  final todayStart = startOfDay(DateTime.now(), sodHour);
  final todayEnd = todayStart.add(const Duration(days: 1));
  final weekStart = todayStart.subtract(const Duration(days: 6));
  final weekActivities = activities
      .where((a) =>
          !a.startTime.isBefore(weekStart) && a.startTime.isBefore(todayEnd))
      .toList();
  if (weekActivities.isEmpty) return null;
  return ActivityAggregator.compute(weekActivities);
});

/// Rolling 30-day activity summary (for monthly targets).
final rollingMonthSummaryProvider = Provider<ActivitySummary?>((ref) {
  final activities = ref.watch(activitiesProvider).valueOrNull;
  if (activities == null) return null;
  final sodHour = ref.watch(startOfDayHourProvider).valueOrNull ?? 0;
  final todayStart = startOfDay(DateTime.now(), sodHour);
  final todayEnd = todayStart.add(const Duration(days: 1));
  final monthStart = todayStart.subtract(const Duration(days: 29));
  final monthActivities = activities
      .where((a) =>
          !a.startTime.isBefore(monthStart) && a.startTime.isBefore(todayEnd))
      .toList();
  if (monthActivities.isEmpty) return null;
  return ActivityAggregator.compute(monthActivities);
});

/// 7-day trailing averages for key metrics (excluding today).
/// Uses dailySummaryMapProvider to avoid redundant compute() calls.
final inferredBaselinesProvider = Provider<InferredBaselines?>((ref) {
  final dailyMap = ref.watch(dailySummaryMapProvider);
  if (dailyMap.isEmpty) return null;
  final sodHour = ref.watch(startOfDayHourProvider).valueOrNull ?? 0;
  final todayStart = startOfDay(DateTime.now(), sodHour);

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
    final summary = dailyMap[_dayKey(dayStart)];
    if (summary == null) continue;
    daysWithData++;
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

/// Reusable progress computation from summaries + targets + baselines.
List<MetricProgress> computeProgress({
  required ActivitySummary? dailySummary,
  required ActivitySummary? weeklySummary,
  required ActivitySummary? monthlySummary,
  required InferredBaselines? baselines,
  required List<TargetModel> targets,
}) {
  final results = <MetricProgress>[];
  final coveredKeys = <String>{};

  // Helper to get the right summary for a period.
  ActivitySummary? summaryForPeriod(String period) => switch (period) {
        'daily' => dailySummary,
        'weekly' => weeklySummary,
        'monthly' => monthlySummary,
        _ => dailySummary,
      };

  String? periodLabel(String period) => switch (period) {
        'weekly' => '7d',
        'monthly' => '30d',
        _ => null,
      };

  // 1. Explicit targets (aggregate allergen targets into one ring per period)
  final allergenTargetsDaily = <TargetModel>[];
  final allergenTargetsWeekly = <TargetModel>[];
  final allergenTargetsMonthly = <TargetModel>[];

  for (final target in targets) {
    // Collect allergen targets for aggregation
    if (target.metric == 'allergenExposures' ||
        target.metric == 'allergenExposureDays') {
      switch (target.period) {
        case 'daily':
          allergenTargetsDaily.add(target);
        case 'weekly':
          allergenTargetsWeekly.add(target);
        case 'monthly':
          allergenTargetsMonthly.add(target);
      }
      continue;
    }

    final key = '${target.activityType}.${target.metric}.${target.period}';
    final type = parseActivityType(target.activityType);
    final s = summaryForPeriod(target.period);

    double actual = 0;
    if (s != null) {
      actual = extractMetricFromSummary(
            target.activityType,
            target.metric,
            s,
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
      periodLabel: periodLabel(target.period),
    ));
    coveredKeys.add(key);
  }

  // 1b. Aggregate allergen targets into rings (one per period that has them)
  void addAllergenRing(List<TargetModel> allergenTargets, String period) {
    if (allergenTargets.isEmpty) return;
    final s = summaryForPeriod(period);
    int metCount = 0;
    for (final target in allergenTargets) {
      double actual = 0;
      if (s != null) {
        actual = extractMetricFromSummary(
              target.activityType,
              target.metric,
              s,
              allergenName: target.allergenName,
            ) ??
            0;
      }
      if (target.targetValue > 0 && actual >= target.targetValue) {
        metCount++;
      }
    }
    final total = allergenTargets.length;
    final fraction = total > 0 ? metCount / total : 0.0;
    results.add(MetricProgress(
      key: 'allergens.aggregate.$period',
      label: 'Allergens',
      actual: metCount.toDouble(),
      target: total.toDouble(),
      fraction: fraction.clamp(0.0, 1.0),
      isExplicit: true,
      icon: Icons.science_outlined,
      color: Colors.teal,
      unit: '',
      periodLabel: periodLabel(period),
    ));
    coveredKeys.add('allergens.aggregate.$period');
  }

  addAllergenRing(allergenTargetsDaily, 'daily');
  addAllergenRing(allergenTargetsWeekly, 'weekly');
  addAllergenRing(allergenTargetsMonthly, 'monthly');

  // 2. Inferred baselines for key types without explicit targets
  if (baselines != null && baselines.daysWithData >= 3) {
    final inferredMetrics = [
      (
        key: 'feedBottle.totalVolumeMl.daily',
        label: 'Feed Vol.',
        actual: dailySummary?.bottleFeedTotalMl ?? 0.0,
        target: baselines.avgBottleMl,
        icon: activityIcon(ActivityType.feedBottle),
        color: activityColor(ActivityType.feedBottle),
        unit: 'ml',
      ),
      (
        key: 'diaper.count.daily',
        label: 'Diapers',
        actual: (dailySummary?.diaperCount ?? 0).toDouble(),
        target: baselines.avgDiaperCount,
        icon: activityIcon(ActivityType.diaper),
        color: activityColor(ActivityType.diaper),
        unit: '',
      ),
      (
        key: 'solids.count.daily',
        label: 'Solids',
        actual: (dailySummary?.solidsCount ?? 0).toDouble(),
        target: baselines.avgSolidsCount,
        icon: activityIcon(ActivityType.solids),
        color: activityColor(ActivityType.solids),
        unit: '',
      ),
      (
        key: 'tummyTime.totalDurationMinutes.daily',
        label: 'Tummy Time',
        actual:
            (dailySummary?.durationTotals[ActivityType.tummyTime.name] ?? 0)
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

  // Sort by fraction ascending (behind-target first).
  results.sort((a, b) => a.fraction.compareTo(b.fraction));

  return results;
}

/// Merges explicit goals (daily/weekly/monthly) + inferred baselines into
/// progress metrics, sorted by urgency (behind-target first).
final todayProgressProvider = Provider<List<MetricProgress>>((ref) {
  final summary = ref.watch(todaySummaryProvider);
  final weekSummary = ref.watch(rollingWeekSummaryProvider);
  final monthSummary = ref.watch(rollingMonthSummaryProvider);
  final targets = ref.watch(targetsProvider).valueOrNull ?? [];
  final baselines = ref.watch(inferredBaselinesProvider);
  return computeProgress(
    dailySummary: summary,
    weeklySummary: weekSummary,
    monthlySummary: monthSummary,
    baselines: baselines,
    targets: targets,
  );
});

/// Progress metrics for the insights window period.
final insightsProgressProvider = Provider<List<MetricProgress>>((ref) {
  final summary = ref.watch(insightsSummaryProvider);
  final weekSummary = ref.watch(insightsWeeklySummaryProvider);
  final monthSummary = ref.watch(insightsMonthlySummaryProvider);
  final targets = ref.watch(targetsProvider).valueOrNull ?? [];
  final baselines = ref.watch(inferredBaselinesProvider);
  return computeProgress(
    dailySummary: summary,
    weeklySummary: weekSummary,
    monthlySummary: monthSummary,
    baselines: baselines,
    targets: targets,
  );
});

/// Curated metrics for the home screen status rings.
///
/// Returns exactly these 4 metrics in fixed order (skipping any without data):
/// 1. Feeds (today) — combined bottle + breast count
/// 2. Diapers (today)
/// 3. Allergens covered (today)
/// 4. Allergens (7d)
final homeProgressProvider = Provider<List<MetricProgress>>((ref) {
  final allProgress = ref.watch(todayProgressProvider);
  final summary = ref.watch(todaySummaryProvider);
  final baselines = ref.watch(inferredBaselinesProvider);

  final results = <MetricProgress>[];

  // 1. Combined feed count (bottle + breast) for today
  // Check explicit targets first, then inferred baselines
  final feedExplicit = allProgress.where((m) =>
      m.key.startsWith('feedBottle.') && m.key.endsWith('.daily') ||
      m.key.startsWith('feedBreast.') && m.key.endsWith('.daily'));
  if (feedExplicit.isNotEmpty) {
    // Use the most relevant explicit feed target (lowest fraction = most behind)
    results.add(feedExplicit.reduce((a, b) => a.fraction < b.fraction ? a : b));
  } else if (summary != null) {
    // Inferred combined feed count
    final feedCount =
        (summary.bottleFeedCount + summary.breastFeedCount).toDouble();
    final avgFeedCount = baselines != null && baselines.daysWithData >= 3
        ? baselines.avgBottleCount + baselines.avgBreastCount
        : 0.0;
    if (avgFeedCount >= 0.5) {
      final fraction = avgFeedCount > 0 ? feedCount / avgFeedCount : 0.0;
      results.add(MetricProgress(
        key: 'feed.count.daily',
        label: 'Feeds',
        actual: feedCount,
        target: avgFeedCount,
        fraction: fraction.clamp(0.0, 1.0),
        isExplicit: false,
        icon: activityIcon(ActivityType.feedBottle),
        color: activityColor(ActivityType.feedBottle),
      ));
    }
  }

  // 2. Diapers (today) — from todayProgressProvider or inferred
  final diaperMetric =
      allProgress.where((m) => m.key == 'diaper.count.daily').firstOrNull;
  if (diaperMetric != null) results.add(diaperMetric);

  // 3. Allergens covered (today)
  final allergenDaily = allProgress
      .where((m) => m.key == 'allergens.aggregate.daily')
      .firstOrNull;
  if (allergenDaily != null) results.add(allergenDaily);

  // 4. Allergens (7d)
  final allergenWeekly = allProgress
      .where((m) => m.key == 'allergens.aggregate.weekly')
      .firstOrNull;
  if (allergenWeekly != null) results.add(allergenWeekly);

  return results;
});

// ==========================================================================
// Trend providers
// ==========================================================================

final selectedTrendMetricProvider =
    StateProvider<TrendMetric>((ref) => TrendMetric.feedVolume);

final selectedTrendPeriodProvider = StateProvider<int>((ref) => 7);

/// Daily trend data for the selected metric and period.
/// Uses dailySummaryMapProvider to avoid redundant compute() calls.
final trendDataProvider = Provider<List<TrendPoint>>((ref) {
  final dailyMap = ref.watch(dailySummaryMapProvider);
  final metric = ref.watch(selectedTrendMetricProvider);
  final days = ref.watch(selectedTrendPeriodProvider);
  if (dailyMap.isEmpty && ref.watch(activitiesProvider).valueOrNull == null) {
    return [];
  }

  final sodHour = ref.watch(startOfDayHourProvider).valueOrNull ?? 0;
  final todayStart = startOfDay(DateTime.now(), sodHour);
  final points = <TrendPoint>[];

  for (int i = days - 1; i >= 0; i--) {
    final dayStart = todayStart.subtract(Duration(days: i));
    final s = dailyMap[_dayKey(dayStart)];

    double value = 0;
    if (s != null) {
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
/// Uses dailySummaryMapProvider for O(1) daily lookups.
final metricTrendDataProvider =
    Provider.family<List<TrendPoint>, ({String metricKey, int days})>(
        (ref, query) {
  final activities = ref.watch(activitiesProvider).valueOrNull;
  if (activities == null) return [];
  final dailyMap = ref.watch(dailySummaryMapProvider);
  return computeTrendForMetric(
    activities: activities,
    metricKey: query.metricKey,
    referenceDate: DateTime.now(),
    days: query.days,
    dailySummaryMap: dailyMap.isNotEmpty ? dailyMap : null,
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

/// Allergen coverage anchored to the insights window.
final insightsAllergenCoverageProvider = Provider<AllergenCoverage?>((ref) {
  final activities = ref.watch(activitiesProvider).valueOrNull;
  final categories = ref.watch(allergenCategoriesProvider);
  final period = ref.watch(allergenCoveragePeriodProvider);
  final targets = ref.watch(targetsProvider).valueOrNull ?? [];
  final anchor = ref.watch(insightsAnchorProvider);
  if (activities == null || categories.isEmpty) return null;

  return computeAllergenCoverage(
    activities: activities,
    allergenCategories: categories,
    referenceDate: anchor,
    periodDays: period,
    targets: targets,
  );
});

/// Filter mode for the allergen matrix view.
enum AllergenMatrixFilter { exposedOnly, all }

/// Selected filter for the allergen matrix.
final allergenMatrixFilterProvider =
    StateProvider<AllergenMatrixFilter>((ref) => AllergenMatrixFilter.exposedOnly);

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

/// Matrix week anchor derived from the insights anchor date.
final insightsMatrixWeekProvider = StateProvider<DateTime>((ref) {
  final anchor = ref.watch(insightsAnchorProvider);
  // Derive Monday of the anchor's week
  return DateTime(anchor.year, anchor.month, anchor.day)
      .subtract(Duration(days: anchor.weekday - 1));
});

/// Weekly allergen matrix anchored to the insights matrix week.
final insightsWeeklyAllergenMatrixProvider =
    Provider<WeeklyAllergenMatrix?>((ref) {
  final activities = ref.watch(activitiesProvider).valueOrNull;
  final categories = ref.watch(allergenCategoriesProvider);
  final matrixWeek = ref.watch(insightsMatrixWeekProvider);
  if (activities == null || categories.isEmpty) return null;

  return computeWeeklyAllergenMatrix(
    activities: activities,
    allergenCategories: categories,
    referenceDate: matrixWeek,
  );
});

/// Pre-computed drilldowns for ALL allergen categories (single activity scan).
final _allAllergenDrilldownsProvider =
    Provider<Map<String, List<AllergenIngredientDetail>>>((ref) {
  final activities = ref.watch(activitiesProvider).valueOrNull ?? [];
  final ingredients = ref.watch(ingredientsProvider).valueOrNull ?? [];
  return computeAllAllergenDrilldowns(
    activities: activities,
    ingredients: ingredients,
    referenceDate: DateTime.now(),
    periodDays: 30,
  );
});

/// Drill-down: per-ingredient details for a given allergen category.
/// Reads from the batch-computed map instead of scanning per allergen.
final allergenIngredientDrilldownProvider = Provider.family<
    List<AllergenIngredientDetail>, String>((ref, allergenCategory) {
  final allDrilldowns = ref.watch(_allAllergenDrilldownsProvider);
  return allDrilldowns[allergenCategory.trim().toLowerCase()] ?? [];
});

// ==========================================================================
// Metric detail providers
// ==========================================================================

/// Selected date for metric detail day navigation.
final metricDetailDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// Summary for the metric detail selected date.
final metricDetailSummaryProvider = Provider<ActivitySummary?>((ref) {
  final activities = ref.watch(activitiesProvider).valueOrNull;
  if (activities == null) return null;
  final date = ref.watch(metricDetailDateProvider);
  final sodHour = ref.watch(startOfDayHourProvider).valueOrNull ?? 0;
  final start = DateTime(date.year, date.month, date.day, sodHour);
  final end = start.add(const Duration(days: 1));
  final filtered = activities
      .where((a) => !a.startTime.isBefore(start) && a.startTime.isBefore(end))
      .toList();
  if (filtered.isEmpty) return null;
  return ActivityAggregator.compute(filtered);
});

/// Activities for the metric detail selected date.
final metricDetailActivitiesProvider =
    Provider<List<ActivityModel>>((ref) {
  final activities = ref.watch(activitiesProvider).valueOrNull;
  if (activities == null) return [];
  final date = ref.watch(metricDetailDateProvider);
  final sodHour = ref.watch(startOfDayHourProvider).valueOrNull ?? 0;
  final start = DateTime(date.year, date.month, date.day, sodHour);
  final end = start.add(const Duration(days: 1));
  return activities
      .where((a) => !a.startTime.isBefore(start) && a.startTime.isBefore(end))
      .toList();
});

/// Progress metric for the metric detail selected date.
final metricDetailProgressProvider =
    Provider.family<MetricProgress?, String>((ref, metricKey) {
  final summary = ref.watch(metricDetailSummaryProvider);
  final targets = ref.watch(targetsProvider).valueOrNull ?? [];
  final baselines = ref.watch(inferredBaselinesProvider);

  // Reuse computeProgress for the selected day
  // For weekly/monthly summary, use rolling windows ending at selected date
  final activities = ref.watch(activitiesProvider).valueOrNull;
  if (activities == null) return null;
  final date = ref.watch(metricDetailDateProvider);
  final sodHour = ref.watch(startOfDayHourProvider).valueOrNull ?? 0;
  final dayEnd = DateTime(date.year, date.month, date.day, sodHour)
      .add(const Duration(days: 1));

  // Compute weekly summary for the selected date
  final weekStart = dayEnd.subtract(const Duration(days: 7));
  final weekFiltered = activities
      .where(
          (a) => !a.startTime.isBefore(weekStart) && a.startTime.isBefore(dayEnd))
      .toList();
  final weekSummary =
      weekFiltered.isEmpty ? null : ActivityAggregator.compute(weekFiltered);

  // Compute monthly summary for the selected date
  final monthStart = dayEnd.subtract(const Duration(days: 30));
  final monthFiltered = activities
      .where(
          (a) => !a.startTime.isBefore(monthStart) && a.startTime.isBefore(dayEnd))
      .toList();
  final monthSummary =
      monthFiltered.isEmpty ? null : ActivityAggregator.compute(monthFiltered);

  final progress = computeProgress(
    dailySummary: summary,
    weeklySummary: weekSummary,
    monthlySummary: monthSummary,
    baselines: baselines,
    targets: targets,
  );
  return progress.where((m) => m.key == metricKey).firstOrNull;
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

// ==========================================================================
// UI state persistence providers (#47)
// ==========================================================================

/// Expanded allergen goal periods on the Goals screen.
final goalsAllergenExpandedProvider =
    StateProvider<Set<String>>((ref) => {});

/// Visible growth chart metrics on the Growth Detail screen.
enum GrowthMetric { weight, length, head }

final growthChartVisibilityProvider =
    StateProvider<Set<GrowthMetric>>(
        (ref) => {GrowthMetric.weight, GrowthMetric.length, GrowthMetric.head});

/// Expanded allergen rows on the Allergen Detail screen.
final allergenDetailExpandedProvider =
    StateProvider<Set<String>>((ref) => {});
