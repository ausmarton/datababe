import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/activity_model.dart';
import '../../models/enums.dart';
import '../../providers/activity_provider.dart';
import '../../providers/child_provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/insights_provider.dart';
import '../../providers/settings_provider.dart';
import '../../utils/activity_helpers.dart';
import '../../utils/date_range_helpers.dart';
import '../../widgets/allergen_matrix.dart';
import '../../widgets/progress_ring.dart';
import '../../widgets/data_error_widget.dart';
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
            return Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.insights,
                          size: 48,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant),
                      const SizedBox(height: 16),
                      Text(
                        'No insights yet',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Log a few days of activities to see\n'
                        'patterns, trends, and progress.',
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () =>
                            context.push('/log/feedBottle'),
                        icon: const Icon(Icons.add),
                        label: const Text('Start Logging'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _PeriodSelector(),
              const SizedBox(height: 16),
              const _ProgressSection(),
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
        error: (e, _) => DataErrorWidget(
          error: e,
          onRetry: () => ref.invalidate(activitiesProvider),
        ),
      ),
    );
  }
}

enum _Granularity { day, week, month }

class _PeriodSelector extends ConsumerWidget {
  const _PeriodSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(insightsWindowModeProvider);
    final anchor = ref.watch(insightsAnchorProvider);
    final sodHour = ref.watch(startOfDayHourProvider).valueOrNull ?? 0;
    final isCalendar = isCalendarMode(mode);

    _Granularity granularity;
    if (mode == TimeWindowMode.calendarDay ||
        mode == TimeWindowMode.last24h) {
      granularity = _Granularity.day;
    } else if (mode == TimeWindowMode.calendarWeek ||
        mode == TimeWindowMode.last7Days) {
      granularity = _Granularity.week;
    } else {
      granularity = _Granularity.month;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<_Granularity>(
              segments: const [
                ButtonSegment(
                    value: _Granularity.day, label: Text('Day')),
                ButtonSegment(
                    value: _Granularity.week, label: Text('Week')),
                ButtonSegment(
                    value: _Granularity.month, label: Text('Month')),
              ],
              selected: {granularity},
              onSelectionChanged: (s) {
                final g = s.first;
                TimeWindowMode newMode;
                if (isCalendar) {
                  newMode = switch (g) {
                    _Granularity.day => TimeWindowMode.calendarDay,
                    _Granularity.week => TimeWindowMode.calendarWeek,
                    _Granularity.month => TimeWindowMode.calendarMonth,
                  };
                } else {
                  newMode = switch (g) {
                    _Granularity.day => TimeWindowMode.last24h,
                    _Granularity.week => TimeWindowMode.last7Days,
                    _Granularity.month => TimeWindowMode.last30Days,
                  };
                }
                ref.read(insightsWindowModeProvider.notifier).state = newMode;
              },
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ChoiceChip(
                  label: Text(isCalendar ? 'Calendar' : 'Rolling'),
                  selected: isCalendar,
                  onSelected: (_) {
                    TimeWindowMode newMode;
                    if (isCalendar) {
                      newMode = switch (granularity) {
                        _Granularity.day => TimeWindowMode.last24h,
                        _Granularity.week => TimeWindowMode.last7Days,
                        _Granularity.month => TimeWindowMode.last30Days,
                      };
                    } else {
                      newMode = switch (granularity) {
                        _Granularity.day => TimeWindowMode.calendarDay,
                        _Granularity.week => TimeWindowMode.calendarWeek,
                        _Granularity.month => TimeWindowMode.calendarMonth,
                      };
                    }
                    ref.read(insightsWindowModeProvider.notifier).state =
                        newMode;
                  },
                ),
                const Spacer(),
                if (isCalendar) ...[
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () {
                      ref.read(insightsAnchorProvider.notifier).state =
                          previousAnchor(mode, anchor);
                    },
                  ),
                  Text(
                    rangeLabel(mode, anchor, startOfDayHour: sodHour),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _isNextInFuture(mode, anchor, sodHour)
                        ? null
                        : () {
                            ref.read(insightsAnchorProvider.notifier).state =
                                nextAnchor(mode, anchor);
                          },
                  ),
                ] else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      rangeLabel(mode, anchor, startOfDayHour: sodHour),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _isNextInFuture(
      TimeWindowMode mode, DateTime anchor, int startOfDayHour) {
    final next = nextAnchor(mode, anchor);
    final today = startOfDay(DateTime.now(), startOfDayHour);
    return next.isAfter(today);
  }
}

class _ProgressSection extends ConsumerWidget {
  const _ProgressSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(insightsProgressProvider);
    final mode = ref.watch(insightsWindowModeProvider);
    final anchor = ref.watch(insightsAnchorProvider);
    final sodHour = ref.watch(startOfDayHourProvider).valueOrNull ?? 0;
    final label = rangeLabel(mode, anchor, startOfDayHour: sodHour);

