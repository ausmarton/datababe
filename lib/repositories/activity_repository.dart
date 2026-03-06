import '../models/activity_model.dart';

abstract class ActivityRepository {
  Stream<List<ActivityModel>> watchActivities(
      String familyId, String childId);

  Stream<List<ActivityModel>> watchActivitiesByType(
      String familyId, String childId, String type);

  Stream<List<ActivityModel>> watchActivitiesInRange(
      String familyId, String childId, DateTime start, DateTime end);

  Future<ActivityModel?> getActivity(String familyId, String activityId);

  Future<void> insertActivity(String familyId, ActivityModel activity);

  Future<void> insertActivities(
      String familyId, List<ActivityModel> activities);

  Future<void> updateActivity(String familyId, ActivityModel activity);

  Future<void> softDeleteActivity(String familyId, String activityId);

  Future<List<ActivityModel>> findByTimeRange(
      String familyId, String childId, DateTime start, DateTime end);
}
