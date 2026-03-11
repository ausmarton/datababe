import 'package:sembast/sembast.dart';

import '../models/activity_model.dart';
import '../repositories/activity_repository.dart';
import '../repositories/local_activity_repository.dart';
import 'sync_engine_interface.dart';
import 'sync_queue.dart';

/// Wraps a local ActivityRepository: reads delegate to local,
/// writes go to local then enqueue for sync — atomically in one transaction.
class SyncingActivityRepository implements ActivityRepository {
  final LocalActivityRepository _local;
  final SyncQueue _queue;
  final SyncEngineInterface _engine;
  final Database _db;

  SyncingActivityRepository(this._local, this._queue, this._engine, this._db);

  @override
  Stream<List<ActivityModel>> watchActivities(
          String familyId, String childId) =>
      _local.watchActivities(familyId, childId);

  @override
  Stream<List<ActivityModel>> watchActivitiesByType(
          String familyId, String childId, String type) =>
      _local.watchActivitiesByType(familyId, childId, type);

  @override
  Stream<List<ActivityModel>> watchActivitiesInRange(
          String familyId, String childId, DateTime start, DateTime end) =>
      _local.watchActivitiesInRange(familyId, childId, start, end);

  @override
  Future<ActivityModel?> getActivity(
          String familyId, String activityId) =>
      _local.getActivity(familyId, activityId);

  @override
  Future<void> insertActivity(
      String familyId, ActivityModel activity) async {
    await _db.transaction((txn) async {
      await _local.insertActivity(familyId, activity, txn: txn);
      await _queue.enqueueTxn(txn,
        collection: 'activities',
        documentId: activity.id,
        familyId: familyId,
        isNew: true,
      );
    });
    _engine.notifyWrite();
  }

  @override
  Future<void> insertActivities(
      String familyId, List<ActivityModel> activities) async {
    await _db.transaction((txn) async {
      await _local.insertActivities(familyId, activities, txn: txn);
      for (final activity in activities) {
        await _queue.enqueueTxn(txn,
          collection: 'activities',
          documentId: activity.id,
          familyId: familyId,
          isNew: true,
        );
      }
    });
    _engine.notifyWrite();
  }

  @override
  Future<void> updateActivity(
      String familyId, ActivityModel activity) async {
    await _db.transaction((txn) async {
      await _local.updateActivity(familyId, activity, txn: txn);
      await _queue.enqueueTxn(txn,
        collection: 'activities',
        documentId: activity.id,
        familyId: familyId,
      );
    });
    _engine.notifyWrite();
  }

  @override
  Future<List<ActivityModel>> findByTimeRange(
          String familyId, String childId, DateTime start, DateTime end) =>
      _local.findByTimeRange(familyId, childId, start, end);

  @override
  Future<void> softDeleteActivity(
      String familyId, String activityId) async {
    await _db.transaction((txn) async {
      await _local.softDeleteActivity(familyId, activityId, txn: txn);
      await _queue.enqueueTxn(txn,
        collection: 'activities',
        documentId: activityId,
        familyId: familyId,
      );
    });
    _engine.notifyWrite();
  }
}
