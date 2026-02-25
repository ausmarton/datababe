import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/enums.dart';
import '../../providers/activity_provider.dart';
import '../../providers/child_provider.dart';
import '../../utils/activity_helpers.dart';
import '../../widgets/activity_tile.dart';

/// Provider for the currently selected activity type filter.
final timelineFilterProvider = StateProvider<ActivityType?>((ref) => null);

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

    final activitiesAsync = filter != null
        ? ref.watch(activitiesByTypeProvider(filter.name))
        : ref.watch(activitiesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Timeline'),
        actions: [
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
      body: activitiesAsync.when(
        data: (activities) {
          if (activities.isEmpty) {
            return const Center(child: Text('No activities recorded yet'));
          }

          // Group by date.
          final grouped = <String, List<dynamic>>{};
          final dateFormat = DateFormat.yMMMd();
          for (final a in activities) {
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      dateLabel,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ),
                  ...items.map((a) => ActivityTile(activity: a)),
                  const Divider(height: 1),
                ],
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
