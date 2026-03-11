import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/invite_model.dart';
import 'auth_provider.dart';
import 'child_provider.dart';
import 'repository_provider.dart';

/// Pending invites for the currently signed-in user's email.
final pendingInvitesProvider = StreamProvider<List<InviteModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null || user.email.isEmpty) return Stream.value([]);
  final repo = ref.watch(inviteRepositoryProvider);
  return repo.watchPendingInvites(user.email);
});

/// All invites (any status) for the currently selected family.
final familyInvitesProvider = StreamProvider<List<InviteModel>>((ref) {
  final familyId = ref.watch(selectedFamilyIdProvider);
  if (familyId == null) return Stream.value([]);
  final repo = ref.watch(inviteRepositoryProvider);
  return repo.watchFamilyInvites(familyId);
});
