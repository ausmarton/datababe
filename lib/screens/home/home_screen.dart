import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/enums.dart';
import '../../providers/child_provider.dart';
import '../../providers/activity_provider.dart';
import '../../providers/initial_sync_provider.dart';
import '../../providers/insights_provider.dart';
import '../../providers/invite_provider.dart';
import '../../providers/repository_provider.dart';
import '../../utils/activity_helpers.dart';
import '../../widgets/activity_tile.dart';
import '../../widgets/progress_ring.dart';
import '../home/setup_prompt.dart';
import '../home/invite_pending_prompt.dart';

/// When true, skip the invite prompt and show SetupPrompt directly.
final _skipInvitesProvider = StateProvider<bool>((ref) => false);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initialSync = ref.watch(initialSyncProvider);

    // Show loading while initial sync is in progress.
    if (initialSync.isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Syncing your data...'),
          ],
        ),
      );
    }

    // Show sync error if it failed (but still let the user proceed).
    final syncResult = initialSync.valueOrNull;
    if (syncResult?.error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sync error: ${syncResult!.error}'),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      });
    }

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
        SliverToBoxAdapter(
          child: _StatusRings(),
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
                    onCopy: () => context.push(
                      '/log/${activity.type}?copyFrom=${activity.id}',
                    ),
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
  ).closed.then((reason) async {
    if (!undone) {
      try {
        await repo.softDeleteActivity(familyId, activityId);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Delete failed: $e')),
          );
        }
      }
    }
  });
}

class _StatusRings extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(todayProgressProvider);
    if (progress.isEmpty) return const SizedBox.shrink();

    final metrics = progress.take(3).toList();
    final remaining = progress.length - metrics.length;

    return GestureDetector(
      onTap: () => GoRouter.of(context).go('/insights'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final m in metrics)
                  ProgressRing(
                    fraction: m.fraction,
                    icon: m.icon,
                    color: m.color,
                    actual: m.unit.isNotEmpty
                        ? '${m.actual.round()}${m.unit}'
                        : '${m.actual.round()}',
                    target: m.unit.isNotEmpty
                        ? '${m.target.round()}${m.unit}'
                        : '${m.target.round()}',
                    label: m.periodLabel != null
                        ? '${m.label} (${m.periodLabel})'
                        : m.label,
                    isInferred: !m.isExplicit,
                  ),
                if (remaining > 0)
                  SizedBox(
                    width: 40,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 16,
                          child: Text('+$remaining'),
                        ),
                        const SizedBox(height: 4),
                        Text('more',
                            style: Theme.of(context).textTheme.labelSmall),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
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
      children: [
        ..._quickLogTypes.map((type) {
          return ActionChip(
            avatar: Icon(activityIcon(type), size: 18),
            label: Text(activityDisplayName(type)),
            onPressed: () => context.push('/log/${type.name}'),
          );
        }),
        ActionChip(
          avatar: const Icon(Icons.playlist_add, size: 18),
          label: const Text('Bulk Add'),
          onPressed: () => context.push('/bulk-add'),
        ),
      ],
    );
  }
}
