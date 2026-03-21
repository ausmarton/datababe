import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/enums.dart';
import '../models/target_model.dart';
import '../widgets/summary_card.dart';
import 'activity_provider.dart';
import 'child_provider.dart';
import 'insights_provider.dart';
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
    if (!periodMatchesMode(target.period, mode)) continue;

    final actual = extractMetricFromSummary(
      target.activityType,
      target.metric,
      summary,
      ingredientName: target.ingredientName,
      allergenName: target.allergenName,
    );
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

/// Whether a target period matches the given time window mode.
bool periodMatchesMode(String period, TimeWindowMode mode) {
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
