import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/target_model.dart';
import 'target_repository.dart';

class FirebaseTargetRepository implements TargetRepository {
  final FirebaseFirestore _firestore;

  FirebaseTargetRepository(this._firestore);

  CollectionReference<Map<String, dynamic>> _targetsCol(String familyId) =>
      _firestore.collection('families').doc(familyId).collection('targets');

  @override
  Stream<List<TargetModel>> watchTargets(String familyId, String childId) {
    return _targetsCol(familyId)
        .where('childId', isEqualTo: childId)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => TargetModel.fromFirestore(doc)).toList());
  }

  @override
  Future<void> createTarget(String familyId, TargetModel target) async {
    await _targetsCol(familyId).doc(target.id).set(target.toFirestore());
  }

  @override
  Future<void> updateTarget(String familyId, TargetModel target) async {
    await _targetsCol(familyId).doc(target.id).set(target.toFirestore());
  }

  @override
  Future<void> deactivateTarget(String familyId, String targetId) async {
    await _targetsCol(familyId).doc(targetId).update({'isActive': false});
  }
}
