import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/target_model.dart';
import '../../providers/child_provider.dart';
import '../../providers/insights_provider.dart';
import '../../providers/repository_provider.dart';
import '../../providers/target_provider.dart';
import '../../utils/activity_helpers.dart';
import '../../widgets/data_error_widget.dart';
import '../../widgets/summary_card.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targetsAsync = ref.watch(targetsProvider);
    final progress = ref.watch(targetProgressProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Goals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_add),
            tooltip: 'Bulk allergen goals',
            onPressed: () => context.push('/goals/bulk-allergens'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/goals/add'),
        child: const Icon(Icons.add),
      ),
      body: targetsAsync.when(
        data: (targets) {
          if (targets.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.track_changes,
                        size: 48,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant),
                    const SizedBox(height: 16),
                    Text(
                      'No goals set yet',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Set targets for feeds, diapers, and allergens\n'
                      'to track daily progress.',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => context.push('/goals/add'),
                      icon: const Icon(Icons.add),
                      label: const Text('Add First Goal'),
                    ),
                  ],
                ),
              ),
            );
          }

          final allergenTargets = targets
              .where((t) =>
                  t.metric == 'allergenExposures' ||
                  t.metric == 'allergenExposureDays')
              .toList();
          final otherTargets = targets
              .where((t) =>
                  t.metric != 'allergenExposures' &&
                  t.metric != 'allergenExposureDays')
              .toList();

          // Group allergen targets by period
          final allergenByPeriod = <String, List<TargetModel>>{};
          for (final t in allergenTargets) {
            allergenByPeriod.putIfAbsent(t.period, () => []).add(t);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final entry in allergenByPeriod.entries)
                _AllergenGoalSection(
                  period: entry.key,
                  targets: entry.value,
                  progress: progress,
                  onDelete: (target) =>
                      _deleteGoal(context, ref, target),
                ),
              if (otherTargets.isNotEmpty) ...[
                if (allergenByPeriod.isNotEmpty)
                  const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('Other Goals',
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                ...otherTargets.map((target) => _GoalCard(
                      target: target,
                      progress: progress,
                      onDelete: () =>
                          _deleteGoal(context, ref, target),
                      onTap: () =>
                          context.push('/goals/add?id=${target.id}'),
                    )),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => DataErrorWidget(
          error: e,
          onRetry: () => ref.invalidate(targetsProvider),
        ),
      ),
    );
  }

  Future<void> _deleteGoal(
      BuildContext context, WidgetRef ref, TargetModel target) async {
    final familyId = ref.read(selectedFamilyIdProvider);
    if (familyId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete goal?'),
        content: const Text('Are you sure you want to delete this goal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    try {
      await ref
          .read(targetRepositoryProvider)
          .deactivateTarget(familyId, target.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Goal deleted')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }
}

class _AllergenGoalSection extends ConsumerWidget {
  final String period;
  final List<TargetModel> targets;
  final List<TargetProgress> progress;
  final void Function(TargetModel) onDelete;

  const _AllergenGoalSection({
    required this.period,
    required this.targets,
    required this.progress,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expandedPeriods = ref.watch(goalsAllergenExpandedProvider);
    final expanded = expandedPeriods.contains(period);

    final total = targets.length;
    int onTrackCount = 0;
    for (final t in targets) {
      final tp = progress
          .where((p) => p.target.id == t.id)
          .firstOrNull;
      if (tp != null && tp.fraction >= 1.0) onTrackCount++;
    }
    final fraction = total > 0 ? onTrackCount / total : 0.0;
    final progressColor = fraction >= 0.8
        ? Colors.green
        : fraction >= 0.5
            ? Colors.amber
            : Colors.red;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Allergen Goals ($period)',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      context.push('/goals/bulk-allergens'),
                  child: const Text('Edit'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: fraction.clamp(0.0, 1.0),
                    color: progressColor,
                    backgroundColor:
                        progressColor.withValues(alpha: 0.2),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$onTrackCount/$total on track',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                final current = ref.read(goalsAllergenExpandedProvider);
                ref.read(goalsAllergenExpandedProvider.notifier).state =
                    expanded
                        ? ({...current}..remove(period))
                        : ({...current}..add(period));
              },
              child: Row(
                children: [
                  Icon(
                    expanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 20,
                    color:
                        Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    expanded ? 'Hide' : 'Show all',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(
                          color:
                              Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ],
              ),
            ),
            if (expanded) ...[
              const SizedBox(height: 8),
              ...targets.map((target) {
                final tp = progress
                    .where((p) => p.target.id == target.id)
                    .firstOrNull;
                final progressFraction = tp?.fraction ?? 0.0;
                final actual = tp?.actual ?? 0.0;
                final color = progressFraction >= 1.0
                    ? Colors.green
                    : progressFraction >= 0.5
                        ? Colors.amber
                        : Colors.red;

                return Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text(
                          target.allergenName ?? target.metric,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${actual.round()}/${target.targetValue.round()}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: LinearProgressIndicator(
                          value:
                              progressFraction.clamp(0.0, 1.0),
                          color: color,
                          backgroundColor:
                              color.withValues(alpha: 0.2),
                          minHeight: 4,
                          borderRadius:
                              BorderRadius.circular(2),
                        ),
                      ),
                      SizedBox(
                        width: 32,
                        child: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 16),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () =>
                              onDelete(target),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final TargetModel target;
  final List<TargetProgress> progress;
  final VoidCallback onDelete;
  final VoidCallback? onTap;

  const _GoalCard({
    required this.target,
    required this.progress,
    required this.onDelete,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final type = parseActivityType(target.activityType);
    final tp =
        progress.where((p) => p.target.id == target.id).firstOrNull;
    final progressFraction = tp?.fraction ?? 0.0;
    final actual = tp?.actual ?? 0.0;
    final color = progressFraction >= 1.0
        ? Colors.green
        : progressFraction >= 0.5
            ? Colors.amber
            : Colors.red;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (type != null) ...[
                    Icon(activityIcon(type),
                        color: activityColor(type), size: 20),
                    const SizedBox(width: 8),
                    Text(activityDisplayName(type)),
                  ] else
                    Text(target.activityType),
                  const Spacer(),
                  Chip(
                    label: Text(target.period),
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onDelete,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${_metricLabel(target.metric, ingredientName: target.ingredientName, allergenName: target.allergenName)}: ${actual.round()} / ${target.targetValue.round()}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: progressFraction.clamp(0.0, 1.0),
                color: color,
                backgroundColor: color.withValues(alpha: 0.2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _metricLabel(String metric,
      {String? ingredientName, String? allergenName}) {
    return switch (metric) {
      'totalVolumeMl' => 'Volume (ml)',
      'count' => 'Count',
      'uniqueFoods' => 'Unique foods',
      'totalDurationMinutes' => 'Duration (min)',
      'ingredientExposures' => ingredientName != null
          ? '$ingredientName exposures'
          : 'Exposures',
      'allergenExposures' => allergenName != null
          ? '$allergenName exposures'
          : 'Allergen exposures',
      'allergenExposureDays' => allergenName != null
          ? '$allergenName days'
          : 'Allergen exposure days',
      _ => metric,
    };
  }
}
