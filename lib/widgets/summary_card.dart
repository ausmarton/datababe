import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../models/target_model.dart';
import '../utils/activity_aggregator.dart';
import '../utils/activity_helpers.dart';

/// Progress toward a target.
class TargetProgress {
  final TargetModel target;
  final double actual;
  final double fraction;

  const TargetProgress({
    required this.target,
    required this.actual,
    required this.fraction,
  });
}

/// Compact summary card showing aggregated stats for a time range.
class SummaryCard extends StatelessWidget {
  final ActivitySummary summary;
  final ActivityType? filter;
  final List<TargetProgress>? targetProgress;

  const SummaryCard({
    super.key,
    required this.summary,
    this.filter,
    this.targetProgress,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (filter == null)
              _buildOverview(context)
            else
              _buildFiltered(context),
            if (targetProgress != null && targetProgress!.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              ..._buildTargetBars(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOverview(BuildContext context) {
    final chips = <Widget>[];

    chips.add(_statChip(
        context, Icons.format_list_numbered, '${summary.totalCount} total'));

    if (summary.bottleFeedCount > 0) {
      chips.add(_typeChip(
          context, ActivityType.feedBottle, '${summary.bottleFeedCount}'));
    }
    if (summary.breastFeedCount > 0) {
      chips.add(_typeChip(
          context, ActivityType.feedBreast, '${summary.breastFeedCount}'));
    }
    if (summary.diaperCount > 0) {
      chips.add(
          _typeChip(context, ActivityType.diaper, '${summary.diaperCount}'));
    }
    if (summary.solidsCount > 0) {
      chips.add(
          _typeChip(context, ActivityType.solids, '${summary.solidsCount}'));
    }
    if (summary.medsBreakdown.isNotEmpty) {
      final total = summary.medsBreakdown.values.fold(0, (a, b) => a + b);
      chips.add(_typeChip(context, ActivityType.meds, '$total'));
    }
    if (summary.pumpCount > 0) {
      chips
          .add(_typeChip(context, ActivityType.pump, '${summary.pumpCount}'));
    }
    if (summary.pottyCount > 0) {
      chips.add(
          _typeChip(context, ActivityType.potty, '${summary.pottyCount}'));
    }

    for (final entry in summary.durationCounts.entries) {
      if (entry.key == ActivityType.pump.name) continue;
      final type = parseActivityType(entry.key);
      if (type != null) {
        chips.add(_typeChip(context, type, '${entry.value}'));
      }
    }

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: chips,
    );
  }

  Widget _buildFiltered(BuildContext context) {
    final children = <Widget>[];

    switch (filter!) {
      case ActivityType.feedBottle:
        children.add(Text(
          '${summary.bottleFeedCount} feeds — ${summary.bottleFeedTotalMl.round()}ml total',
          style: Theme.of(context).textTheme.bodyMedium,
        ));
        if (summary.bottleFeedCount > 0) {
          children.add(Text(
            'Avg: ${(summary.bottleFeedTotalMl / summary.bottleFeedCount).round()}ml',
            style: Theme.of(context).textTheme.bodySmall,
          ));
        }

      case ActivityType.feedBreast:
        children.add(Text(
          '${summary.breastFeedCount} feeds — ${formatDuration(summary.breastFeedTotalMinutes)} total',
          style: Theme.of(context).textTheme.bodyMedium,
        ));

      case ActivityType.diaper:
        children.add(Text(
          '${summary.diaperCount} diapers',
          style: Theme.of(context).textTheme.bodyMedium,
        ));
        if (summary.diaperBreakdown.isNotEmpty) {
          children.add(Text(
            summary.diaperBreakdown.entries
                .map((e) => '${e.key}: ${e.value}')
                .join(', '),
            style: Theme.of(context).textTheme.bodySmall,
          ));
        }

      case ActivityType.solids:
        children.add(Text(
          '${summary.solidsCount} meals — ${summary.uniqueFoods.length} unique foods',
          style: Theme.of(context).textTheme.bodyMedium,
        ));
        if (summary.uniqueFoods.isNotEmpty) {
          children.add(Text(
            summary.uniqueFoods.join(', '),
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ));
        }

      case ActivityType.meds:
        for (final entry in summary.medsBreakdown.entries) {
          children.add(Text(
            '${entry.key}: ${entry.value}x',
            style: Theme.of(context).textTheme.bodyMedium,
          ));
        }

      case ActivityType.growth:
        if (summary.latestWeightKg != null) {
          children.add(Text('Weight: ${summary.latestWeightKg}kg'));
        }
        if (summary.latestLengthCm != null) {
          children.add(Text('Length: ${summary.latestLengthCm}cm'));
        }
        if (summary.latestHeadCm != null) {
          children.add(Text('Head: ${summary.latestHeadCm}cm'));
        }

      case ActivityType.temperature:
        if (summary.latestTempC != null) {
          children.add(Text('Latest: ${summary.latestTempC}°C'));
        }
        if (summary.minTempC != null && summary.maxTempC != null) {
          children.add(Text(
            'Range: ${summary.minTempC}°C – ${summary.maxTempC}°C',
            style: Theme.of(context).textTheme.bodySmall,
          ));
        }

      case ActivityType.pump:
        children.add(Text(
          '${summary.pumpCount} sessions — ${summary.pumpTotalMl.round()}ml total',
          style: Theme.of(context).textTheme.bodyMedium,
        ));

      case ActivityType.potty:
        children.add(Text(
          '${summary.pottyCount} potty',
          style: Theme.of(context).textTheme.bodyMedium,
        ));
        if (summary.pottyBreakdown.isNotEmpty) {
          children.add(Text(
            summary.pottyBreakdown.entries
                .map((e) => '${e.key}: ${e.value}')
                .join(', '),
            style: Theme.of(context).textTheme.bodySmall,
          ));
        }

      default:
        final mins = summary.durationTotals[filter!.name];
        final count = summary.durationCounts[filter!.name] ?? 0;
        children.add(Text(
          '$count sessions${mins != null ? ' — ${formatDuration(mins)} total' : ''}',
          style: Theme.of(context).textTheme.bodyMedium,
        ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  List<Widget> _buildTargetBars(BuildContext context) {
    return targetProgress!.map((tp) {
      final color = tp.fraction >= 1.0
          ? Colors.green
          : tp.fraction >= 0.5
              ? Colors.amber
              : Colors.red;

      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_metricLabel(tp.target.metric)}: ${tp.actual.round()} of ${tp.target.targetValue.round()}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 2),
            LinearProgressIndicator(
              value: tp.fraction.clamp(0.0, 1.0),
              color: color,
              backgroundColor: color.withValues(alpha: 0.2),
            ),
          ],
        ),
      );
    }).toList();
  }

  String _metricLabel(String metric) {
    return switch (metric) {
      'totalVolumeMl' => 'Volume (ml)',
      'count' => 'Count',
      'uniqueFoods' => 'Unique foods',
      'totalDurationMinutes' => 'Duration (min)',
      _ => metric,
    };
  }

  Widget _statChip(BuildContext context, IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label, style: Theme.of(context).textTheme.bodySmall),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _typeChip(BuildContext context, ActivityType type, String count) {
    return Chip(
      avatar: Icon(activityIcon(type), size: 16, color: activityColor(type)),
      label: Text(count, style: Theme.of(context).textTheme.bodySmall),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
