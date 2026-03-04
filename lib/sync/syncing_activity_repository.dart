import '../models/activity_model.dart';
import '../repositories/activity_repository.dart';
import 'sync_engine.dart';
import 'sync_queue.dart';

/// Wraps a local ActivityRepository: reads delegate to local,
/// writes go to local then enqueue for sync.
class SyncingActivityRepository implements ActivityRepository {
  final ActivityRepository _local;
  final SyncQueue _queue;
  final SyncEngine _engine;

  SyncingActivityRepository(this._local, this._queue, this._engine);

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
    await _local.insertActivity(familyId, activity);
    await _queue.enqueue(
      collection: 'activities',
      documentId: activity.id,
      familyId: familyId,
    );
    _engine.notifyWrite();
  }

  @override
  Future<void> insertActivities(
      String familyId, List<ActivityModel> activities) async {
    await _local.insertActivities(familyId, activities);
    for (final activity in activities) {
      await _queue.enqueue(
        collection: 'activities',
        documentId: activity.id,
        familyId: familyId,
      );
    }
    _engine.notifyWrite();
  }

  @override
  Future<void> updateActivity(
      String familyId, ActivityModel activity) async {
    await _local.updateActivity(familyId, activity);
    await _queue.enqueue(
      collection: 'activities',
      documentId: activity.id,
      familyId: familyId,
    );
    _engine.notifyWrite();
  }

  @override
  Future<void> softDeleteActivity(
      String familyId, String activityId) async {
    await _local.softDeleteActivity(familyId, activityId);
    await _queue.enqueue(
      collection: 'activities',
      documentId: activityId,
      familyId: familyId,
    );
    _engine.notifyWrite();
  }
}
