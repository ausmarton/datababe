import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_provider.dart';
import 'sync_provider.dart';

/// Performs initial sync after login by fetching familyIds from
/// the user's Firestore doc and pulling all family data locally.
///
/// Returns `true` when sync is complete (or skipped/failed).
/// Returns `null` (loading) while sync is in progress.
/// Re-evaluates on login/logout.
final initialSyncProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;

  try {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!userDoc.exists) return true; // New user, no data to sync

    final data = userDoc.data()!;
    final familyIds = (data['familyIds'] as List<dynamic>?)
            ?.cast<String>() ??
        [];

    if (familyIds.isEmpty) return true;

    final engine = ref.read(syncEngineProvider);
    await engine.initialSync(familyIds);
  } catch (e) {
    debugPrint('[Sync] initial sync failed: $e');
  }

  return true; // App should be usable even if sync failed
});
