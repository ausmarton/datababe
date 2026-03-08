import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/target_model.dart';
import '../../providers/child_provider.dart';
import '../../providers/repository_provider.dart';
import '../../providers/target_provider.dart';
import '../../utils/activity_helpers.dart';

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
            return const Center(
              child: Text('No goals set yet.\nTap + to add one.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: targets.length,
            itemBuilder: (context, index) {
              final target = targets[index];
              final type = parseActivityType(target.activityType);
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

              return Card(
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
                            onPressed: () =>
                                _deleteGoal(context, ref, target),
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
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
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

  String _metricLabel(String metric,
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
      _ => metric,
    };
  }
}
