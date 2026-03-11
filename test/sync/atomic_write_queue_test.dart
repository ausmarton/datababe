import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import 'package:datababe/local/store_refs.dart';
import 'package:datababe/models/activity_model.dart';
import 'package:datababe/models/child_model.dart';
import 'package:datababe/models/carer_model.dart';
import 'package:datababe/models/family_model.dart';
import 'package:datababe/models/ingredient_model.dart';
import 'package:datababe/models/recipe_model.dart';
import 'package:datababe/models/target_model.dart';
import 'package:datababe/repositories/local_activity_repository.dart';
import 'package:datababe/repositories/local_family_repository.dart';
import 'package:datababe/repositories/local_ingredient_repository.dart';
import 'package:datababe/repositories/local_recipe_repository.dart';
import 'package:datababe/repositories/local_target_repository.dart';
import 'package:datababe/sync/sync_queue.dart';

late Database db;
late SyncQueue queue;
var _dbIndex = 0;

final _now = DateTime(2026, 3, 10);

Future<void> _setUp() async {
  _dbIndex++;
  db = await databaseFactoryMemory.openDatabase('test_atomic_$_dbIndex');
  queue = SyncQueue(db);
}

Future<void> _tearDown() async {
  await db.close();
  await databaseFactoryMemory.deleteDatabase('test_atomic_$_dbIndex');
}

