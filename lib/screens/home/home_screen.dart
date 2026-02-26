import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/enums.dart';
import '../../providers/child_provider.dart';
import '../../providers/activity_provider.dart';
import '../../providers/invite_provider.dart';
import '../../providers/repository_provider.dart';
import '../../utils/activity_helpers.dart';
import '../../widgets/activity_tile.dart';
import '../home/setup_prompt.dart';
import '../home/invite_pending_prompt.dart';

/// When true, skip the invite prompt and show SetupPrompt directly.
final _skipInvitesProvider = StateProvider<bool>((ref) => false);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedChild = ref.watch(selectedChildProvider);
    final dailyActivities = ref.watch(dailyActivitiesProvider);
    final pendingInvites = ref.watch(pendingInvitesProvider);
    final skipInvites = ref.watch(_skipInvitesProvider);

    if (selectedChild == null) {
      // Wait for families to load before deciding what to show.
      // Without this, SetupPrompt flashes on page refresh while Firestore
      // is still loading, and the user could create duplicate families.
      final familiesState = ref.watch(userFamiliesProvider);
      if (familiesState.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }

      // If the user already has families, auto-selection will kick in
      // on the next frame — show a loading indicator while it settles.
      final families = familiesState.valueOrNull ?? [];
      if (families.isNotEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      // No families at all — check for pending invites or show SetupPrompt.
      final invites = pendingInvites.valueOrNull ?? [];
      if (invites.isNotEmpty && !skipInvites) {
        return InvitePendingPrompt(
          invites: invites,
          onCreateOwn: () {
            ref.read(_skipInvitesProvider.notifier).state = true;
          },
        );
      }
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
                (context, index) {
                  final activity = activities[index];
                  return ActivityTile(
                    activity: activity,
                    onDelete: () => _deleteActivity(context, ref, activity),
                  );
                },
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

void _deleteActivity(BuildContext context, WidgetRef ref, dynamic activity) {
  final familyId = ref.read(selectedFamilyIdProvider);
  if (familyId == null) return;

  final repo = ref.read(activityRepositoryProvider);
  final typeName = activity.type as String;
  final activityId = activity.id as String;
  bool undone = false;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Deleted $typeName'),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () => undone = true,
      ),
    ),
  ).closed.then((reason) {
    if (!undone) {
      repo.softDeleteActivity(familyId, activityId);
    }
  });
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
