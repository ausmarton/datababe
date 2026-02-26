import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../models/activity_model.dart';
import '../../models/enums.dart';
import '../../providers/activity_provider.dart';
import '../../providers/child_provider.dart';


class ChartsScreen extends ConsumerWidget {
  const ChartsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(selectedChildProvider);
    if (child == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Charts')),
        body: const Center(child: Text('Please add a child first')),
      );
    }

    final activitiesAsync = ref.watch(activitiesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Charts')),
      body: activitiesAsync.when(
        data: (activities) {
          if (activities.isEmpty) {
            return const Center(child: Text('No data to display'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _DailySummaryCard(activities: activities),
              const SizedBox(height: 16),
              _FeedChartCard(activities: activities),
              const SizedBox(height: 16),
              _DiaperChartCard(activities: activities),
              const SizedBox(height: 16),
              _GrowthChartCard(activities: activities),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

/// Shows today's summary counts.
class _DailySummaryCard extends StatelessWidget {
  final List<ActivityModel> activities;

  const _DailySummaryCard({required this.activities});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayActivities =
        activities.where((a) => a.startTime.isAfter(todayStart)).toList();

    final feedCount = todayActivities
        .where((a) =>
            a.type == ActivityType.feedBottle.name ||
            a.type == ActivityType.feedBreast.name)
        .length;
    final diaperCount =
        todayActivities.where((a) => a.type == ActivityType.diaper.name).length;
    final totalMl = todayActivities
        .where((a) =>
            a.type == ActivityType.feedBottle.name && a.volumeMl != null)
        .fold<double>(0, (sum, a) => sum + a.volumeMl!);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Today\'s Summary',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _SummaryItem(
                  icon: Icons.baby_changing_station,
                  label: 'Feeds',
                  value: '$feedCount',
                ),
                _SummaryItem(
                  icon: Icons.baby_changing_station,
                  label: 'Volume',
                  value: '${totalMl.round()}ml',
                ),
                _SummaryItem(
                  icon: Icons.baby_changing_station,
                  label: 'Diapers',
                  value: '$diaperCount',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.headlineSmall),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// Bar chart of daily feed volumes over the last 7 days.
class _FeedChartCard extends StatelessWidget {
  final List<ActivityModel> activities;

  const _FeedChartCard({required this.activities});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return DateTime(d.year, d.month, d.day);
    });

    final dayFormat = DateFormat('E');
    final groups = <BarChartGroupData>[];

    for (var i = 0; i < days.length; i++) {
      final dayStart = days[i];
      final dayEnd = dayStart.add(const Duration(days: 1));
      final totalMl = activities
          .where((a) =>
              a.type == ActivityType.feedBottle.name &&
              a.volumeMl != null &&
              a.startTime.isAfter(dayStart) &&
              a.startTime.isBefore(dayEnd))
          .fold<double>(0, (sum, a) => sum + a.volumeMl!);

      groups.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: totalMl,
            color: Theme.of(context).colorScheme.primary,
            width: 16,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      ));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Daily Feed Volume (ml)',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  barGroups: groups,
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= days.length) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            dayFormat.format(days[idx]),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bar chart of daily diaper counts over the last 7 days.
class _DiaperChartCard extends StatelessWidget {
  final List<ActivityModel> activities;

  const _DiaperChartCard({required this.activities});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return DateTime(d.year, d.month, d.day);
    });

    final dayFormat = DateFormat('E');
    final groups = <BarChartGroupData>[];

    for (var i = 0; i < days.length; i++) {
      final dayStart = days[i];
      final dayEnd = dayStart.add(const Duration(days: 1));
      final count = activities
          .where((a) =>
              a.type == ActivityType.diaper.name &&
              a.startTime.isAfter(dayStart) &&
              a.startTime.isBefore(dayEnd))
          .length;

      groups.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: count.toDouble(),
            color: Colors.amber,
            width: 16,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      ));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Daily Diaper Count',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  barGroups: groups,
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= days.length) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            dayFormat.format(days[idx]),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Line chart of weight over time.
class _GrowthChartCard extends StatelessWidget {
  final List<ActivityModel> activities;

  const _GrowthChartCard({required this.activities});

  @override
  Widget build(BuildContext context) {
    final growthEntries = activities
        .where(
            (a) => a.type == ActivityType.growth.name && a.weightKg != null)
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    if (growthEntries.isEmpty) {
      return const SizedBox.shrink();
    }

    final spots = growthEntries.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.weightKg!);
    }).toList();

    final dateFormat = DateFormat('d/M');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Weight (kg)',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Colors.teal,
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
                          if (idx < 0 || idx >= growthEntries.length) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            dateFormat.format(growthEntries[idx].startTime),
                            style: const TextStyle(fontSize: 9),
                          );
                        },
                        interval: (growthEntries.length / 5).ceilToDouble().clamp(1, double.infinity),
                      ),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
