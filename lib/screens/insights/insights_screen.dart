import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/activity_model.dart';
import '../../models/enums.dart';
import '../../providers/activity_provider.dart';
import '../../providers/child_provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/insights_provider.dart';
import '../../utils/activity_helpers.dart';
import '../../widgets/allergen_matrix.dart';
import '../../widgets/progress_ring.dart';
import '../../widgets/trend_chart.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(selectedChildProvider);
    if (child == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Insights')),
        body: const Center(child: Text('Please add a child first')),
      );
    }

    final activitiesAsync = ref.watch(activitiesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: 'Goals',
            onPressed: () => context.push('/goals'),
          ),
        ],
      ),
      body: activitiesAsync.when(
        data: (activities) {
          if (activities.isEmpty) {
            return const Center(
              child: Text('Start logging activities to see insights'),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _TodaySection(),
              const SizedBox(height: 16),
              const _AllergenTrackerSection(),
              const SizedBox(height: 16),
              const _WeeklyAllergenSection(),
              const SizedBox(height: 16),
              const _TrendSection(),
              const SizedBox(height: 16),
              _GrowthSection(activities: activities),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _TodaySection extends ConsumerWidget {
  const _TodaySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(todayProgressProvider);

    if (progress.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Today', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text('Log a few more days to see progress tracking'),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Today', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: progress.map((m) {
                  final actualStr = m.actual.round().toString();
                  final targetStr = m.target.round().toString();
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ProgressRing(
                      fraction: m.fraction,
                      icon: m.icon,
                      color: m.color,
                      actual:
                          m.unit.isNotEmpty ? '$actualStr${m.unit}' : actualStr,
                      target:
                          m.unit.isNotEmpty ? '$targetStr${m.unit}' : targetStr,
                      label: m.label,
                      isInferred: !m.isExplicit,
                      onTap: () => context.push(
                          '/insights/metric/${Uri.encodeComponent(m.key)}'),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendSection extends ConsumerWidget {
  const _TrendSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metric = ref.watch(selectedTrendMetricProvider);
    final period = ref.watch(selectedTrendPeriodProvider);
    final trendData = ref.watch(trendDataProvider);
    final baseline = ref.watch(trendBaselineProvider);

    final metricColor = switch (metric) {
      TrendMetric.feedVolume => activityColor(ActivityType.feedBottle),
      TrendMetric.diapers => activityColor(ActivityType.diaper),
      TrendMetric.solids => activityColor(ActivityType.solids),
      TrendMetric.tummyTime => activityColor(ActivityType.tummyTime),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Trends', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<TrendMetric>(
                segments: TrendMetric.values
                    .map((m) =>
                        ButtonSegment(value: m, label: Text(m.label)))
                    .toList(),
                selected: {metric},
                onSelectionChanged: (s) => ref
                    .read(selectedTrendMetricProvider.notifier)
                    .state = s.first,
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7, label: Text('7d')),
                ButtonSegment(value: 30, label: Text('30d')),
              ],
              selected: {period},
              onSelectionChanged: (s) => ref
                  .read(selectedTrendPeriodProvider.notifier)
                  .state = s.first,
              showSelectedIcon: false,
              style:
                  const ButtonStyle(visualDensity: VisualDensity.compact),
            ),
            const SizedBox(height: 12),
            TrendChart(
              data: trendData,
              baselineValue: baseline,
              barColor: metricColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _AllergenTrackerSection extends ConsumerWidget {
  const _AllergenTrackerSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(allergenCategoriesProvider);

    if (categories.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Allergen Tracker',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text(
                'Define your allergen categories in Settings > Manage Allergens to start tracking exposure.',
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.push('/settings/allergens'),
                child: const Text('Manage Allergens'),
              ),
            ],
          ),
        ),
      );
    }

    final coverage = ref.watch(allergenCoverageProvider);
    final period = ref.watch(allergenCoveragePeriodProvider);

    if (coverage == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Allergen Tracker',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text(
                'Start logging solids with ingredients to track allergen exposure.',
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => context.push('/insights/allergens'),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Allergen Tracker',
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 7, label: Text('7d')),
                      ButtonSegment(value: 14, label: Text('14d')),
                    ],
                    selected: {period},
                    onSelectionChanged: (s) => ref
                        .read(allergenCoveragePeriodProvider.notifier)
                        .state = s.first,
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (coverage.covered.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: coverage.covered.map((a) {
                    final tp = coverage.targetProgress[a];
                    return Chip(
                      avatar: const Icon(Icons.check_circle,
                          size: 16, color: Colors.green),
                      label: Text(tp != null
                          ? '$a ${tp.actual.round()}/${tp.scaledTarget.round()}'
                          : a),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    );
                  }).toList(),
                ),
              ],
              if (coverage.missing.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _sortedMissing(coverage).map((a) {
                    final tp = coverage.targetProgress[a];
                    final urgency = coverage.urgencyInfo[a];
                    final hasProgress = (tp != null && tp.actual > 0) ||
                        (tp == null &&
                            (coverage.exposureCounts[a] ?? 0) > 0);

                    // Icon/color: overdue→red warning, due/partial→amber,
                    // zero→outline only
                    final Widget? avatar;
                    final BorderSide? side;
                    if (urgency?.urgency == AllergenUrgency.overdue) {
                      avatar = const Icon(Icons.warning_amber,
                          size: 16, color: Colors.red);
                      side = null;
                    } else if (hasProgress ||
                        urgency?.urgency == AllergenUrgency.due) {
                      avatar = const Icon(Icons.timelapse,
                          size: 16, color: Colors.amber);
                      side = null;
                    } else {
                      avatar = null;
                      side = BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .outlineVariant);
                    }

                    // Label: name + progress + last given
                    String label = a;
                    if (tp != null) {
                      label =
                          '$a ${tp.actual.round()}/${tp.scaledTarget.round()}';
                    }
                    if (urgency != null &&
                        urgency.daysSinceExposure < 999) {
                      label += ' (${urgency.daysSinceExposure}d ago)';
                    }

                    return Chip(
                      avatar: avatar,
                      label: Text(label),
                      side: side,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                Builder(builder: (context) {
                  // Suggest the most urgent missing allergens.
                  final sorted = _sortedMissing(coverage);
                  final suggestions = sorted.take(2).join(' or ');
                  return Text(
                    'Consider introducing $suggestions to maintain rotation.',
                    style:
                        Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WeeklyAllergenSection extends ConsumerWidget {
  const _WeeklyAllergenSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(allergenCategoriesProvider);
    if (categories.isEmpty) return const SizedBox.shrink();

    final matrix = ref.watch(weeklyAllergenMatrixProvider);
    if (matrix == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This Week',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            AllergenMatrix(matrix: matrix),
          ],
        ),
      ),
    );
  }
}

class _GrowthSection extends StatelessWidget {
  final List<ActivityModel> activities;

  const _GrowthSection({required this.activities});

  @override
  Widget build(BuildContext context) {
    final growthEntries = activities
        .where((a) => a.type == ActivityType.growth.name)
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    if (growthEntries.isEmpty) return const SizedBox.shrink();

    final latest = growthEntries.last;
    final previous =
        growthEntries.length >= 2 ? growthEntries[growthEntries.length - 2] : null;

    return GestureDetector(
      onTap: () => context.push('/insights/growth'),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Growth',
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  Icon(Icons.chevron_right,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  if (latest.weightKg != null)
                    _GrowthStat(
                      label: 'Weight',
                      value: '${latest.weightKg}kg',
                      delta: previous?.weightKg != null
                          ? _formatDelta(
                              latest.weightKg! - previous!.weightKg!, 'kg')
                          : null,
                    ),
                  if (latest.lengthCm != null)
                    _GrowthStat(
                      label: 'Length',
                      value: '${latest.lengthCm}cm',
                      delta: previous?.lengthCm != null
                          ? _formatDelta(
                              latest.lengthCm! - previous!.lengthCm!, 'cm')
                          : null,
                    ),
                  if (latest.headCircumferenceCm != null)
                    _GrowthStat(
                      label: 'Head',
                      value: '${latest.headCircumferenceCm}cm',
                      delta: previous?.headCircumferenceCm != null
                          ? _formatDelta(
                              latest.headCircumferenceCm! -
                                  previous!.headCircumferenceCm!,
                              'cm')
                          : null,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDelta(double delta, String unit) {
    final sign = delta >= 0 ? '+' : '';
    return '$sign${delta.toStringAsFixed(1)}$unit';
  }
}

class _GrowthStat extends StatelessWidget {
  final String label;
  final String value;
  final String? delta;

  const _GrowthStat({
    required this.label,
    required this.value,
    this.delta,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
        if (delta != null)
          Text(
            delta!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
      ],
    );
  }
}

/// Sort missing allergens by urgency: overdue first, then due, then rest.
List<String> _sortedMissing(AllergenCoverage coverage) {
  final list = coverage.missing.toList();
  list.sort((a, b) {
    final ua = coverage.urgencyInfo[a];
    final ub = coverage.urgencyInfo[b];
    final orderA = ua == null
        ? 3
        : ua.urgency == AllergenUrgency.overdue
            ? 0
            : ua.urgency == AllergenUrgency.due
                ? 1
                : 2;
    final orderB = ub == null
        ? 3
        : ub.urgency == AllergenUrgency.overdue
            ? 0
            : ub.urgency == AllergenUrgency.due
                ? 1
                : 2;
    if (orderA != orderB) return orderA.compareTo(orderB);
    // Within same urgency, sort by days since exposure (most overdue first).
    final daysA = ua?.daysSinceExposure ?? 999;
    final daysB = ub?.daysSinceExposure ?? 999;
    return daysB.compareTo(daysA);
  });
  return list;
}
