import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/enums.dart';
import '../models/target_model.dart';
import '../widgets/summary_card.dart';
import 'activity_provider.dart';
import 'child_provider.dart';
import 'repository_provider.dart';

/// Active targets for the selected child.
final targetsProvider = StreamProvider<List<TargetModel>>((ref) {
  final familyId = ref.watch(selectedFamilyIdProvider);
  final childId = ref.watch(selectedChildIdProvider);
  final repo = ref.watch(targetRepositoryProvider);
  if (familyId == null || childId == null) return Stream.value([]);
  return repo.watchTargets(familyId, childId);
});

/// Evaluates each target against the current timeline summary.
final targetProgressProvider = Provider<List<TargetProgress>>((ref) {
  final targets = ref.watch(targetsProvider).valueOrNull ?? [];
  final summary = ref.watch(timelineSummaryProvider);
  final mode = ref.watch(timelineWindowModeProvider);

  if (summary == null || targets.isEmpty) return [];

  final results = <TargetProgress>[];

  for (final target in targets) {
    // Check if timeline range matches target period
    if (!_periodMatches(target.period, mode)) continue;

    final actual = _extractMetric(target, summary);
    if (actual == null) continue;

    final fraction =
        target.targetValue > 0 ? (actual / target.targetValue) : 0.0;

    results.add(TargetProgress(
      target: target,
      actual: actual,
      fraction: fraction.clamp(0.0, 1.0),
    ));
  }

  return results;
});

bool _periodMatches(String period, TimeWindowMode mode) {
  return switch (period) {
    'daily' => mode == TimeWindowMode.calendarDay ||
        mode == TimeWindowMode.last24h,
    'weekly' => mode == TimeWindowMode.calendarWeek ||
        mode == TimeWindowMode.last7Days,
    'monthly' => mode == TimeWindowMode.calendarMonth ||
        mode == TimeWindowMode.last30Days,
    _ => false,
  };
}

double? _extractMetric(
    TargetModel target, dynamic summary) {
  final metric = target.metric;
  final actType = target.activityType;

  switch (metric) {
    case 'totalVolumeMl':
      if (actType == ActivityType.feedBottle.name) {
        return summary.bottleFeedTotalMl;
      }
      if (actType == ActivityType.pump.name) {
        return summary.pumpTotalMl;
      }
      return null;

    case 'count':
      if (actType == ActivityType.feedBottle.name) {
        return summary.bottleFeedCount.toDouble();
      }
      if (actType == ActivityType.feedBreast.name) {
        return summary.breastFeedCount.toDouble();
      }
      if (actType == ActivityType.diaper.name) {
        return summary.diaperCount.toDouble();
      }
      if (actType == ActivityType.solids.name) {
        return summary.solidsCount.toDouble();
      }
      if (actType == ActivityType.pump.name) {
        return summary.pumpCount.toDouble();
      }
      if (actType == ActivityType.potty.name) {
        return summary.pottyCount.toDouble();
      }
      final count = summary.durationCounts[actType];
      return count?.toDouble();

    case 'uniqueFoods':
      if (actType == ActivityType.solids.name) {
        return summary.uniqueFoods.length.toDouble();
      }
      return null;

    case 'totalDurationMinutes':
      if (actType == ActivityType.feedBreast.name) {
        return summary.breastFeedTotalMinutes.toDouble();
      }
      final mins = summary.durationTotals[actType];
      return mins?.toDouble();

    case 'ingredientExposures':
      if (actType == ActivityType.solids.name &&
          target.ingredientName != null) {
        return summary
                .ingredientExposures[
                    target.ingredientName!.trim().toLowerCase()]
                ?.toDouble() ??
            0.0;
      }
      return null;

    case 'allergenExposures':
      if (actType == ActivityType.solids.name &&
          target.allergenName != null) {
        return summary
                .allergenExposures[
                    target.allergenName!.trim().toLowerCase()]
                ?.toDouble() ??
            0.0;
      }
      return null;

    case 'allergenExposureDays':
      if (actType == ActivityType.solids.name &&
          target.allergenName != null) {
        return summary
                .allergenExposureDays[
                    target.allergenName!.trim().toLowerCase()]
                ?.toDouble() ??
            0.0;
      }
      return null;

    default:
      return null;
  }
}
