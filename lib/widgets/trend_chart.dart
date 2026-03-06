import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../providers/insights_provider.dart';

class TrendChart extends StatelessWidget {
  final List<TrendPoint> data;
  final double? baselineValue;
  final Color barColor;

  const TrendChart({
    super.key,
    required this.data,
    this.baselineValue,
    this.barColor = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('No data')),
      );
    }

    final dayFormat = DateFormat('E');
    final dateFormat = DateFormat('d/M');
    final isWeekView = data.length <= 7;

    final maxY =
        data.fold<double>(0, (max, p) => p.value > max ? p.value : max);
    final baselineMax =
        baselineValue != null && baselineValue! > maxY ? baselineValue! : maxY;
    final effectiveMax = baselineMax * 1.2;

    final groups = data.asMap().entries.map((e) {
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: e.value.value,
            color: barColor,
            width: isWeekView ? 16 : 8,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    }).toList();

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          maxY: effectiveMax > 0 ? effectiveMax : 10,
          barGroups: groups,
          extraLinesData: baselineValue != null && baselineValue! > 0
              ? ExtraLinesData(horizontalLines: [
                  HorizontalLine(
                    y: baselineValue!,
                    color: Theme.of(context).colorScheme.outline,
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ])
              : null,
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= data.length) {
                    return const SizedBox.shrink();
                  }
                  if (!isWeekView && idx % 5 != 0 && idx != data.length - 1) {
                    return const SizedBox.shrink();
                  }
                  final label = isWeekView
                      ? dayFormat.format(data[idx].date)
                      : dateFormat.format(data[idx].date);
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(label, style: const TextStyle(fontSize: 10)),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 40),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: true, drawVerticalLine: false),
        ),
      ),
    );
  }
}
