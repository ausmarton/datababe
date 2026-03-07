import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/family_model.dart';
import '../models/child_model.dart';
import '../models/carer_model.dart';
import 'cascaded_change.dart';
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
    // Step 1: Create the family document and update the user profile.
    // This must happen first because subcollection security rules use get()
    // to verify membership in the parent family document.
    final setupBatch = _firestore.batch();

    setupBatch.set(
      _firestore.collection('families').doc(family.id),
      family.toFirestore(),
    );

    if (family.createdBy.isNotEmpty) {
      setupBatch.set(
        _firestore.collection('users').doc(family.createdBy),
        {
          'familyIds': FieldValue.arrayUnion([family.id]),
        },
        SetOptions(merge: true),
      );
    }

    await setupBatch.commit();

    // Step 2: Create child and carer in subcollections (family now exists).
    final membersBatch = _firestore.batch();

    membersBatch.set(
      _firestore
          .collection('families')
          .doc(family.id)
          .collection('children')
          .doc(child.id),
      child.toFirestore(),
    );

    membersBatch.set(
      _firestore
          .collection('families')
          .doc(family.id)
          .collection('carers')
          .doc(carer.id),
      carer.toFirestore(),
    );

    await membersBatch.commit();
  }

  // --- Members ---

  @override
  Stream<List<CarerModel>> watchCarers(String familyId) {
    return _firestore
        .collection('families')
        .doc(familyId)
        .collection('carers')
        .orderBy('createdAt')
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => CarerModel.fromFirestore(doc)).toList());
  }

  @override
  Future<void> updateCarerRole(
      String familyId, String carerId, String newRole) async {
    await _firestore
        .collection('families')
        .doc(familyId)
        .collection('carers')
        .doc(carerId)
        .update({'role': newRole});
  }

  @override
  Future<void> removeMember({
    required String familyId,
    required String memberUid,
    required String carerId,
  }) async {
    final batch = _firestore.batch();

    batch.update(
      _firestore.collection('families').doc(familyId),
      {
        'memberUids': FieldValue.arrayRemove([memberUid]),
      },
    );

    batch.delete(
      _firestore
          .collection('families')
          .doc(familyId)
          .collection('carers')
          .doc(carerId),
    );

    await batch.commit();
  }

  // --- Allergen Categories ---

  @override
  Future<void> updateAllergenCategories(
      String familyId, List<String> categories) async {
    await _firestore
        .collection('families')
        .doc(familyId)
        .update({'allergenCategories': categories});
  }

  @override
  Future<List<CascadedChange>> renameAllergenCategory(
      String familyId, String oldName, String newName) async {
    // Cascade handled locally; Firestore gets individual doc updates via sync.
    final doc =
        await _firestore.collection('families').doc(familyId).get();
    if (doc.exists) {
      final categories = List<String>.from(
          (doc.data()!['allergenCategories'] as List<dynamic>?) ?? []);
      final idx = categories.indexOf(oldName);
      if (idx >= 0) categories[idx] = newName;
      await _firestore
          .collection('families')
          .doc(familyId)
          .update({'allergenCategories': categories});
    }
    return [];
  }

  @override
  Future<List<CascadedChange>> removeAllergenCategory(
      String familyId, String name) async {
    // Cascade handled locally; Firestore gets individual doc updates via sync.
    await _firestore.collection('families').doc(familyId).update({
      'allergenCategories': FieldValue.arrayRemove([name]),
    });
    return [];
  }
}
