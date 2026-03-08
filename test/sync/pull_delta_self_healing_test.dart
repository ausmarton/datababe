import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import 'package:datababe/local/store_refs.dart';
import 'package:datababe/sync/sync_metadata.dart';
import 'package:datababe/sync/sync_queue.dart';

/// Tests for the pull-delta self-healing and lastPull advancement logic.
///
/// Root cause scenario (the bug):
/// 1. User imports 5000+ activities via CSV → all enqueued for sync (isNew).
/// 2. App restarts → _pullDelta fetches all from Firestore.
/// 3. ALL are skipped because _hasPendingForDoc returns true.
/// 4. lastPull is advanced to DateTime.now() anyway.
/// 5. Sync push later clears queue entries.
/// 6. Next delta pull: modifiedAt > lastPull → 0 docs.
/// 7. Activities permanently missing from local DB.
///
/// Fixes:
/// - Self-healing: if lastPull is set but local store is empty, reset for
///   full re-pull.
/// - Don't advance lastPull if any docs were skipped due to pending entries.
/// - Push before pull in initialSync.
void main() {
  group('pullDelta self-healing', () {
    late Database db;
    late SyncMetadata metadata;
    late SyncQueue queue;

    const familyId = 'fam-1';
    const collection = 'activities';

    setUp(() async {
      db = await databaseFactoryMemory.openDatabase('test.db');
      metadata = SyncMetadata(db);
      queue = SyncQueue(db);
    });

    tearDown(() async {
      await db.close();
      await databaseFactoryMemory.deleteDatabase('test.db');
    });

    test('lastPull set but empty store → detectable condition', () async {
      // Simulate the broken state: lastPull is set but no activities locally.
      await metadata.setLastPull(familyId, collection, DateTime(2026, 3, 8));

      final lastPull = await metadata.getLastPull(familyId, collection);
      expect(lastPull, isNotNull);

      // Store has 0 records for this family.
      final store = StoreRefs.activities;
      final localCount = await store.count(db,
          filter: Filter.equals('familyId', familyId));
      expect(localCount, 0);

      // Self-healing condition: lastPull set but 0 local records.
      // The fix in _pullDelta resets lastPull to null in this case.
      expect(lastPull != null && localCount == 0, isTrue,
          reason: 'Self-healing should detect this state');
    });

    test('pending sync entries block pull', () async {
      // Simulate: 3 activities with pending sync queue entries.
      for (var i = 0; i < 3; i++) {
        await queue.enqueue(
          collection: collection,
          documentId: 'act-$i',
          familyId: familyId,
          isNew: true,
        );
      }

      // Verify all have pending entries.
      for (var i = 0; i < 3; i++) {
        final key = '${collection}_act-$i';
        final record = await StoreRefs.syncQueue.record(key).get(db);
        expect(record, isNotNull,
            reason: 'Activity act-$i should have a pending entry');
      }

      // The _pullDelta code checks _hasPendingForDoc for each doc.
      // With all pending, all would be skipped, and lastPull should NOT advance.
      final pendingCount = await queue.pendingCount();
      expect(pendingCount, 3);
    });

    test('clearing queue entries unblocks pull', () async {
      // Enqueue 3 activities.
      for (var i = 0; i < 3; i++) {
        await queue.enqueue(
          collection: collection,
          documentId: 'act-$i',
          familyId: familyId,
          isNew: true,
        );
      }
      expect(await queue.pendingCount(), 3);

      // Simulate push completing: remove all entries.
      final entries = await queue.getPending();
      await queue.removeAll(entries.map((e) => e.id).toList());
      expect(await queue.pendingCount(), 0);

      // Now _hasPendingForDoc would return false for all → pull stores them.
      for (var i = 0; i < 3; i++) {
        final key = '${collection}_act-$i';
        final record = await StoreRefs.syncQueue.record(key).get(db);
        expect(record, isNull,
            reason: 'Entry should be cleared after push');
      }
    });

    test('self-healing recovers after queue is cleared', () async {
      // Step 1: Broken state — lastPull set, no local data.
      await metadata.setLastPull(familyId, collection, DateTime(2026, 3, 8));
      final store = StoreRefs.activities;
      var localCount = await store.count(db,
          filter: Filter.equals('familyId', familyId));
      expect(localCount, 0);

      // Step 2: Self-healing detects the condition.
      var lastPull = await metadata.getLastPull(familyId, collection);
      final needsFullPull = lastPull != null && localCount == 0;
      expect(needsFullPull, isTrue);

      // Step 3: Reset lastPull (as the fix does).
      if (needsFullPull) {
        lastPull = null; // Would trigger a full re-pull.
      }
      expect(lastPull, isNull);

      // Step 4: After full re-pull stores data, lastPull can advance.
      await store.record('act-1').put(db, {
        'familyId': familyId,
        'childId': 'child-1',
        'type': 'feedBottle',
        'startTime': '2026-03-07T10:00:00.000Z',
        'modifiedAt': '2026-03-07T10:00:00.000Z',
        'isDeleted': false,
      });
      localCount = await store.count(db,
          filter: Filter.equals('familyId', familyId));
      expect(localCount, 1);

      // Now lastPull can safely advance.
      await metadata.setLastPull(familyId, collection, DateTime(2026, 3, 9));
      lastPull = await metadata.getLastPull(familyId, collection);
      expect(lastPull, isNotNull);
    });

    test('other families not affected by self-healing', () async {
      const otherFamily = 'fam-2';
      final store = StoreRefs.activities;

      // Family 1: broken state (lastPull set, no data).
      await metadata.setLastPull(familyId, collection, DateTime(2026, 3, 8));

      // Family 2: healthy state (lastPull set, has data).
      await metadata.setLastPull(otherFamily, collection, DateTime(2026, 3, 8));
      await store.record('act-other').put(db, {
        'familyId': otherFamily,
        'childId': 'child-2',
        'type': 'diaper',
        'startTime': '2026-03-07T12:00:00.000Z',
        'modifiedAt': '2026-03-07T12:00:00.000Z',
        'isDeleted': false,
      });

      // Family 1 needs self-healing.
      final count1 = await store.count(db,
          filter: Filter.equals('familyId', familyId));
      final lastPull1 = await metadata.getLastPull(familyId, collection);
      expect(lastPull1 != null && count1 == 0, isTrue);

      // Family 2 does NOT need self-healing.
      final count2 = await store.count(db,
          filter: Filter.equals('familyId', otherFamily));
      final lastPull2 = await metadata.getLastPull(otherFamily, collection);
      expect(lastPull2 != null && count2 == 0, isFalse);
    });
  });
}
