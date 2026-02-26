import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/family_model.dart';
import '../models/child_model.dart';
import '../models/carer_model.dart';
import 'family_repository.dart';

class FirebaseFamilyRepository implements FamilyRepository {
  final FirebaseFirestore _firestore;

  FirebaseFamilyRepository(this._firestore);

  @override
  Stream<List<FamilyModel>> watchFamilies(String uid) {
    return _firestore
        .collection('families')
        .where('memberUids', arrayContains: uid)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => FamilyModel.fromFirestore(doc))
            .toList());
  }

  @override
  Stream<List<ChildModel>> watchChildren(String familyId) {
    return _firestore
        .collection('families')
        .doc(familyId)
        .collection('children')
        .orderBy('createdAt')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ChildModel.fromFirestore(doc))
            .toList());
  }

  @override
  Future<FamilyModel> createFamily(FamilyModel family) async {
    await _firestore
        .collection('families')
        .doc(family.id)
        .set(family.toFirestore());
    return family;
  }

  @override
  Future<ChildModel> createChild(String familyId, ChildModel child) async {
    await _firestore
        .collection('families')
        .doc(familyId)
        .collection('children')
        .doc(child.id)
        .set(child.toFirestore());
    return child;
  }

  @override
  Future<CarerModel> createCarer(String familyId, CarerModel carer) async {
    await _firestore
        .collection('families')
        .doc(familyId)
        .collection('carers')
        .doc(carer.id)
        .set(carer.toFirestore());
    return carer;
  }

  @override
  Future<void> createFamilyWithChild({
    required FamilyModel family,
    required ChildModel child,
    required CarerModel carer,
  }) async {
    final batch = _firestore.batch();

    batch.set(
      _firestore.collection('families').doc(family.id),
      family.toFirestore(),
    );

    batch.set(
      _firestore
          .collection('families')
          .doc(family.id)
          .collection('children')
          .doc(child.id),
      child.toFirestore(),
    );

    batch.set(
      _firestore
          .collection('families')
          .doc(family.id)
          .collection('carers')
          .doc(carer.id),
      carer.toFirestore(),
    );

    // Update user document with family reference
    if (family.createdBy.isNotEmpty) {
      batch.set(
        _firestore.collection('users').doc(family.createdBy),
        {
          'familyIds': FieldValue.arrayUnion([family.id]),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }
}
