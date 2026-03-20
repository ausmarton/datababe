import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/activity_model.dart';
import '../../models/enums.dart';
import '../../providers/activity_provider.dart';
import '../../providers/child_provider.dart';
import '../../providers/insights_provider.dart';
import '../../utils/growth_standards.dart';
import '../../widgets/data_error_widget.dart';

class GrowthDetailScreen extends ConsumerWidget {
  const GrowthDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activitiesAsync = ref.watch(activitiesProvider);
    final visibility = ref.watch(growthChartVisibilityProvider);
    final child = ref.watch(selectedChildProvider);

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
                      onPressed: () => context.push('/log/growth'),
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
          final dob = child?.dateOfBirth;
          final gender = child?.gender;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Latest stats with percentiles
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
                      percentile: dob != null
                          ? computePercentile(
                              metric: GrowthStandardMetric.weight,
                              value: latest.weightKg!,
                              dateOfBirth: dob,
                              measurementDate: latest.startTime,
                              gender: gender,
                            )
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
                      percentile: dob != null
                          ? computePercentile(
                              metric: GrowthStandardMetric.length,
                              value: latest.lengthCm!,
                              dateOfBirth: dob,
                              measurementDate: latest.startTime,
                              gender: gender,
                            )
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
                      percentile: dob != null
                          ? computePercentile(
                              metric: GrowthStandardMetric.head,
                              value: latest.headCircumferenceCm!,
                              dateOfBirth: dob,
                              measurementDate: latest.startTime,
                              gender: gender,
                            )
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
                    onSelected: (v) =>
                        _toggleMetric(ref, GrowthMetric.weight, v),
                    selectedColor: Colors.teal.withValues(alpha: 0.2),
                    checkmarkColor: Colors.teal,
                  ),
                  FilterChip(
                    label: const Text('Length'),
                    selected: visibility.contains(GrowthMetric.length),
                    onSelected: (v) =>
                        _toggleMetric(ref, GrowthMetric.length, v),
                    selectedColor: Colors.indigo.withValues(alpha: 0.2),
                    checkmarkColor: Colors.indigo,
                  ),
                  FilterChip(
                    label: const Text('Head'),
                    selected: visibility.contains(GrowthMetric.head),
                    onSelected: (v) =>
                        _toggleMetric(ref, GrowthMetric.head, v),
                    selectedColor: Colors.orange.withValues(alpha: 0.2),
                    checkmarkColor: Colors.orange,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Charts with WHO reference curves
              if (visibility.contains(GrowthMetric.weight))
                _MetricChart(
                  label: 'Weight (kg)',
                  entries: entries,
                  getValue: (a) => a.weightKg,
                  color: Colors.teal,
                  dateOfBirth: dob,
                  gender: gender,
                  whoMetric: GrowthStandardMetric.weight,
                ),
              if (visibility.contains(GrowthMetric.length))
                _MetricChart(
                  label: 'Length (cm)',
                  entries: entries,
                  getValue: (a) => a.lengthCm,
                  color: Colors.indigo,
                  dateOfBirth: dob,
                  gender: gender,
                  whoMetric: GrowthStandardMetric.length,
                ),
              if (visibility.contains(GrowthMetric.head))
                _MetricChart(
                  label: 'Head circumference (cm)',
                  entries: entries,
                  getValue: (a) => a.headCircumferenceCm,
                  color: Colors.orange,
                  dateOfBirth: dob,
                  gender: gender,
                  whoMetric: GrowthStandardMetric.head,
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
  final double? percentile;

  const _GrowthStat({
    required this.label,
    required this.value,
    this.delta,
    this.percentile,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelSmall),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: theme.textTheme.titleMedium),
            if (percentile != null) ...[
              const SizedBox(width: 4),
              Text(
                'P${percentile!.round()}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
        if (delta != null)
          Text(
            delta!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
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
  final DateTime? dateOfBirth;
  final String? gender;
  final GrowthStandardMetric? whoMetric;

  const _MetricChart({
    required this.label,
    required this.entries,
    required this.getValue,
    required this.color,
    this.dateOfBirth,
    this.gender,
    this.whoMetric,
  });

  double _ageMonthsFractional(DateTime dob, DateTime date) {
    return date.difference(dob).inDays / 30.44;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = entries.where((a) => getValue(a) != null).toList();
    if (filtered.isEmpty) return const SizedBox.shrink();

    final dob = dateOfBirth;
    final useAge = dob != null;

    // Child's data points
    final spots = filtered.asMap().entries.map((e) {
      final x = useAge
          ? _ageMonthsFractional(dob, e.value.startTime)
          : e.key.toDouble();
      return FlSpot(x, getValue(e.value)!);
    }).toList();

    // WHO reference curve data (only if we have DOB and metric)
    final refLines = <LineChartBarData>[];
    if (useAge && whoMetric != null) {
      final minAge = spots.map((s) => s.x).reduce((a, b) => a < b ? a : b);
      final maxAge = spots.map((s) => s.x).reduce((a, b) => a > b ? a : b);
      final startMonth = minAge.floor().clamp(0, 24);
      final endMonth = maxAge.ceil().clamp(0, 24);

      if (endMonth > startMonth) {
        final pctColors = [
          Colors.grey.withValues(alpha: 0.3), // P3
          Colors.grey.withValues(alpha: 0.2), // P15
          Colors.grey.withValues(alpha: 0.4), // P50
          Colors.grey.withValues(alpha: 0.2), // P85
          Colors.grey.withValues(alpha: 0.3), // P97
        ];
        final pctExtractors = <double Function(GrowthPercentiles)>[
          (p) => p.p3,
          (p) => p.p15,
          (p) => p.p50,
          (p) => p.p85,
          (p) => p.p97,
        ];

        for (int pIdx = 0; pIdx < 5; pIdx++) {
          final refSpots = <FlSpot>[];
          for (int m = startMonth; m <= endMonth; m++) {
            final pct = getWhoPercentiles(
              metric: whoMetric!,
              ageMonths: m,
              gender: gender,
            );
            if (pct != null) {
              refSpots.add(FlSpot(m.toDouble(), pctExtractors[pIdx](pct)));
            }
          }
          if (refSpots.length >= 2) {
            refLines.add(LineChartBarData(
              spots: refSpots,
              isCurved: true,
              color: pctColors[pIdx],
              barWidth: pIdx == 2 ? 1.5 : 1, // P50 slightly thicker
              dotData: const FlDotData(show: false),
              dashArray: pIdx == 2 ? null : [4, 4], // P50 solid, rest dashed
            ));
          }
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child:
                    Text(label, style: Theme.of(context).textTheme.titleSmall),
              ),
              if (refLines.isNotEmpty)
                Text(
                  'WHO percentiles',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.grey,
                      ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                lineBarsData: [
                  ...refLines,
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
                        if (useAge) {
                          if (value == value.roundToDouble() && value >= 0) {
                            return Text(
                              '${value.toInt()}m',
                              style: const TextStyle(fontSize: 9),
                            );
                          }
                          return const SizedBox.shrink();
                        }
                        // Fallback: index-based dates
                        final idx = value.toInt();
                        if (idx < 0 || idx >= filtered.length) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          '${filtered[idx].startTime.day}/${filtered[idx].startTime.month}',
                          style: const TextStyle(fontSize: 9),
                        );
                      },
                      interval: useAge ? 1 : (filtered.length / 5)
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
          if (refLines.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Dashed: 3rd/15th/85th/97th  •  Solid: 50th (median)',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.grey,
                      fontSize: 10,
                    ),
              ),
            ),
        ],
      ),
    );
  }
}
