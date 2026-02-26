import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/activity_model.dart';
import 'repository_provider.dart';
import 'child_provider.dart';

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

/// Activities for the selected day.
final dailyActivitiesProvider = StreamProvider<List<ActivityModel>>((ref) {
  final childId = ref.watch(selectedChildIdProvider);
  final familyId = ref.watch(selectedFamilyIdProvider);
  final date = ref.watch(selectedDateProvider);
  final repo = ref.watch(activityRepositoryProvider);
  if (childId == null || familyId == null) return Stream.value([]);
  final start = DateTime(date.year, date.month, date.day);
  final end = start.add(const Duration(days: 1));
  return repo.watchActivitiesInRange(familyId, childId, start, end);
});
