import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/activity_model.dart';
import '../models/enums.dart';
import '../utils/activity_helpers.dart';

/// Displays a single activity entry in the timeline/list.
class ActivityTile extends StatelessWidget {
  final ActivityModel activity;
  final VoidCallback? onDelete;
  final VoidCallback? onCopy;

  const ActivityTile({
    super.key,
    required this.activity,
    this.onDelete,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final type = parseActivityType(activity.type);
    final timeFormat = DateFormat.Hm();

    final tile = ListTile(
      onTap: () => context.push('/log/${activity.type}?id=${activity.id}'),
      onLongPress: onCopy != null
          ? () => _showContextMenu(context)
          : null,
      leading: CircleAvatar(
        backgroundColor: type != null
            ? activityColor(type).withValues(alpha: 0.2)
            : Colors.grey.withValues(alpha: 0.2),
        child: Icon(
          type != null ? activityIcon(type) : Icons.help_outline,
          color: type != null ? activityColor(type) : Colors.grey,
        ),
      ),
      title: Text(type != null ? activityDisplayName(type) : activity.type),
      subtitle: Text(_buildSubtitle()),
      trailing: Text(
        timeFormat.format(activity.startTime),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );

    if (onDelete == null) return tile;

    return Dismissible(
      key: ValueKey(activity.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Theme.of(context).colorScheme.error,
        child: Icon(Icons.delete, color: Theme.of(context).colorScheme.onError),
      ),
      confirmDismiss: (_) async {
        onDelete!();
        return false; // Don't remove the widget — the delete + undo is handled by the caller
      },
      child: tile,
    );
  }

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy as new'),
              onTap: () {
                Navigator.pop(ctx);
                onCopy!();
              },
            ),
          ],
        ),
      ),
    );
  }

  String _buildSubtitle() {
    final type = parseActivityType(activity.type);
    if (type == null) return '';

    switch (type) {
      case ActivityType.feedBottle:
        final parts = <String>[];
        if (activity.feedType != null) parts.add(activity.feedType!);
        if (activity.volumeMl != null) parts.add('${activity.volumeMl!.round()}ml');
        return parts.join(' - ');

      case ActivityType.feedBreast:
        final parts = <String>[];
        if (activity.rightBreastMinutes != null) {
          parts.add('R: ${activity.rightBreastMinutes}min');
        }
        if (activity.leftBreastMinutes != null) {
          parts.add('L: ${activity.leftBreastMinutes}min');
        }
        if (activity.durationMinutes != null) {
          parts.add('Total: ${formatDuration(activity.durationMinutes)}');
        }
        return parts.join(', ');

      case ActivityType.diaper:
        final parts = <String>[];
        if (activity.contents != null) parts.add(activity.contents!);
        if (activity.contentSize != null) parts.add(activity.contentSize!);
        if (activity.pooColour != null) parts.add(activity.pooColour!);
        return parts.join(', ');

      case ActivityType.meds:
        final parts = <String>[];
        if (activity.medicationName != null) parts.add(activity.medicationName!);
        if (activity.dose != null) parts.add(activity.dose!);
        return parts.join(' - ');

      case ActivityType.solids:
        final parts = <String>[];
        if (activity.foodDescription != null) parts.add(activity.foodDescription!);
        if (activity.ingredientNames != null &&
            activity.ingredientNames!.isNotEmpty) {
          parts.add('${activity.ingredientNames!.length} ingredients');
        }
        if (activity.allergenNames != null &&
            activity.allergenNames!.isNotEmpty) {
          parts.add('${activity.allergenNames!.length} allergens');
        }
        if (activity.reaction != null) parts.add(activity.reaction!);
        return parts.join(' - ');

      case ActivityType.growth:
        final parts = <String>[];
        if (activity.weightKg != null) parts.add('${activity.weightKg}kg');
        if (activity.lengthCm != null) parts.add('${activity.lengthCm}cm');
        if (activity.headCircumferenceCm != null) {
          parts.add('Head: ${activity.headCircumferenceCm}cm');
        }
        return parts.join(', ');

      case ActivityType.temperature:
        if (activity.tempCelsius != null) return '${activity.tempCelsius}°C';
        return '';

      case ActivityType.pump:
        final parts = <String>[];
        if (activity.volumeMl != null) parts.add('${activity.volumeMl!.round()}ml');
        if (activity.durationMinutes != null) {
          parts.add(formatDuration(activity.durationMinutes));
        }
        return parts.join(', ');

      case ActivityType.tummyTime:
      case ActivityType.indoorPlay:
      case ActivityType.outdoorPlay:
      case ActivityType.bath:
      case ActivityType.skinToSkin:
      case ActivityType.sleep:
        return formatDuration(activity.durationMinutes);

      case ActivityType.potty:
        final parts = <String>[];
        if (activity.contents != null) parts.add(activity.contents!);
        if (activity.contentSize != null) parts.add(activity.contentSize!);
        return parts.join(', ');
    }
  }
}
