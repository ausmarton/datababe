import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import 'package:datababe/local/store_refs.dart';
import 'package:datababe/sync/sync_queue.dart';

void main() {
  late Database db;
  late SyncQueue queue;

  setUp(() async {
    db = await newDatabaseFactoryMemory().openDatabase('test.db');
    queue = SyncQueue(db);
  });

  test('enqueue adds entry and getPending returns it', () async {
    await queue.enqueue(
      collection: 'activities',
      documentId: 'act-1',
      familyId: 'fam-1',
    );

    final pending = await queue.getPending();
    expect(pending.length, 1);
    expect(pending.first.collection, 'activities');
    expect(pending.first.documentId, 'act-1');
    expect(pending.first.familyId, 'fam-1');
  });

  test('enqueue same document collapses to one entry', () async {
    await queue.enqueue(
      collection: 'activities',
      documentId: 'act-1',
      familyId: 'fam-1',
    );
    await queue.enqueue(
      collection: 'activities',
      documentId: 'act-1',
      familyId: 'fam-1',
    );

    final pending = await queue.getPending();
    expect(pending.length, 1);
  });

  test('different documents create separate entries', () async {
    await queue.enqueue(
      collection: 'activities',
      documentId: 'act-1',
      familyId: 'fam-1',
    );
    await queue.enqueue(
      collection: 'activities',
      documentId: 'act-2',
      familyId: 'fam-1',
    );

    final pending = await queue.getPending();
    expect(pending.length, 2);
  });

  test('remove deletes entry', () async {
    await queue.enqueue(
      collection: 'activities',
      documentId: 'act-1',
      familyId: 'fam-1',
    );

    final pending = await queue.getPending();
    await queue.remove(pending.first.id);

    expect(await queue.hasPendingChanges(), false);
  });

  test('removeAll deletes multiple entries', () async {
    await queue.enqueue(
      collection: 'activities',
      documentId: 'act-1',
      familyId: 'fam-1',
    );
    await queue.enqueue(
      collection: 'ingredients',
      documentId: 'ing-1',
      familyId: 'fam-1',
    );

    final pending = await queue.getPending();
    await queue.removeAll(pending.map((e) => e.id).toList());

    expect(await queue.pendingCount(), 0);
  });

  test('hasPendingChanges returns false when empty', () async {
    expect(await queue.hasPendingChanges(), false);
  });

  test('pendingCount returns correct count', () async {
    await queue.enqueue(
      collection: 'activities',
      documentId: 'act-1',
      familyId: 'fam-1',
    );
    await queue.enqueue(
      collection: 'activities',
      documentId: 'act-2',
      familyId: 'fam-1',
    );

    expect(await queue.pendingCount(), 2);
  });

  test('isNew stored and retrieved correctly', () async {
    await queue.enqueue(
      collection: 'activities',
      documentId: 'act-1',
      familyId: 'fam-1',
      isNew: true,
    );

    final pending = await queue.getPending();
    expect(pending.first.isNew, true);
  });

  test('isNew defaults to false', () async {
    await queue.enqueue(
      collection: 'activities',
      documentId: 'act-1',
      familyId: 'fam-1',
    );

    final pending = await queue.getPending();
    expect(pending.first.isNew, false);
  });

  test('re-enqueue preserves isNew true through queue collapse', () async {
    // First enqueue as new.
    await queue.enqueue(
      collection: 'activities',
      documentId: 'act-1',
      familyId: 'fam-1',
      isNew: true,
    );
    // Re-enqueue as update (e.g. edit before push).
    await queue.enqueue(
      collection: 'activities',
      documentId: 'act-1',
      familyId: 'fam-1',
      isNew: false,
    );

    final pending = await queue.getPending();
    expect(pending.length, 1);
    expect(pending.first.isNew, true);
  });

  test('legacy entries without isNew default to false', () {
    final entry = SyncEntry.fromMap('test_key', {
      'collection': 'activities',
      'documentId': 'act-1',
      'familyId': 'fam-1',
      'createdAt': DateTime.now().toIso8601String(),
      // No 'isNew' key — simulates legacy data.
    });

    expect(entry.isNew, false);
  });

  test('SyncEntry toMap/fromMap round-trip preserves isNew', () {
    final original = SyncEntry(
      id: 'test_key',
      collection: 'activities',
      documentId: 'act-1',
      familyId: 'fam-1',
      createdAt: DateTime(2026, 3, 7),
      isNew: true,
    );

    final map = original.toMap();
    final restored = SyncEntry.fromMap('test_key', map);

    expect(restored.isNew, true);
    expect(restored.collection, original.collection);
    expect(restored.documentId, original.documentId);
    expect(restored.familyId, original.familyId);
  });

  group('retryCount tracking', () {
    test('SyncEntry retryCount defaults to 0', () async {
      await queue.enqueue(
        collection: 'activities',
        documentId: 'act-1',
        familyId: 'fam-1',
      );

      final pending = await queue.getPending();
      expect(pending.first.retryCount, 0);
    });

    test('SyncEntry retryCount preserved in toMap/fromMap', () {
      final entry = SyncEntry(
        id: 'key',
        collection: 'activities',
        documentId: 'act-1',
        familyId: 'fam-1',
        createdAt: DateTime(2026, 3, 19),
        retryCount: 5,
        lastError: 'network error',
      );

      final map = entry.toMap();
      final restored = SyncEntry.fromMap('key', map);
      expect(restored.retryCount, 5);
      expect(restored.lastError, 'network error');
    });

    test('legacy entries without retryCount default to 0', () {
      final entry = SyncEntry.fromMap('key', {
        'collection': 'activities',
        'documentId': 'act-1',
        'familyId': 'fam-1',
        'createdAt': DateTime.now().toIso8601String(),
      });
      expect(entry.retryCount, 0);
      expect(entry.lastError, isNull);
    });

    test('incrementRetry increases retryCount and stores error', () async {
      await queue.enqueue(
        collection: 'activities',
        documentId: 'act-1',
        familyId: 'fam-1',
      );

      final pending = await queue.getPending();
      await queue.incrementRetry(pending.first.id, 'network error');

      final updated = await queue.getPending();
      expect(updated.first.retryCount, 1);
      expect(updated.first.lastError, 'network error');

      await queue.incrementRetry(updated.first.id, 'timeout');
      final updated2 = await queue.getPending();
      expect(updated2.first.retryCount, 2);
      expect(updated2.first.lastError, 'timeout');
    });

    test('queue collapse resets retryCount to 0', () async {
      await queue.enqueue(
        collection: 'activities',
        documentId: 'act-1',
        familyId: 'fam-1',
      );
      final pending = await queue.getPending();
      await queue.incrementRetry(pending.first.id, 'err');
      await queue.incrementRetry(pending.first.id, 'err');

      // Re-enqueue same doc (user edit) → retryCount resets.
      await queue.enqueue(
        collection: 'activities',
        documentId: 'act-1',
        familyId: 'fam-1',
      );

      final updated = await queue.getPending();
      expect(updated.first.retryCount, 0);
      expect(updated.first.lastError, isNull);
    });
  });

  group('quarantine', () {
    test('quarantine moves entry from queue to dead letter store', () async {
      await queue.enqueue(
        collection: 'activities',
        documentId: 'act-1',
        familyId: 'fam-1',
      );

      final pending = await queue.getPending();
      expect(pending.length, 1);

      await queue.quarantine(pending.first.id, 'permanent error');

      // Entry removed from active queue.
      final afterQuarantine = await queue.getPending();
      expect(afterQuarantine, isEmpty);

      // Entry exists in dead letter store.
      final deadLetters = await queue.getQuarantined();
      expect(deadLetters.length, 1);
      expect(deadLetters.first.collection, 'activities');
      expect(deadLetters.first.documentId, 'act-1');
      expect(deadLetters.first.lastError, 'permanent error');
    });

    test('quarantined entries do not block hasPendingForDoc', () async {
      await queue.enqueue(
        collection: 'activities',
        documentId: 'act-1',
        familyId: 'fam-1',
      );

      // Before quarantine: entry is in queue store.
      final key = 'activities_act-1';
      final record = await StoreRefs.syncQueue.record(key).get(db);
      expect(record, isNotNull);

      await queue.quarantine(key, 'error');

      // After quarantine: entry is gone from queue store.
      final recordAfter = await StoreRefs.syncQueue.record(key).get(db);
      expect(recordAfter, isNull);
    });

    test('quarantinedCount returns correct count', () async {
      await queue.enqueue(
        collection: 'activities',
        documentId: 'act-1',
        familyId: 'fam-1',
      );
      await queue.enqueue(
        collection: 'ingredients',
        documentId: 'ing-1',
        familyId: 'fam-1',
      );

      final pending = await queue.getPending();
      await queue.quarantine(pending[0].id, 'err1');
      await queue.quarantine(pending[1].id, 'err2');

      expect(await queue.quarantinedCount(), 2);
      expect(await queue.pendingCount(), 0);
    });

    test('clearQuarantined removes all dead letter entries', () async {
      await queue.enqueue(
        collection: 'activities',
        documentId: 'act-1',
        familyId: 'fam-1',
      );
      final pending = await queue.getPending();
      await queue.quarantine(pending.first.id, 'err');

      await queue.clearQuarantined();
      expect(await queue.quarantinedCount(), 0);
    });

    test('retryQuarantined moves entry back to queue', () async {
      await queue.enqueue(
        collection: 'activities',
        documentId: 'act-1',
        familyId: 'fam-1',
      );
      final pending = await queue.getPending();
      await queue.quarantine(pending.first.id, 'err');

      await queue.retryQuarantined(pending.first.id);

      expect(await queue.quarantinedCount(), 0);
      final retried = await queue.getPending();
      expect(retried.length, 1);
      expect(retried.first.retryCount, 0);
      expect(retried.first.lastError, isNull);
    });
  });
}
