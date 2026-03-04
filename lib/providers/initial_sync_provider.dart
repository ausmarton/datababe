import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_provider.dart';
import 'sync_provider.dart';

/// Result of the initial sync attempt.
class InitialSyncResult {
  final bool complete;
  final String? error;

  const InitialSyncResult({required this.complete, this.error});
}

/// Performs initial sync after login by fetching familyIds from
/// the user's Firestore doc and pulling all family data locally.
///
/// Re-evaluates on login/logout.
final initialSyncProvider = FutureProvider<InitialSyncResult>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const InitialSyncResult(complete: false);

  try {
    debugPrint('[Sync] initial sync starting for uid=${user.uid}');

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!userDoc.exists) {
      debugPrint('[Sync] no user doc found — new user');
      return const InitialSyncResult(complete: true);
    }

    final data = userDoc.data()!;
    final familyIds = (data['familyIds'] as List<dynamic>?)
            ?.cast<String>() ??
        [];

    debugPrint('[Sync] found ${familyIds.length} families: $familyIds');

    if (familyIds.isEmpty) {
      return const InitialSyncResult(complete: true);
    }

    final engine = ref.read(syncEngineProvider);
    await engine.initialSync(familyIds);

    debugPrint('[Sync] initial sync complete');
    return const InitialSyncResult(complete: true);
  } catch (e, st) {
    debugPrint('[Sync] initial sync failed: $e\n$st');
    return InitialSyncResult(complete: true, error: e.toString());
  }
});
