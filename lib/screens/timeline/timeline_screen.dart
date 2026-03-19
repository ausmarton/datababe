import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/enums.dart';
import '../../providers/activity_provider.dart';
import '../../providers/child_provider.dart';
import '../../providers/repository_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/target_provider.dart';
import '../../utils/activity_helpers.dart';
import '../../utils/date_range_helpers.dart';
import '../../widgets/activity_tile.dart';
import '../../widgets/data_error_widget.dart';
import '../../widgets/summary_card.dart';

class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedChild = ref.watch(selectedChildProvider);
    final filter = ref.watch(timelineFilterProvider);

    if (selectedChild == null) {
      return const Scaffold(
        body: Center(child: Text('Please add a child first')),
      );
    }

    final activitiesAsync = ref.watch(timelineActivitiesProvider);
    final summary = ref.watch(timelineSummaryProvider);
    final progress = ref.watch(targetProgressProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Timeline'),
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_add),
            tooltip: 'Bulk Add',
            onPressed: () => context.push('/bulk-add'),
          ),
          PopupMenuButton<ActivityType?>(
            icon: Badge(
              isLabelVisible: filter != null,
              child: const Icon(Icons.filter_list),
            ),
            onSelected: (value) {
              ref.read(timelineFilterProvider.notifier).state = value;
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('All activities'),
              ),
              const PopupMenuDivider(),
              ...ActivityType.values.map((type) => PopupMenuItem(
                    value: type,
                    child: Row(
                      children: [
                        Icon(activityIcon(type),
                            size: 20, color: activityColor(type)),
                        const SizedBox(width: 8),
                        Text(activityDisplayName(type)),
                      ],
                    ),
                  )),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          const _RangeSelector(),
          if (summary != null)
            SummaryCard(
              summary: summary,
              filter: filter,
              targetProgress: progress.isNotEmpty ? progress : null,
            ),
          Expanded(
            child: activitiesAsync.when(
              data: (activities) {
                // Apply client-side type filter
                final filtered = filter != null
                    ? activities
                        .where((a) => a.type == filter.name)
                        .toList()
                    : activities;

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_note,
                            size: 48,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant),
                        const SizedBox(height: 16),
                        Text(
                          'No activities in this period',
                          style:
                              Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try a different date range or log a new activity.',
                          style:
                              Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                // Group by date
                final grouped = <String, List<dynamic>>{};
                final dateFormat = DateFormat.yMMMd();
                for (final a in filtered) {
                  final key = dateFormat.format(a.startTime);
                  grouped.putIfAbsent(key, () => []).add(a);
                }

                final keys = grouped.keys.toList();

                return ListView.builder(
                  itemCount: keys.length,
                  itemBuilder: (context, index) {
                    final dateLabel = keys[index];
                    final items = grouped[dateLabel]!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Text(
                            dateLabel,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ),
                        ...items.map((a) => ActivityTile(
                              activity: a,
                              onDelete: () =>
                                  _deleteActivity(context, ref, a),
                              onCopy: () => context.push(
                                '/log/${a.type}?copyFrom=${a.id}',
                              ),
                            )),
                        const Divider(height: 1),
                      ],
                    );
                  },
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => DataErrorWidget(
                error: e,
                onRetry: () => ref.invalidate(timelineActivitiesProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _deleteActivity(
      BuildContext context, WidgetRef ref, dynamic activity) {
    final familyId = ref.read(selectedFamilyIdProvider);
    if (familyId == null) return;

    final repo = ref.read(activityRepositoryProvider);
    final typeName = activity.type as String;
    final activityId = activity.id as String;
    bool undone = false;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text('Deleted $typeName'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => undone = true,
        ),
      ),
    )
        .closed
        .then((reason) {
      if (!undone) {
        repo.softDeleteActivity(familyId, activityId);
      }
    });
  }
}

class _RangeSelector extends ConsumerWidget {
  const _RangeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(timelineWindowModeProvider);
    final anchor = ref.watch(timelineAnchorProvider);
    final sodHour = ref.watch(startOfDayHourProvider).valueOrNull ?? 0;
    final isCalendar = isCalendarMode(mode);

    // Determine granularity for the segmented button
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
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Row 1: Granularity pills
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
                ref.read(timelineWindowModeProvider.notifier).state =
                    newMode;
              },
            ),
            const SizedBox(height: 8),
            // Row 2: Calendar/Rolling toggle + navigation
            Row(
              children: [
                // Calendar/Rolling toggle
                ChoiceChip(
                  label: Text(isCalendar ? 'Calendar' : 'Rolling'),
                  selected: isCalendar,
                  onSelected: (_) {
                    TimeWindowMode newMode;
                    if (isCalendar) {
                      // Switch to rolling
                      newMode = switch (granularity) {
                        _Granularity.day => TimeWindowMode.last24h,
                        _Granularity.week => TimeWindowMode.last7Days,
                        _Granularity.month => TimeWindowMode.last30Days,
                      };
                    } else {
                      // Switch to calendar
                      newMode = switch (granularity) {
                        _Granularity.day => TimeWindowMode.calendarDay,
                        _Granularity.week => TimeWindowMode.calendarWeek,
                        _Granularity.month =>
                          TimeWindowMode.calendarMonth,
                      };
                    }
                    ref.read(timelineWindowModeProvider.notifier).state =
                        newMode;
                  },
                ),
                const Spacer(),
                // Navigation arrows (calendar mode only)
                if (isCalendar) ...[
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () {
                      ref.read(timelineAnchorProvider.notifier).state =
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
                            ref
                                .read(timelineAnchorProvider.notifier)
                                .state = nextAnchor(mode, anchor);
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

enum _Granularity { day, week, month }