    if (progress.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Progress',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
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
            Text('Progress',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
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
                          m.key.startsWith('allergens.aggregate')
                              ? '/insights/allergens'
                              : '/insights/metric/${Uri.encodeComponent(m.key)}'),
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

    final coverage = ref.watch(insightsAllergenCoverageProvider);
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

    final attention = coverage.attentionAllergens;
    final coveredCount = coverage.covered.length;
    final missingCount = coverage.missing.length;
    final nonAttentionMissing = missingCount - attention.length;
    final progressColor = coverage.coveredFraction >= 0.8
        ? Colors.green
        : coverage.coveredFraction >= 0.5
            ? Colors.amber
            : Colors.red;

    return GestureDetector(
      onTap: () => context.push('/insights/allergens'),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title + period toggle
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

              // Summary progress bar
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: coverage.coveredFraction,
                      color: progressColor,
                      backgroundColor:
                          progressColor.withValues(alpha: 0.2),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$coveredCount/${coverage.totalCount} covered',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),

              // Needs attention list
              if (attention.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Needs attention (${attention.length})',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 4),
                ...attention.map((a) {
                  final urgency = coverage.urgencyInfo[a]!;
                  final tp = coverage.targetProgress[a];
                  final isOverdue =
                      urgency.urgency == AllergenUrgency.overdue;

                  String trailing = isOverdue
                      ? '${urgency.daysSinceExposure}d overdue'
                      : 'due';
                  if (tp != null) {
                    trailing +=
                        ', ${tp.actual.round()}/${tp.scaledTarget.round()} exposures';
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Icon(
                          isOverdue
                              ? Icons.warning_amber
                              : Icons.timelapse,
                          size: 16,
                          color: isOverdue ? Colors.red : Colors.amber,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            a,
                            style:
                                Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        Text(
                          trailing,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  );
                }),
              ],

              // All on track
              if (attention.isEmpty && coverage.missing.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.check_circle,
                        size: 16, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      'All on track',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.green),
                    ),
                  ],
                ),
              ],

              // Footer summary + "All" link
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      nonAttentionMissing > 0
                          ? '$nonAttentionMissing more missing \u00b7 $coveredCount covered'
                          : '$coveredCount covered',
                      style:
                          Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                    ),
                  ),
                  Text(
                    'All \u25b8',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ],
              ),
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

    final matrix = ref.watch(insightsWeeklyAllergenMatrixProvider);
    if (matrix == null) return const SizedBox.shrink();

    final matrixWeek = ref.watch(insightsMatrixWeekProvider);
    final filter = ref.watch(allergenMatrixFilterProvider);

    // Week label from matrix days
    final weekLabel = matrix.days.isNotEmpty
        ? '${DateFormat('d MMM').format(matrix.days.first)} – ${DateFormat('d MMM').format(matrix.days.last)}'
        : 'This Week';

    // Filter and sort allergens
    final List<String> filteredAllergens;
    if (filter == AllergenMatrixFilter.exposedOnly) {
      filteredAllergens = matrix.allergens
          .where((a) => (matrix.matrix[a] ?? {}).isNotEmpty)
          .toList()
        ..sort((a, b) {
          final countA = (matrix.matrix[a] ?? {}).length;
          final countB = (matrix.matrix[b] ?? {}).length;
          if (countA != countB) return countB.compareTo(countA);
          return a.compareTo(b);
        });
    } else {
      filteredAllergens = matrix.allergens;
    }

    final unexposedCount = matrix.allergens.length - filteredAllergens.length;

    final filteredMatrix = WeeklyAllergenMatrix(
      days: matrix.days,
      allergens: filteredAllergens,
      matrix: Map.fromEntries(
        filteredAllergens.map((a) => MapEntry(a, matrix.matrix[a] ?? {})),
      ),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 20),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    ref.read(insightsMatrixWeekProvider.notifier).state =
                        matrixWeek.subtract(const Duration(days: 7));
                  },
                ),
                Expanded(
                  child: Text(weekLabel,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 20),
                  visualDensity: VisualDensity.compact,
                  onPressed: _isNextWeekInFuture(matrixWeek)
                      ? null
                      : () {
                          ref.read(insightsMatrixWeekProvider.notifier).state =
                              matrixWeek.add(const Duration(days: 7));
                        },
                ),
                const SizedBox(width: 4),
                SegmentedButton<AllergenMatrixFilter>(
                  segments: const [
                    ButtonSegment(
                      value: AllergenMatrixFilter.exposedOnly,
                      label: Text('Exposed'),
                    ),
                    ButtonSegment(
                      value: AllergenMatrixFilter.all,
                      label: Text('All'),
                    ),
                  ],
                  selected: {filter},
                  onSelectionChanged: (s) => ref
                      .read(allergenMatrixFilterProvider.notifier)
                      .state = s.first,
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (filteredAllergens.isEmpty)
              Text(
                'No allergens exposed this week',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              )
            else
              AllergenMatrix(matrix: filteredMatrix),
            if (filter == AllergenMatrixFilter.exposedOnly &&
                unexposedCount > 0) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => ref
                    .read(allergenMatrixFilterProvider.notifier)
                    .state = AllergenMatrixFilter.all,
                child: Text(
                  '$unexposedCount allergen${unexposedCount == 1 ? '' : 's'} not exposed this week',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _isNextWeekInFuture(DateTime matrixWeek) {
    final now = DateTime.now();
    final thisMonday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    return !matrixWeek.isBefore(thisMonday);
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
