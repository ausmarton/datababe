import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/activity_model.dart';
import '../models/enums.dart';
import '../utils/activity_aggregator.dart';
import '../utils/date_range_helpers.dart';
import 'repository_provider.dart';
import 'child_provider.dart';
import 'settings_provider.dart';

/// All activities for the selected child, newest first.
final activitiesProvider = StreamProvider<List<ActivityModel>>((ref) {
  final childId = ref.watch(selectedChildIdProvider);
  final familyId = ref.watch(selectedFamilyIdProvider);
  final repo = ref.watch(activityRepositoryProvider);
  if (childId == null || familyId == null) return Stream.value([]);
  return repo.watchActivities(familyId, childId);
});

/// Activities filtered by type for the selected child.
final activitiesByTypeProvider =
    StreamProvider.family<List<ActivityModel>, String>((ref, type) {
  final childId = ref.watch(selectedChildIdProvider);
  final familyId = ref.watch(selectedFamilyIdProvider);
  final repo = ref.watch(activityRepositoryProvider);
  if (childId == null || familyId == null) return Stream.value([]);
  return repo.watchActivitiesByType(familyId, childId, type);
});

/// Selected date for daily views.
final selectedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// Activities for the selected day, respecting start-of-day preference.
final dailyActivitiesProvider = StreamProvider<List<ActivityModel>>((ref) {
  final childId = ref.watch(selectedChildIdProvider);
  final familyId = ref.watch(selectedFamilyIdProvider);
  final date = ref.watch(selectedDateProvider);
  final repo = ref.watch(activityRepositoryProvider);
  final sodHour = ref.watch(startOfDayHourProvider).valueOrNull ?? 0;
  if (childId == null || familyId == null) return Stream.value([]);
  final start = DateTime(date.year, date.month, date.day, sodHour);
  final end = start.add(const Duration(days: 1));
  return repo.watchActivitiesInRange(familyId, childId, start, end);
});

// --- Timeline providers ---

/// Selected time window mode for the timeline.
final timelineWindowModeProvider =
    StateProvider<TimeWindowMode>((ref) => TimeWindowMode.calendarDay);

/// Anchor date for the timeline navigation.
final timelineAnchorProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// Activity type filter for the timeline.
final timelineFilterProvider = StateProvider<ActivityType?>((ref) => null);

/// Activities within the selected time window.
final timelineActivitiesProvider =
    StreamProvider<List<ActivityModel>>((ref) {
  final childId = ref.watch(selectedChildIdProvider);
  final familyId = ref.watch(selectedFamilyIdProvider);
  final mode = ref.watch(timelineWindowModeProvider);
  final anchor = ref.watch(timelineAnchorProvider);
  final repo = ref.watch(activityRepositoryProvider);
  final sodHour = ref.watch(startOfDayHourProvider).valueOrNull ?? 0;
  if (childId == null || familyId == null) return Stream.value([]);
  final (start, end) = computeRange(mode, anchor, startOfDayHour: sodHour);
  return repo.watchActivitiesInRange(familyId, childId, start, end);
});

/// Aggregated summary from the timeline activities, with filter applied.
final timelineSummaryProvider = Provider<ActivitySummary?>((ref) {
  final activitiesAsync = ref.watch(timelineActivitiesProvider);
  final filter = ref.watch(timelineFilterProvider);
  final activities = activitiesAsync.valueOrNull;
  if (activities == null || activities.isEmpty) return null;

  final filtered = filter != null
      ? activities.where((a) => a.type == filter.name).toList()
      : activities;

  if (filtered.isEmpty) return null;
  return ActivityAggregator.compute(filtered);
});
