import 'package:flutter/foundation.dart';
import 'package:sembast/sembast.dart';

import '../local/store_refs.dart';
import 'sync_metadata.dart';

/// One-time migration (v1.10.1) that heals data integrity issues:
///
/// 1. **Resets lastPull timestamps** — forces a full re-pull from Firestore,
///    which recovers activities that were invisible due to late pushes
///    (modifiedAt older than other devices' lastPull) and restores records
///    that were incorrectly hard-deleted by reconciliation.
///
/// 2. **Fills missing timestamp fields in local Sembast records** — scans
///    activities, ingredients, recipes, targets, children, and carers for
///    records missing startTime, createdAt, or modifiedAt. Fills them with
///    stable defaults so every read doesn't generate a new DateTime.now().
///
/// Records completion in syncMeta store so it only runs once per local DB.
/// Idempotent — re-runs harmlessly after logout/login.
class TimestampHealMigration {
  static const _migrationKey = 'timestamp_heal_v1';

  final Database _db;

  TimestampHealMigration(this._db);

  /// Runs the migration. Returns the number of local records healed.
  /// Returns 0 if migration already ran or no records needed healing.
  Future<int> run() async {
    // Check if already completed.
    final meta = await StoreRefs.syncMeta.record(_migrationKey).get(_db);
    if (meta != null) return 0;

    var healed = 0;

    // Step 1: Reset all lastPull timestamps to force full re-pull.
    final metadata = SyncMetadata(_db);
    await metadata.clearAllPullTimestamps();
    debugPrint('[Migration] timestamp-heal: reset all lastPull timestamps');

    // Step 2: Scan local records for missing timestamp fields and fill them.
    // This ensures stable reads even before the re-pull overwrites them.
    final stores = [
      StoreRefs.activities,
      StoreRefs.ingredients,
      StoreRefs.recipes,
      StoreRefs.targets,
      StoreRefs.children,
      StoreRefs.carers,
    ];

    for (final store in stores) {
      final records = await store.find(_db);
      for (final record in records) {
        final map = record.value;
        final now = DateTime.now().toIso8601String();
        var changed = false;

        final updated = Map<String, dynamic>.from(map);

        // Fill missing createdAt
        if (updated['createdAt'] == null ||
            (updated['createdAt'] is String &&
                (updated['createdAt'] as String).isEmpty)) {
          updated['createdAt'] = now;
          changed = true;
        }

        // Fill missing modifiedAt (default to createdAt)
        if (updated['modifiedAt'] == null ||
            (updated['modifiedAt'] is String &&
                (updated['modifiedAt'] as String).isEmpty)) {
          updated['modifiedAt'] =
              updated['createdAt'] as String? ?? now;
          changed = true;
        }

        // Fill missing startTime (activities only — other models don't have it)
        if (updated.containsKey('type') &&
            (updated['startTime'] == null ||
                (updated['startTime'] is String &&
                    (updated['startTime'] as String).isEmpty))) {
          updated['startTime'] = now;
          changed = true;
        }

        if (changed) {
          await store.record(record.key).put(_db, updated);
          healed++;
        }
      }
    }

    // Mark migration as complete.
    await StoreRefs.syncMeta.record(_migrationKey).put(_db, {
      'completedAt': DateTime.now().toIso8601String(),
    });

    debugPrint(
        '[Migration] timestamp-heal: complete — $healed records healed');

    return healed;
  }
}
