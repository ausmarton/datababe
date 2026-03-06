import 'package:sembast/sembast.dart';

import '../local/store_refs.dart';
import '../models/activity_model.dart';
import 'activity_repository.dart';

class LocalActivityRepository implements ActivityRepository {
  final Database _db;

  LocalActivityRepository(this._db);

  StoreRef<String, Map<String, dynamic>> get _store => StoreRefs.activities;

  @override
  Stream<List<ActivityModel>> watchActivities(
      String familyId, String childId) {
    final finder = Finder(
      filter: Filter.and([
        Filter.equals('familyId', familyId),
        Filter.equals('childId', childId),
        Filter.equals('isDeleted', false),
      ]),
      sortOrders: [SortOrder('startTime', false)],
    );
    return _store.query(finder: finder).onSnapshots(_db).map(
          (snapshots) => snapshots
              .map((s) => ActivityModel.fromMap(s.key, s.value))
              .toList(),
        );
  }

  @override
  Stream<List<ActivityModel>> watchActivitiesByType(
      String familyId, String childId, String type) {
    final finder = Finder(
      filter: Filter.and([
        Filter.equals('familyId', familyId),
        Filter.equals('childId', childId),
        Filter.equals('type', type),
        Filter.equals('isDeleted', false),
      ]),
      sortOrders: [SortOrder('startTime', false)],
    );
    return _store.query(finder: finder).onSnapshots(_db).map(
          (snapshots) => snapshots
              .map((s) => ActivityModel.fromMap(s.key, s.value))
              .toList(),
        );
  }

  @override
  Stream<List<ActivityModel>> watchActivitiesInRange(
      String familyId, String childId, DateTime start, DateTime end) {
    final finder = Finder(
      filter: Filter.and([
        Filter.equals('familyId', familyId),
        Filter.equals('childId', childId),
        Filter.equals('isDeleted', false),
        Filter.greaterThanOrEquals('startTime', start.toIso8601String()),
        Filter.lessThan('startTime', end.toIso8601String()),
      ]),
      sortOrders: [SortOrder('startTime', false)],
    );
    return _store.query(finder: finder).onSnapshots(_db).map(
          (snapshots) => snapshots
              .map((s) => ActivityModel.fromMap(s.key, s.value))
              .toList(),
        );
  }

  @override
  Future<ActivityModel?> getActivity(
      String familyId, String activityId) async {
    final record = await _store.record(activityId).get(_db);
    if (record == null) return null;
    return ActivityModel.fromMap(activityId, record);
  }

  @override
  Future<void> insertActivity(
      String familyId, ActivityModel activity) async {
    final map = activity.toMap();
    map['familyId'] = familyId;
    await _store.record(activity.id).put(_db, map);
  }

  @override
  Future<void> insertActivities(
      String familyId, List<ActivityModel> activities) async {
    await _db.transaction((txn) async {
      for (final activity in activities) {
        final map = activity.toMap();
        map['familyId'] = familyId;
        await _store.record(activity.id).put(txn, map);
      }
    });
  }

  @override
  Future<void> updateActivity(
      String familyId, ActivityModel activity) async {
    final map = activity.toMap();
    map['familyId'] = familyId;
    await _store.record(activity.id).put(_db, map);
  }

  @override
  Future<List<ActivityModel>> findByTimeRange(
      String familyId, String childId, DateTime start, DateTime end) async {
    final finder = Finder(
      filter: Filter.and([
        Filter.equals('familyId', familyId),
        Filter.equals('childId', childId),
        Filter.greaterThanOrEquals('startTime', start.toIso8601String()),
        Filter.lessThanOrEquals('startTime', end.toIso8601String()),
      ]),
    );
    final records = await _store.find(_db, finder: finder);
    return records
        .map((r) => ActivityModel.fromMap(r.key, r.value))
        .toList();
  }

  @override
  Future<void> softDeleteActivity(
      String familyId, String activityId) async {
    final record = await _store.record(activityId).get(_db);
    if (record != null) {
      final updated = Map<String, dynamic>.from(record);
      updated['isDeleted'] = true;
      updated['modifiedAt'] = DateTime.now().toIso8601String();
      await _store.record(activityId).put(_db, updated);
    }
  }
}
