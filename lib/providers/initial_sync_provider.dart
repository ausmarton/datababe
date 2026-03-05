import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sembast/sembast.dart';

import '../local/database_provider.dart';
import '../local/store_refs.dart';
import 'auth_provider.dart';
import 'sync_provider.dart';

/// Result of the initial sync attempt.
class InitialSyncResult {
  final bool complete;
  final String? error;

  const InitialSyncResult({required this.complete, this.error});
}

/// Performs initial sync after login by querying Firestore for
/// families where the user is a member, then pulling all data locally.
///
/// Re-evaluates on login/logout.
final initialSyncProvider = FutureProvider<InitialSyncResult>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const InitialSyncResult(complete: false);

  try {
    debugPrint('[Sync] initial sync starting for uid=${user.uid}');

    // Query families where this user is a member — avoids stale
    // familyIds in the user doc and works with security rules.
    final familyDocs = await FirebaseFirestore.instance
        .collection('families')
        .where('memberUids', arrayContains: user.uid)
        .get();

    final familyIds = familyDocs.docs.map((doc) => doc.id).toList();

    debugPrint('[Sync] found ${familyIds.length} families: $familyIds');

    if (familyIds.isEmpty) {
      debugPrint('[Sync] no families found — new user');
      return const InitialSyncResult(complete: true);
    }

    final engine = ref.read(syncEngineProvider);
    await engine.initialSync(familyIds);

    // Verify data was stored in Sembast.
    final db = ref.read(localDatabaseProvider);
    final storedFamilies = await StoreRefs.families.find(db);
    final storedChildren = await StoreRefs.children.find(db);
    final storedActivities = await StoreRefs.activities.find(db);
    debugPrint('[Sync] initial sync complete — '
        'Sembast has ${storedFamilies.length} families, '
        '${storedChildren.length} children, '
        '${storedActivities.length} activities');
    for (final f in storedFamilies) {
      debugPrint('[Sync]   family ${f.key}: ${f.value['name']} '
          'memberUids=${f.value['memberUids']}');
    }

    return const InitialSyncResult(complete: true);
  } catch (e, st) {
    debugPrint('[Sync] initial sync failed: $e\n$st');
    return InitialSyncResult(complete: true, error: e.toString());
  }
});
