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
}
