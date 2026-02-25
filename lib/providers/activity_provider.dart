import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import 'database_provider.dart';
import 'child_provider.dart';

/// All activities for the selected child, newest first.
final activitiesProvider = StreamProvider<List<Activity>>((ref) {
  final childId = ref.watch(selectedChildIdProvider);
  final dao = ref.watch(activityDaoProvider);
  if (childId == null) return Stream.value([]);
  return dao.watchActivities(childId);
});

/// Activities filtered by type for the selected child.
final activitiesByTypeProvider =
    StreamProvider.family<List<Activity>, String>((ref, type) {
  final childId = ref.watch(selectedChildIdProvider);
  final dao = ref.watch(activityDaoProvider);
  if (childId == null) return Stream.value([]);
  return dao.watchActivitiesByType(childId, type);
});

/// Selected date for daily views.
final selectedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// Activities for the selected day.
final dailyActivitiesProvider = StreamProvider<List<Activity>>((ref) {
  final childId = ref.watch(selectedChildIdProvider);
  final date = ref.watch(selectedDateProvider);
  final dao = ref.watch(activityDaoProvider);
  if (childId == null) return Stream.value([]);
  final start = DateTime(date.year, date.month, date.day);
  final end = start.add(const Duration(days: 1));
  return dao.watchActivitiesInRange(childId, start, end);
});