void main() {
  setUp(_setUp);
  tearDown(_tearDown);

  group('SyncQueue.enqueueTxn', () {
    test('enqueue within transaction is visible after commit', () async {
      await db.transaction((txn) async {
        await queue.enqueueTxn(txn,
          collection: 'activities',
          documentId: 'a1',
          familyId: 'f1',
          isNew: true,
        );
      });
      final entries = await queue.getPending();
      expect(entries.length, 1);
      expect(entries.first.collection, 'activities');
      expect(entries.first.documentId, 'a1');
      expect(entries.first.isNew, true);
    });

    test('preserves isNew on queue collapse', () async {
      // First enqueue as new
      await queue.enqueueTxn(db,
        collection: 'activities',
        documentId: 'a1',
        familyId: 'f1',
        isNew: true,
      );
      // Second enqueue as update — should preserve isNew
      await queue.enqueueTxn(db,
        collection: 'activities',
        documentId: 'a1',
        familyId: 'f1',
        isNew: false,
      );
      final entries = await queue.getPending();
      expect(entries.length, 1);
      expect(entries.first.isNew, true);
    });
  });

  group('Atomic activity write + queue', () {
    test('insertActivity and queue entry in same transaction', () async {
      final repo = LocalActivityRepository(db);
      final activity = ActivityModel(
        id: 'a1',
        childId: 'c1',
        type: 'solids',
        startTime: _now,
        createdAt: _now,
        modifiedAt: _now,
      );

      await db.transaction((txn) async {
        await repo.insertActivity('f1', activity, txn: txn);
        await queue.enqueueTxn(txn,
          collection: 'activities',
          documentId: activity.id,
          familyId: 'f1',
          isNew: true,
        );
      });

      // Both should exist
      final record = await StoreRefs.activities.record('a1').get(db);
      expect(record, isNotNull);
      final entries = await queue.getPending();
      expect(entries.length, 1);
    });

    test('failed transaction rolls back both write and queue', () async {
      final repo = LocalActivityRepository(db);
      final activity = ActivityModel(
        id: 'a2',
        childId: 'c1',
        type: 'solids',
        startTime: _now,
        createdAt: _now,
        modifiedAt: _now,
      );

      try {
        await db.transaction((txn) async {
          await repo.insertActivity('f1', activity, txn: txn);
          await queue.enqueueTxn(txn,
            collection: 'activities',
            documentId: activity.id,
            familyId: 'f1',
            isNew: true,
          );
          throw Exception('simulated crash');
        });
      } catch (_) {}

      // Neither should exist
      final record = await StoreRefs.activities.record('a2').get(db);
      expect(record, isNull);
      final entries = await queue.getPending();
      expect(entries, isEmpty);
    });

    test('softDeleteActivity and queue entry in same transaction', () async {
      final repo = LocalActivityRepository(db);
      final activity = ActivityModel(
        id: 'a3',
        childId: 'c1',
        type: 'solids',
        startTime: _now,
        createdAt: _now,
        modifiedAt: _now,
      );
      // Pre-insert
      await repo.insertActivity('f1', activity);

      await db.transaction((txn) async {
        await repo.softDeleteActivity('f1', 'a3', txn: txn);
        await queue.enqueueTxn(txn,
          collection: 'activities',
          documentId: 'a3',
          familyId: 'f1',
        );
      });

      final record = await StoreRefs.activities.record('a3').get(db);
      expect(record!['isDeleted'], true);
      expect(await queue.pendingCount(), 1);
    });

    test('insertActivities batch and queue entries in same transaction',
        () async {
      final repo = LocalActivityRepository(db);
      final activities = List.generate(
        5,
        (i) => ActivityModel(
          id: 'batch_$i',
          childId: 'c1',
          type: 'solids',
          startTime: _now,
          createdAt: _now,
          modifiedAt: _now,
        ),
      );

      await db.transaction((txn) async {
        await repo.insertActivities('f1', activities, txn: txn);
        for (final a in activities) {
          await queue.enqueueTxn(txn,
            collection: 'activities',
            documentId: a.id,
            familyId: 'f1',
            isNew: true,
          );
        }
      });

      final count = await StoreRefs.activities.count(db);
      expect(count, 5);
      expect(await queue.pendingCount(), 5);
    });
  });

  group('Atomic target write + queue', () {
    test('createTarget and queue entry in same transaction', () async {
      final repo = LocalTargetRepository(db);
      final target = TargetModel(
        id: 't1',
        childId: 'c1',
        activityType: 'solids',
        metric: 'count',
        period: 'weekly',
        targetValue: 5,
        createdBy: 'u1',
        createdAt: _now,
        modifiedAt: _now,
      );

      await db.transaction((txn) async {
        await repo.createTarget('f1', target, txn: txn);
        await queue.enqueueTxn(txn,
          collection: 'targets',
          documentId: target.id,
          familyId: 'f1',
          isNew: true,
        );
      });

      final record = await StoreRefs.targets.record('t1').get(db);
      expect(record, isNotNull);
      expect(await queue.pendingCount(), 1);
    });

    test('deactivateTarget and queue entry in same transaction', () async {
      final repo = LocalTargetRepository(db);
      final target = TargetModel(
        id: 't2',
        childId: 'c1',
        activityType: 'solids',
        metric: 'count',
        period: 'weekly',
        targetValue: 5,
        createdBy: 'u1',
        createdAt: _now,
        modifiedAt: _now,
      );
      await repo.createTarget('f1', target);

      await db.transaction((txn) async {
        await repo.deactivateTarget('f1', 't2', txn: txn);
        await queue.enqueueTxn(txn,
          collection: 'targets',
          documentId: 't2',
          familyId: 'f1',
        );
      });

      final record = await StoreRefs.targets.record('t2').get(db);
      expect(record!['isActive'], false);
      expect(await queue.pendingCount(), 1);
    });
  });

  group('Atomic recipe write + queue', () {
    test('createRecipe and queue entry in same transaction', () async {
      final repo = LocalRecipeRepository(db);
      final recipe = RecipeModel(
        id: 'r1',
        name: 'test recipe',
        ingredients: ['egg'],
        createdBy: 'u1',
        createdAt: _now,
        modifiedAt: _now,
      );

      await db.transaction((txn) async {
        await repo.createRecipe('f1', recipe, txn: txn);
        await queue.enqueueTxn(txn,
          collection: 'recipes',
          documentId: recipe.id,
          familyId: 'f1',
          isNew: true,
        );
      });

      final record = await StoreRefs.recipes.record('r1').get(db);
      expect(record, isNotNull);
      expect(await queue.pendingCount(), 1);
    });
  });

  group('Atomic ingredient write + queue', () {
    test('createIngredient and queue entry in same transaction', () async {
      final repo = LocalIngredientRepository(db);
      final ingredient = IngredientModel(
        id: 'i1',
        name: 'egg',
        allergens: ['egg'],
        createdBy: 'u1',
        createdAt: _now,
        modifiedAt: _now,
      );

      await db.transaction((txn) async {
        await repo.createIngredient('f1', ingredient, txn: txn);
        await queue.enqueueTxn(txn,
          collection: 'ingredients',
          documentId: ingredient.id,
          familyId: 'f1',
          isNew: true,
        );
      });

      final record = await StoreRefs.ingredients.record('i1').get(db);
      expect(record, isNotNull);
      expect(await queue.pendingCount(), 1);
    });

    test('renameIngredient and queue entries in same transaction', () async {
      final repo = LocalIngredientRepository(db);
      final ingredient = IngredientModel(
        id: 'i2',
        name: 'egg',
        allergens: ['egg'],
        createdBy: 'u1',
        createdAt: _now,
        modifiedAt: _now,
      );
      await repo.createIngredient('f1', ingredient);

      final renamed = IngredientModel(
        id: 'i2',
        name: 'chicken egg',
        allergens: ['egg'],
        createdBy: 'u1',
        createdAt: _now,
        modifiedAt: _now,
      );

      late List changes;
      await db.transaction((txn) async {
        changes = await repo.renameIngredient('f1', renamed, 'egg', txn: txn);
        await queue.enqueueTxn(txn,
          collection: 'ingredients',
          documentId: renamed.id,
          familyId: 'f1',
        );
        for (final change in changes) {
          await queue.enqueueTxn(txn,
            collection: change.collection,
            documentId: change.documentId,
            familyId: 'f1',
          );
        }
      });

      final record = await StoreRefs.ingredients.record('i2').get(db);
      expect(record!['name'], 'chicken egg');
      expect(await queue.pendingCount(), greaterThanOrEqualTo(1));
    });
  });

  group('Atomic family write + queue', () {
    test('createFamily and queue entry in same transaction', () async {
      final repo = LocalFamilyRepository(db);
      final family = FamilyModel(
        id: 'f1',
        name: 'Test Family',
        createdBy: 'u1',
        memberUids: ['u1'],
        createdAt: _now,
        modifiedAt: _now,
      );

      await db.transaction((txn) async {
        await repo.createFamily(family, txn: txn);
        await queue.enqueueTxn(txn,
          collection: 'families',
          documentId: family.id,
          familyId: family.id,
          isNew: true,
        );
      });

      final record = await StoreRefs.families.record('f1').get(db);
      expect(record, isNotNull);
      expect(await queue.pendingCount(), 1);
    });

    test('createFamilyWithChild and queue entries in same transaction',
        () async {
      final repo = LocalFamilyRepository(db);
      final family = FamilyModel(
        id: 'f2',
        name: 'Family 2',
        createdBy: 'u1',
        memberUids: ['u1'],
        createdAt: _now,
        modifiedAt: _now,
      );
      final child = ChildModel(
        id: 'c1',
        name: 'Baby',
        dateOfBirth: _now,
        createdAt: _now,
        modifiedAt: _now,
      );
      final carer = CarerModel(
        id: 'cr1',
        uid: 'u1',
        displayName: 'Test User',
        role: 'parent',
        createdAt: _now,
        modifiedAt: _now,
      );

      await db.transaction((txn) async {
        await repo.createFamilyWithChild(
          family: family,
          child: child,
          carer: carer,
          txn: txn,
        );
        await queue.enqueueTxn(txn,
          collection: 'families',
          documentId: family.id,
          familyId: family.id,
          isNew: true,
        );
        await queue.enqueueTxn(txn,
          collection: 'children',
          documentId: child.id,
          familyId: family.id,
          isNew: true,
        );
        await queue.enqueueTxn(txn,
          collection: 'carers',
          documentId: carer.id,
          familyId: family.id,
          isNew: true,
        );
      });

      expect(await StoreRefs.families.record('f2').get(db), isNotNull);
      expect(await StoreRefs.children.record('c1').get(db), isNotNull);
      expect(await StoreRefs.carers.record('cr1').get(db), isNotNull);
      expect(await queue.pendingCount(), 3);
    });

    test('failed family transaction rolls back all stores', () async {
      final repo = LocalFamilyRepository(db);
      final family = FamilyModel(
        id: 'f3',
        name: 'Family 3',
        createdBy: 'u1',
        memberUids: ['u1'],
        createdAt: _now,
        modifiedAt: _now,
      );
      final child = ChildModel(
        id: 'c2',
        name: 'Baby 2',
        dateOfBirth: _now,
        createdAt: _now,
        modifiedAt: _now,
      );
      final carer = CarerModel(
        id: 'cr2',
        uid: 'u1',
        displayName: 'Test User',
        role: 'parent',
        createdAt: _now,
        modifiedAt: _now,
      );

      try {
        await db.transaction((txn) async {
          await repo.createFamilyWithChild(
            family: family,
            child: child,
            carer: carer,
            txn: txn,
          );
          await queue.enqueueTxn(txn,
            collection: 'families',
            documentId: family.id,
            familyId: family.id,
            isNew: true,
          );
          throw Exception('simulated crash');
        });
      } catch (_) {}

      expect(await StoreRefs.families.record('f3').get(db), isNull);
      expect(await StoreRefs.children.record('c2').get(db), isNull);
      expect(await StoreRefs.carers.record('cr2').get(db), isNull);
      // Queue should not have any entries from this failed transaction
      final entries = await queue.getPending();
      final f3Entries =
          entries.where((e) => e.familyId == 'f3').toList();
      expect(f3Entries, isEmpty);
    });
  });
}
