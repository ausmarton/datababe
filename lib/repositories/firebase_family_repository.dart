import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/family_model.dart';
import '../models/child_model.dart';
import '../models/carer_model.dart';
import '../models/invite_model.dart';
import '../models/enums.dart';
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

  @override
  Future<void> cancelInvite(String inviteId) async {
    await _firestore.collection('invites').doc(inviteId).delete();
  }

  // --- Invites ---

  @override
  Future<void> createInvite(InviteModel invite) async {
    await _firestore
        .collection('invites')
        .doc(invite.id)
        .set(invite.toFirestore());
  }

  @override
  Stream<List<InviteModel>> watchPendingInvites(String email) {
    return _firestore
        .collection('invites')
        .where('inviteeEmail', isEqualTo: email.toLowerCase())
        .where('status', isEqualTo: InviteStatus.pending.name)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => InviteModel.fromFirestore(doc))
            .toList());
  }

  @override
  Stream<List<InviteModel>> watchFamilyInvites(String familyId) {
    return _firestore
        .collection('invites')
        .where('familyId', isEqualTo: familyId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => InviteModel.fromFirestore(doc))
            .toList());
  }

  @override
  Future<void> acceptInvite({
    required InviteModel invite,
    required String uid,
    required String displayName,
  }) async {
    // Batch 1: Mark invite accepted + add UID to family memberUids.
    final batch1 = _firestore.batch();

    batch1.update(
      _firestore.collection('invites').doc(invite.id),
      {
        'status': InviteStatus.accepted.name,
        'respondedAt': FieldValue.serverTimestamp(),
      },
    );

    batch1.update(
      _firestore.collection('families').doc(invite.familyId),
      {
        'memberUids': FieldValue.arrayUnion([uid]),
      },
    );

    await batch1.commit();

    // Batch 2: Update user profile + create carer doc.
    final batch2 = _firestore.batch();

    batch2.set(
      _firestore.collection('users').doc(uid),
      {
        'familyIds': FieldValue.arrayUnion([invite.familyId]),
      },
      SetOptions(merge: true),
    );

    final carerId = const Uuid().v4();
    batch2.set(
      _firestore
          .collection('families')
          .doc(invite.familyId)
          .collection('carers')
          .doc(carerId),
      CarerModel(
        id: carerId,
        uid: uid,
        displayName: displayName,
        role: invite.role,
        createdAt: DateTime.now(),
      ).toFirestore(),
    );

    await batch2.commit();
  }

  @override
  Future<void> declineInvite(String inviteId) async {
    await _firestore.collection('invites').doc(inviteId).update({
      'status': InviteStatus.declined.name,
      'respondedAt': FieldValue.serverTimestamp(),
    });
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
}
