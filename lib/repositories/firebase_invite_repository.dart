import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/carer_model.dart';
import '../models/enums.dart';
import '../models/invite_model.dart';
import 'invite_repository.dart';

class FirebaseInviteRepository implements InviteRepository {
  final FirebaseFirestore _firestore;

  FirebaseInviteRepository(this._firestore);

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

  @override
  Future<void> cancelInvite(String inviteId) async {
    await _firestore.collection('invites').doc(inviteId).delete();
  }
}
