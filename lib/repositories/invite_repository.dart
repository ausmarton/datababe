import '../models/invite_model.dart';

/// Online-only invite operations (Firebase Auth required).
abstract class InviteRepository {
  Future<void> createInvite(InviteModel invite);

  Stream<List<InviteModel>> watchPendingInvites(String email);

  Stream<List<InviteModel>> watchFamilyInvites(String familyId);

  Future<void> acceptInvite({
    required InviteModel invite,
    required String uid,
    required String displayName,
  });

  Future<void> declineInvite(String inviteId);

  Future<void> cancelInvite(String inviteId);
}
