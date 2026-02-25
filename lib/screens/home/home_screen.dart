import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/enums.dart';
import '../../providers/child_provider.dart';
import '../../providers/activity_provider.dart';
import '../../utils/activity_helpers.dart';
import '../../widgets/activity_tile.dart';
import '../home/setup_prompt.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedChild = ref.watch(selectedChildProvider);
    final dailyActivities = ref.watch(dailyActivitiesProvider);

    if (selectedChild == null) {
      return const SetupPrompt();
    }

    return CustomScrollView(
      slivers: [
        SliverAppBar.large(
          title: Text(selectedChild.name),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: _QuickLogGrid(),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Today',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        dailyActivities.when(
          data: (activities) {
            if (activities.isEmpty) {
              return const SliverFillRemaining(
                child: Center(child: Text('No activities logged today')),
              );
            }
            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => ActivityTile(activity: activities[index]),
                childCount: activities.length,
              ),
            );
          },
          loading: () => const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => SliverFillRemaining(
            child: Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }
}

class _QuickLogGrid extends StatelessWidget {
  static const _quickLogTypes = [
    ActivityType.feedBottle,
    ActivityType.feedBreast,
    ActivityType.diaper,
    ActivityType.meds,
    ActivityType.solids,
    ActivityType.growth,
    ActivityType.tummyTime,
    ActivityType.pump,
    ActivityType.temperature,
    ActivityType.bath,
    ActivityType.indoorPlay,
    ActivityType.outdoorPlay,
    ActivityType.skinToSkin,
    ActivityType.potty,
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _quickLogTypes.map((type) {
        return ActionChip(
          avatar: Icon(activityIcon(type), size: 18),
          label: Text(activityDisplayName(type)),
          onPressed: () => context.push('/log/${type.name}'),
        );
      }).toList(),
    );
  }
}
