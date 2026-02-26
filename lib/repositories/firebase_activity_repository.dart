import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/activity_model.dart';
import 'activity_repository.dart';

class FirebaseActivityRepository implements ActivityRepository {
  final FirebaseFirestore _firestore;

  FirebaseActivityRepository(this._firestore);

  CollectionReference<Map<String, dynamic>> _activitiesRef(String familyId) =>
      _firestore
          .collection('families')
          .doc(familyId)
          .collection('activities');

  @override
  Stream<List<ActivityModel>> watchActivities(
      String familyId, String childId) {
    return _activitiesRef(familyId)
        .where('childId', isEqualTo: childId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('startTime', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ActivityModel.fromFirestore(doc))
            .toList());
  }

  @override
  Stream<List<ActivityModel>> watchActivitiesByType(
      String familyId, String childId, String type) {
    return _activitiesRef(familyId)
        .where('childId', isEqualTo: childId)
        .where('type', isEqualTo: type)
        .where('isDeleted', isEqualTo: false)
        .orderBy('startTime', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ActivityModel.fromFirestore(doc))
            .toList());
  }

  @override
  Stream<List<ActivityModel>> watchActivitiesInRange(
      String familyId, String childId, DateTime start, DateTime end) {
    return _activitiesRef(familyId)
        .where('childId', isEqualTo: childId)
        .where('isDeleted', isEqualTo: false)
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('startTime', isLessThan: Timestamp.fromDate(end))
        .orderBy('startTime', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ActivityModel.fromFirestore(doc))
            .toList());
  }

  @override
  Future<void> insertActivity(String familyId, ActivityModel activity) {
    return _activitiesRef(familyId)
        .doc(activity.id)
        .set(activity.toFirestore());
  }

  @override
  Future<void> insertActivities(
      String familyId, List<ActivityModel> activities) async {
    // Firestore batch limit is 500
    const batchSize = 500;
    for (var i = 0; i < activities.length; i += batchSize) {
      final batch = _firestore.batch();
      final chunk = activities.skip(i).take(batchSize);
      for (final activity in chunk) {
        batch.set(
          _activitiesRef(familyId).doc(activity.id),
          activity.toFirestore(),
        );
      }
      await batch.commit();
    }
  }

  @override
  Future<void> updateActivity(String familyId, ActivityModel activity) {
    return _activitiesRef(familyId)
        .doc(activity.id)
        .set(activity.toFirestore());
  }

  @override
  Future<void> softDeleteActivity(String familyId, String activityId) {
    return _activitiesRef(familyId)
        .doc(activityId)
        .update({'isDeleted': true, 'modifiedAt': Timestamp.now()});
  }
}
