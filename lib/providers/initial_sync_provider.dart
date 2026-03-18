import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local/database_provider.dart';
import '../sync/ingredient_dedup_migration.dart';
import '../sync/timestamp_heal_migration.dart';
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

    final db = ref.read(localDatabaseProvider);

    // Timestamp heal migration: resets lastPull to force full re-pull,
    // fills missing timestamp fields in local records.
    // Runs BEFORE initialSync so the pull sees lastPull=null and does a
    // full re-pull, recovering invisible activities and hard-deleted records.
    try {
      final healMigration = TimestampHealMigration(db);
      final healed = await healMigration.run();
      if (healed > 0) {
        debugPrint('[Sync] timestamp-heal migration: $healed records fixed');
      }
    } catch (e) {
      debugPrint('[Sync] timestamp-heal migration failed: $e');
    }

    final engine = ref.read(syncEngineProvider);
    await engine.initialSync(familyIds);

    // Run one-time migrations after initial sync.
    try {
      final migration = IngredientDedupMigration(db);
      final changes = await migration.run();
      if (changes.isNotEmpty) {
        final queue = ref.read(syncQueueProvider);
        for (final change in changes) {
          await queue.enqueue(
            collection: change.collection,
            documentId: change.documentId,
            familyId: familyIds.first,
          );
        }
        engine.notifyWrite();
        debugPrint('[Sync] dedup migration: ${changes.length} docs enqueued');
      }
    } catch (e) {
      debugPrint('[Sync] dedup migration failed: $e');
    }

    debugPrint('[Sync] initial sync complete');
    return const InitialSyncResult(complete: true);
  } catch (e, st) {
    debugPrint('[Sync] initial sync failed: $e\n$st');
    return InitialSyncResult(complete: true, error: e.toString());
  }
});
