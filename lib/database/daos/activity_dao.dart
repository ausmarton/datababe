import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/activities.dart';

part 'activity_dao.g.dart';

@DriftAccessor(tables: [Activities])
class ActivityDao extends DatabaseAccessor<AppDatabase>
    with _$ActivityDaoMixin {
  ActivityDao(super.db);

  /// Watch all non-deleted activities for a child, newest first.
  Stream<List<Activity>> watchActivities(String childId) {
    return (select(activities)
          ..where((a) => a.childId.equals(childId) & a.isDeleted.equals(false))
          ..orderBy([(a) => OrderingTerm.desc(a.startTime)]))
        .watch();
  }

  /// Watch activities for a child filtered by type.
  Stream<List<Activity>> watchActivitiesByType(
    String childId,
    String type,
  ) {
    return (select(activities)
          ..where((a) =>
              a.childId.equals(childId) &
              a.type.equals(type) &
              a.isDeleted.equals(false))
          ..orderBy([(a) => OrderingTerm.desc(a.startTime)]))
        .watch();
  }

  /// Watch activities for a child within a date range.
  Stream<List<Activity>> watchActivitiesInRange(
    String childId,
    DateTime start,
    DateTime end,
  ) {
    return (select(activities)
          ..where((a) =>
              a.childId.equals(childId) &
              a.isDeleted.equals(false) &
              a.startTime.isBiggerOrEqualValue(start) &
              a.startTime.isSmallerThanValue(end))
          ..orderBy([(a) => OrderingTerm.desc(a.startTime)]))
        .watch();
  }

  /// Get a single activity by ID.
  Future<Activity?> getActivity(String id) {
    return (select(activities)..where((a) => a.id.equals(id)))
        .getSingleOrNull();
  }

  /// Insert a new activity.
  Future<void> insertActivity(ActivitiesCompanion entry) {
    return into(activities).insert(entry);
  }

  /// Update an existing activity.
  Future<void> updateActivity(ActivitiesCompanion entry) {
    return (update(activities)..where((a) => a.id.equals(entry.id.value)))
        .write(entry);
  }

  /// Soft-delete an activity.
  Future<void> softDeleteActivity(String id) {
    return (update(activities)..where((a) => a.id.equals(id))).write(
      ActivitiesCompanion(
        isDeleted: const Value(true),
        modifiedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Insert many activities (for CSV import).
  Future<void> insertActivities(List<ActivitiesCompanion> entries) {
    return batch((batch) {
      batch.insertAll(activities, entries);
    });
  }

  /// Get all activities for a child on a given day.
  Future<List<Activity>> getActivitiesForDay(
    String childId,
    DateTime day,
  ) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return (select(activities)
          ..where((a) =>
              a.childId.equals(childId) &
              a.isDeleted.equals(false) &
              a.startTime.isBiggerOrEqualValue(start) &
              a.startTime.isSmallerThanValue(end))
          ..orderBy([(a) => OrderingTerm.desc(a.startTime)]))
        .get();
  }
}
