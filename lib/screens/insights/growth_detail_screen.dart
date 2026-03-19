import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/activity_model.dart';
import '../../models/enums.dart';
import '../../providers/activity_provider.dart';
import '../../providers/insights_provider.dart';
import '../../widgets/data_error_widget.dart';

class GrowthDetailScreen extends ConsumerWidget {
  const GrowthDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activitiesAsync = ref.watch(activitiesProvider);
    final visibility = ref.watch(growthChartVisibilityProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Growth')),
      body: activitiesAsync.when(
        data: (activities) {
          final entries = activities
              .where((a) => a.type == ActivityType.growth.name)
              .toList()
            ..sort((a, b) => a.startTime.compareTo(b.startTime));

          if (entries.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.show_chart,
                        size: 48,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant),
                    const SizedBox(height: 16),
                    Text(
                      'No growth entries yet',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Log weight, length, or head circumference\n'
                      'to see growth charts and trends.',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () =>
                          context.push('/log/growth'),
                      icon: const Icon(Icons.add),
                      label: const Text('Log Growth'),
                    ),
                  ],
                ),
              ),
            );
          }

          final latest = entries.last;
          final previous =
              entries.length >= 2 ? entries[entries.length - 2] : null;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Latest stats
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
              const SizedBox(height: 16),

              // Toggles
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Weight'),
                    selected: visibility.contains(GrowthMetric.weight),
                    onSelected: (v) => _toggleMetric(ref, GrowthMetric.weight, v),
                    selectedColor: Colors.teal.withValues(alpha: 0.2),
                    checkmarkColor: Colors.teal,
                  ),
                  FilterChip(
                    label: const Text('Length'),
                    selected: visibility.contains(GrowthMetric.length),
                    onSelected: (v) => _toggleMetric(ref, GrowthMetric.length, v),
                    selectedColor: Colors.indigo.withValues(alpha: 0.2),
                    checkmarkColor: Colors.indigo,
                  ),
                  FilterChip(
                    label: const Text('Head'),
                    selected: visibility.contains(GrowthMetric.head),
                    onSelected: (v) => _toggleMetric(ref, GrowthMetric.head, v),
                    selectedColor: Colors.orange.withValues(alpha: 0.2),
                    checkmarkColor: Colors.orange,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Charts
              if (visibility.contains(GrowthMetric.weight))
                _MetricChart(
                  label: 'Weight (kg)',
                  entries: entries,
                  getValue: (a) => a.weightKg,
                  color: Colors.teal,
                ),
              if (visibility.contains(GrowthMetric.length))
                _MetricChart(
                  label: 'Length (cm)',
                  entries: entries,
                  getValue: (a) => a.lengthCm,
                  color: Colors.indigo,
                ),
              if (visibility.contains(GrowthMetric.head))
                _MetricChart(
                  label: 'Head circumference (cm)',
                  entries: entries,
                  getValue: (a) => a.headCircumferenceCm,
                  color: Colors.orange,
                ),
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

  void _toggleMetric(WidgetRef ref, GrowthMetric metric, bool on) {
    final current = ref.read(growthChartVisibilityProvider);
    ref.read(growthChartVisibilityProvider.notifier).state =
        on ? ({...current}..add(metric)) : ({...current}..remove(metric));
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

class _MetricChart extends StatelessWidget {
  final String label;
  final List<ActivityModel> entries;
  final double? Function(ActivityModel) getValue;
  final Color color;

  const _MetricChart({
    required this.label,
    required this.entries,
    required this.getValue,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = entries.where((a) => getValue(a) != null).toList();
    if (filtered.isEmpty) return const SizedBox.shrink();

    final spots = filtered.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), getValue(e.value)!);
    }).toList();

    final dateFormat = DateFormat('d/M');

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: color,
                    barWidth: 2,
                    dotData: const FlDotData(show: true),
                  ),
                ],
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= filtered.length) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          dateFormat.format(filtered[idx].startTime),
                          style: const TextStyle(fontSize: 9),
                        );
                      },
                      interval: (filtered.length / 5)
                          .ceilToDouble()
                          .clamp(1, double.infinity),
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles:
                        SideTitles(showTitles: true, reservedSize: 40),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                gridData:
                    const FlGridData(show: true, drawVerticalLine: false),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
