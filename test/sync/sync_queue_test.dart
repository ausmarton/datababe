import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import 'package:datababe/sync/sync_queue.dart';

void main() {
  late SyncQueue queue;

  setUp(() async {
    final db = await newDatabaseFactoryMemory().openDatabase('test.db');
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
}
