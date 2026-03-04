import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import 'package:datababe/local/store_refs.dart';
import 'package:datababe/sync/sync_queue.dart';

/// Tests the clearLocalData logic by verifying that all entity stores,
/// the sync queue, and sync metadata are dropped.
///
/// Note: SyncEngine.clearLocalData() requires a Firebase instance to
/// construct, so we test the equivalent drop logic directly on stores.
void main() {
  group('clearLocalData equivalent', () {
    late dynamic db;

    setUp(() async {
      db = await newDatabaseFactoryMemory().openDatabase('test.db');
    });

    test('drops all entity stores', () async {
      // Populate every store.
      await StoreRefs.activities.record('a1').put(db, {'type': 'feedBottle'});
      await StoreRefs.ingredients.record('i1').put(db, {'name': 'milk'});
      await StoreRefs.recipes.record('r1').put(db, {'name': 'porridge'});
      await StoreRefs.targets.record('t1').put(db, {'metric': 'count'});
      await StoreRefs.families.record('f1').put(db, {'name': 'Smith'});
      await StoreRefs.children.record('c1').put(db, {'name': 'Lily'});
      await StoreRefs.carers.record('cr1').put(db, {'name': 'Dad'});

      // Verify populated.
      expect(await StoreRefs.activities.count(db), 1);
      expect(await StoreRefs.ingredients.count(db), 1);
      expect(await StoreRefs.recipes.count(db), 1);
      expect(await StoreRefs.targets.count(db), 1);
      expect(await StoreRefs.families.count(db), 1);
      expect(await StoreRefs.children.count(db), 1);
      expect(await StoreRefs.carers.count(db), 1);

      // Drop all stores (mirrors SyncEngine.clearLocalData).
      final storeMap = <String, StoreRef<String, Map<String, dynamic>>>{
        'activities': StoreRefs.activities,
        'ingredients': StoreRefs.ingredients,
        'recipes': StoreRefs.recipes,
        'targets': StoreRefs.targets,
        'families': StoreRefs.families,
        'children': StoreRefs.children,
        'carers': StoreRefs.carers,
      };
      await db.transaction((txn) async {
        for (final store in storeMap.values) {
          await store.drop(txn);
        }
        await StoreRefs.syncQueue.drop(txn);
        await StoreRefs.syncMeta.drop(txn);
      });

      // Verify all empty.
      expect(await StoreRefs.activities.count(db), 0);
      expect(await StoreRefs.ingredients.count(db), 0);
      expect(await StoreRefs.recipes.count(db), 0);
      expect(await StoreRefs.targets.count(db), 0);
      expect(await StoreRefs.families.count(db), 0);
      expect(await StoreRefs.children.count(db), 0);
      expect(await StoreRefs.carers.count(db), 0);
    });

    test('drops sync queue and metadata', () async {
      final queue = SyncQueue(db);
      await queue.enqueue(
        collection: 'activities',
        documentId: 'act-1',
        familyId: 'fam-1',
      );
      await StoreRefs.syncMeta.record('fam-1_activities').put(db, {
        'familyId': 'fam-1',
        'collection': 'activities',
        'lastPull': DateTime.now().toIso8601String(),
      });

      expect(await queue.pendingCount(), 1);
      expect(await StoreRefs.syncMeta.count(db), 1);

      // Drop.
      await db.transaction((txn) async {
        await StoreRefs.syncQueue.drop(txn);
        await StoreRefs.syncMeta.drop(txn);
      });

      expect(await queue.pendingCount(), 0);
      expect(await StoreRefs.syncMeta.count(db), 0);
    });

    test('stores are usable after drop', () async {
      await StoreRefs.activities.record('a1').put(db, {'type': 'feedBottle'});
      await db.transaction((txn) async {
        await StoreRefs.activities.drop(txn);
      });

      // Can still write after drop.
      await StoreRefs.activities.record('a2').put(db, {'type': 'diaper'});
      expect(await StoreRefs.activities.count(db), 1);

      final record = await StoreRefs.activities.record('a2').get(db);
      expect(record?['type'], 'diaper');
    });
  });
}
