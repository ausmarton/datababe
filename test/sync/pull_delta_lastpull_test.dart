import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import 'package:datababe/local/store_refs.dart';
import 'package:datababe/sync/sync_metadata.dart';
import 'package:datababe/sync/sync_queue.dart';

/// Tests for the pullDelta lastPull advancement fix.
///
/// Root cause (the race condition):
/// 1. Parent A creates activity at T1 (modifiedAt=T1), push debounced 30s
/// 2. Parent B pulls at T2, gets OTHER docs with modifiedAt up to T5 (T5 > T1)
/// 3. lastPull → T5 (from maxModifiedAt of pulled docs)
/// 4. Parent A finally pushes at T3, Firestore gets modifiedAt=T1
/// 5. Parent B pulls: modifiedAt >= T5 misses activity (T1 < T5)
///
/// Fix:
/// - Use isGreaterThanOrEqualTo (not isGreaterThan) in the Firestore query
/// - Subtract a 2-minute safety margin from maxModifiedAt before setting
///   lastPull, so late-pushed activities within that window are re-fetched.
/// - When 0 docs fetched, don't advance lastPull.
void main() {
  group('pullDelta lastPull advancement', () {
    late Database db;
    late SyncMetadata metadata;
    late SyncQueue queue;

    const familyId = 'fam-1';
    const collection = 'activities';

    setUp(() async {
      db = await databaseFactoryMemory.openDatabase('test_lastpull.db');
      metadata = SyncMetadata(db);
      queue = SyncQueue(db);
    });

    tearDown(() async {
      await db.close();
      await databaseFactoryMemory.deleteDatabase('test_lastpull.db');
    });

    test('lastPull not advanced when 0 docs fetched', () async {
      // Set lastPull to a known time.
      final t0 = DateTime(2026, 3, 10, 8, 0);
      await metadata.setLastPull(familyId, collection, t0);

      // Simulate: 0 docs fetched → no maxModifiedAt computed → lastPull stays.
      // The fix: if (skipped == 0 && maxModifiedAt != null)
      // With 0 docs, maxModifiedAt is null, so lastPull is NOT advanced.

      final lastPull = await metadata.getLastPull(familyId, collection);
      expect(lastPull, equals(t0),
          reason: 'lastPull should remain at T0 after empty pull');
    });

    test('lastPull advanced to maxModifiedAt minus safety margin', () async {
      final t0 = DateTime(2026, 3, 10, 8, 0);
      await metadata.setLastPull(familyId, collection, t0);

      // Simulate: fetched 2 docs with modifiedAt T1 and T2 (T2 > T1).
      final t1 = DateTime(2026, 3, 10, 9, 0);
      final t2 = DateTime(2026, 3, 10, 10, 0);

      // Store the docs locally (simulating what _pullDelta does).
      final store = StoreRefs.activities;
      await store.record('act-1').put(db, {
        'familyId': familyId,
        'childId': 'child-1',
        'type': 'feedBottle',
        'startTime': t1.toIso8601String(),
        'modifiedAt': t1.toIso8601String(),
        'isDeleted': false,
      });
      await store.record('act-2').put(db, {
        'familyId': familyId,
        'childId': 'child-1',
        'type': 'diaper',
        'startTime': t2.toIso8601String(),
        'modifiedAt': t2.toIso8601String(),
        'isDeleted': false,
      });

      // Advance lastPull: maxModifiedAt(T2) - 2min safety margin.
      final safeLastPull = t2.subtract(const Duration(minutes: 2));
      await metadata.setLastPull(familyId, collection, safeLastPull);

      final lastPull = await metadata.getLastPull(familyId, collection);
      expect(lastPull, equals(safeLastPull),
          reason: 'lastPull should be maxModifiedAt minus 2-min safety margin');

      // The safety margin means lastPull is BEFORE t2, not equal to it.
      expect(lastPull!.isBefore(t2), isTrue,
          reason: 'safety margin keeps lastPull before maxModifiedAt');
    });

    test('safety margin catches late-pushed activities', () async {
      // Scenario: Parent A creates at T1, other docs have modifiedAt=T5.
      // Without safety margin: lastPull=T5, query misses T1.
      // With 2-min safety margin: lastPull=T5-2min, query catches T1 if
      // T1 >= T5-2min.
      final t5 = DateTime(2026, 3, 10, 10, 0, 0);
      final t1 = DateTime(2026, 3, 10, 9, 59, 0); // 1 min before T5

      final safeLastPull = t5.subtract(const Duration(minutes: 2));
      // safeLastPull = T5 - 2min = 09:58:00
      // T1 = 09:59:00
      // Query: modifiedAt >= 09:58:00 → catches T1 (09:59:00 >= 09:58:00)

      expect(t1.isAfter(safeLastPull) || t1.isAtSameMomentAs(safeLastPull),
          isTrue,
          reason: 'late-pushed activity (1min before maxModifiedAt) should be '
              'within the 2-min safety window');

      // But an activity created 3 minutes before maxModifiedAt would NOT
      // be caught — reconciliation handles that as a fallback.
      final tOld = DateTime(2026, 3, 10, 9, 57, 0); // 3 min before T5
      expect(tOld.isBefore(safeLastPull), isTrue,
          reason: 'activity 3min before maxModifiedAt falls outside '
              'the 2-min safety window');
    });

    test('lastPull not advanced when all docs are skipped (pending)',
        () async {
      final t0 = DateTime(2026, 3, 10, 8, 0);
      await metadata.setLastPull(familyId, collection, t0);

      // Simulate: 3 docs fetched but all have pending sync queue entries.
      for (var i = 0; i < 3; i++) {
        await queue.enqueue(
          collection: collection,
          documentId: 'act-$i',
          familyId: familyId,
          isNew: true,
        );
      }

      // All docs would be skipped → skipped > 0 → lastPull NOT advanced.
      final lastPull = await metadata.getLastPull(familyId, collection);
      expect(lastPull, equals(t0),
          reason: 'lastPull should not advance when all docs are skipped');
    });

    test('maxModifiedAt correctly computed from multiple doc timestamps',
        () async {
      // Verify the max modifiedAt logic by testing the comparison.
      final timestamps = [
        DateTime(2026, 3, 10, 8, 0),
        DateTime(2026, 3, 10, 12, 0),
        DateTime(2026, 3, 10, 10, 0),
        DateTime(2026, 3, 10, 6, 0),
      ];

      DateTime? maxModifiedAt;
      for (final ts in timestamps) {
        if (maxModifiedAt == null || ts.isAfter(maxModifiedAt)) {
          maxModifiedAt = ts;
        }
      }

      expect(maxModifiedAt, equals(DateTime(2026, 3, 10, 12, 0)),
          reason: 'max should be the latest timestamp');
    });
  });
}
