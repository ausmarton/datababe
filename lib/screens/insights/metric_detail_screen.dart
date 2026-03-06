import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/activity_provider.dart';
import '../../providers/insights_provider.dart';
import '../../utils/activity_helpers.dart';
import '../../widgets/activity_tile.dart';
import '../../widgets/trend_chart.dart';

class MetricDetailScreen extends ConsumerWidget {
  final String metricKey;

  const MetricDetailScreen({super.key, required this.metricKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(todayProgressProvider);
    final metric = progress.where((m) => m.key == metricKey).firstOrNull;

    // Parse activity type from key (e.g. "feedBottle.totalVolumeMl")
    final dotIndex = metricKey.indexOf('.');
    final activityTypeName = dotIndex >= 0 ? metricKey.substring(0, dotIndex) : metricKey;
    final activityType = parseActivityType(activityTypeName);

    final title = metric?.label ?? (activityType != null
        ? activityDisplayName(activityType)
        : activityTypeName);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Today's progress
          _TodayProgress(metric: metric),
          const SizedBox(height: 16),

          // Today's entries
          _TodayEntries(activityTypeName: activityTypeName),
          const SizedBox(height: 16),

          // 7-day trend
          _TrendCard(
            title: '7-day trend',
            metricKey: metricKey,
            days: 7,
            color: activityType != null
                ? activityColor(activityType)
                : Colors.blue,
          ),
          const SizedBox(height: 16),

          // 30-day trend
          _TrendCard(
            title: '30-day trend',
            metricKey: metricKey,
            days: 30,
            color: activityType != null
                ? activityColor(activityType)
                : Colors.blue,
          ),
          const SizedBox(height: 16),

          // Target info
          _TargetInfo(metric: metric),
        ],
      ),
    );
  }
}

class _TodayProgress extends StatelessWidget {
  final MetricProgress? metric;

  const _TodayProgress({this.metric});

  @override
  Widget build(BuildContext context) {
    if (metric == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Today's Progress",
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text('No data for today yet'),
            ],
          ),
        ),
      );
    }

    final m = metric!;
    final statusColor = m.fraction >= 0.8
        ? Colors.green
        : m.fraction >= 0.4
            ? Colors.amber
            : Colors.red;
    final targetLabel = m.isExplicit
        ? 'of ${m.target.round()}${m.unit} target'
        : 'of ${m.target.round()}${m.unit} avg';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Today's Progress",
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '${m.actual.round()}${m.unit}',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(width: 8),
                Text(targetLabel,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: m.fraction.clamp(0.0, 1.0),
              color: statusColor,
              backgroundColor: statusColor.withValues(alpha: 0.15),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayEntries extends ConsumerWidget {
  final String activityTypeName;

  const _TodayEntries({required this.activityTypeName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailyAsync = ref.watch(dailyActivitiesProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Today's Entries",
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            dailyAsync.when(
              data: (activities) {
                final filtered = activities
                    .where((a) => a.type == activityTypeName)
                    .toList();
                if (filtered.isEmpty) {
                  return const Text('No entries today');
                }
                return Column(
                  children: filtered
                      .map((a) => ActivityTile(activity: a))
                      .toList(),
                );
              },
              loading: () => const Center(
                  child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendCard extends ConsumerWidget {
  final String title;
  final String metricKey;
  final int days;
  final Color color;

  const _TrendCard({
    required this.title,
    required this.metricKey,
    required this.days,
    required this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(
        metricTrendDataProvider((metricKey: metricKey, days: days)));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TrendChart(data: data, barColor: color),
          ],
        ),
      ),
    );
  }
}

class _TargetInfo extends StatelessWidget {
  final MetricProgress? metric;

  const _TargetInfo({this.metric});

  @override
  Widget build(BuildContext context) {
    if (metric == null) return const SizedBox.shrink();

    final m = metric!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Target', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (m.isExplicit)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Goal: ${m.target.round()}${m.unit} per day',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/goals'),
                    child: const Text('Edit'),
                  ),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Based on your 7-day average of ${m.target.round()}${m.unit}.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => context.push('/goals/add'),
                    child: const Text('Set an explicit goal'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
