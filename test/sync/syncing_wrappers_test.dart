import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import 'package:datababe/local/store_refs.dart';
import 'package:datababe/models/activity_model.dart';
import 'package:datababe/models/ingredient_model.dart';
import 'package:datababe/models/recipe_model.dart';
import 'package:datababe/models/target_model.dart';
import 'package:datababe/models/carer_model.dart';
import 'package:datababe/models/child_model.dart';
import 'package:datababe/models/family_model.dart';
import 'package:datababe/repositories/local_activity_repository.dart';
import 'package:datababe/repositories/local_family_repository.dart';
import 'package:datababe/repositories/local_ingredient_repository.dart';
import 'package:datababe/repositories/local_recipe_repository.dart';
import 'package:datababe/repositories/local_target_repository.dart';
import 'package:datababe/sync/sync_engine_interface.dart';
import 'package:datababe/sync/sync_queue.dart';
import 'package:datababe/sync/syncing_activity_repository.dart';
import 'package:datababe/sync/syncing_family_repository.dart';
import 'package:datababe/sync/syncing_ingredient_repository.dart';
import 'package:datababe/sync/syncing_recipe_repository.dart';
import 'package:datababe/sync/syncing_target_repository.dart';

/// Minimal fake SyncEngine that tracks notifyWrite() calls.
class _FakeSyncEngine implements SyncEngineInterface {
  int notifyWriteCount = 0;

  @override
  void start() {}
  @override
  void dispose() {}
  @override
  void notifyWrite() => notifyWriteCount++;
  @override
  Future<SyncResult> syncNow() async => SyncResult.empty;
  @override
  Stream<SyncStatus> get statusStream => Stream.value(SyncStatus.idle);
  @override
  SyncStatus get currentStatus => SyncStatus.idle;
  @override
  Future<DateTime?> get lastSyncTime async => null;
  @override
  Future<int> get pendingCount async => 0;
  @override
  Future<void> initialSync(List<String> familyIds) async {}
  @override
  Future<void> forceFullResync(List<String> familyIds) async {}
  @override
  Future<void> clearLocalData() async {}
  @override
  Future<List<String>> fetchFamilyIds() async => [];
  @override
  Future<Map<String, dynamic>> getDiagnostics(String familyId) async => {};
  @override
  Future<Map<String, dynamic>> dateAudit(
      String familyId, DateTime date) async =>
      {};
}

const _familyId = 'fam-1';
const _childId = 'child-1';
final _now = DateTime(2026, 3, 19, 10, 0);

ActivityModel _activity({
  String id = 'act-1',
  String type = 'bottle_feed',
  String? notes,
}) =>
    ActivityModel(
      id: id,
      childId: _childId,
      type: type,
      startTime: _now,
      createdAt: _now,
      modifiedAt: _now,
      notes: notes,
    );

IngredientModel _ingredient({String id = 'ing-1', String name = 'egg'}) =>
    IngredientModel(
      id: id,
      name: name,
      allergens: const ['egg'],
      createdBy: 'user-1',
      createdAt: _now,
      modifiedAt: _now,
    );

RecipeModel _recipe({String id = 'rec-1', String name = 'omelette'}) =>
    RecipeModel(
      id: id,
      name: name,
      ingredients: const ['egg', 'milk'],
      createdBy: 'user-1',
      createdAt: _now,
      modifiedAt: _now,
    );

TargetModel _target({String id = 'tgt-1'}) => TargetModel(
      id: id,
      childId: _childId,
      activityType: 'bottle_feed',
      metric: 'count',
      period: 'daily',
      targetValue: 5,
      createdBy: 'user-1',
      createdAt: _now,
      modifiedAt: _now,
    );

void main() {
  late Database db;
  late SyncQueue queue;
  late _FakeSyncEngine engine;

  setUp(() async {
    db = await newDatabaseFactoryMemory().openDatabase('test.db');
    queue = SyncQueue(db);
    engine = _FakeSyncEngine();
  });

  group('SyncingActivityRepository', () {
    late SyncingActivityRepository repo;

    setUp(() {
      final local = LocalActivityRepository(db);
      repo = SyncingActivityRepository(local, queue, engine, db);
    });

    test('insertActivity stores data and enqueues with isNew:true', () async {
      await repo.insertActivity(_familyId, _activity());

      // Data stored in Sembast.
      final record = await StoreRefs.activities.record('act-1').get(db);
      expect(record, isNotNull);
      expect(record!['type'], 'bottle_feed');
      expect(record['familyId'], _familyId);

      // Sync queue entry with isNew:true.
      final pending = await queue.getPending();
      expect(pending.length, 1);
      expect(pending.first.collection, 'activities');
      expect(pending.first.documentId, 'act-1');
      expect(pending.first.isNew, true);

      // Engine notified.
      expect(engine.notifyWriteCount, 1);
    });

    test('insertActivities stores all and enqueues each with isNew:true',
        () async {
      final activities = [
        _activity(id: 'a1'),
        _activity(id: 'a2'),
        _activity(id: 'a3'),
      ];
      await repo.insertActivities(_familyId, activities);

      expect(await StoreRefs.activities.count(db), 3);

      final pending = await queue.getPending();
      expect(pending.length, 3);
      expect(pending.every((e) => e.isNew), true);
      expect(engine.notifyWriteCount, 1);
    });

    test('updateActivity stores data and enqueues without isNew', () async {
      await repo.insertActivity(_familyId, _activity());
      engine.notifyWriteCount = 0;

      final updated = _activity(notes: 'updated');
      await repo.updateActivity(_familyId, updated);

      final record = await StoreRefs.activities.record('act-1').get(db);
      expect(record!['notes'], 'updated');

      // Queue collapses to 1 entry, but isNew preserved from insert.
      final pending = await queue.getPending();
      expect(pending.length, 1);
      expect(pending.first.isNew, true); // Preserved from original insert.

      expect(engine.notifyWriteCount, 1);
    });

    test('softDeleteActivity sets isDeleted and enqueues', () async {
      await repo.insertActivity(_familyId, _activity());
      engine.notifyWriteCount = 0;

      await repo.softDeleteActivity(_familyId, 'act-1');

      final record = await StoreRefs.activities.record('act-1').get(db);
      expect(record!['isDeleted'], true);

      final pending = await queue.getPending();
      expect(pending.length, 1);
      expect(engine.notifyWriteCount, 1);
    });

    test('getActivity returns stored activity', () async {
      await repo.insertActivity(_familyId, _activity());

      final result = await repo.getActivity(_familyId, 'act-1');
      expect(result, isNotNull);
      expect(result!.type, 'bottle_feed');
    });

    test('getActivity returns null for missing', () async {
      final result = await repo.getActivity(_familyId, 'missing');
      expect(result, isNull);
    });
  });

  group('SyncingIngredientRepository', () {
    late SyncingIngredientRepository repo;

    setUp(() {
      final local = LocalIngredientRepository(db);
      repo = SyncingIngredientRepository(local, queue, engine, db);
    });

    test('createIngredient stores data and enqueues with isNew:true',
        () async {
      await repo.createIngredient(_familyId, _ingredient());

      final record = await StoreRefs.ingredients.record('ing-1').get(db);
      expect(record, isNotNull);
      expect(record!['name'], 'egg');

      final pending = await queue.getPending();
      expect(pending.length, 1);
      expect(pending.first.collection, 'ingredients');
      expect(pending.first.isNew, true);
      expect(engine.notifyWriteCount, 1);
    });

    test('updateIngredient stores data and enqueues', () async {
      await repo.createIngredient(_familyId, _ingredient());
      engine.notifyWriteCount = 0;

      final updated = IngredientModel(
        id: 'ing-1',
        name: 'egg',
        allergens: const ['egg', 'dairy'],
        createdBy: 'user-1',
        createdAt: _now,
        modifiedAt: _now.add(const Duration(hours: 1)),
      );
      await repo.updateIngredient(_familyId, updated);

      final record = await StoreRefs.ingredients.record('ing-1').get(db);
      expect((record!['allergens'] as List).length, 2);
      expect(engine.notifyWriteCount, 1);
    });

    test('softDeleteIngredient sets isDeleted and enqueues', () async {
      await repo.createIngredient(_familyId, _ingredient());
      engine.notifyWriteCount = 0;

      await repo.softDeleteIngredient(_familyId, 'ing-1');

      final record = await StoreRefs.ingredients.record('ing-1').get(db);
      expect(record!['isDeleted'], true);
      expect(engine.notifyWriteCount, 1);
    });

    test('getIngredient returns stored ingredient', () async {
      await repo.createIngredient(_familyId, _ingredient());

      final result = await repo.getIngredient(_familyId, 'ing-1');
      expect(result, isNotNull);
      expect(result!.name, 'egg');
    });
  });

  group('SyncingRecipeRepository', () {
    late SyncingRecipeRepository repo;

    setUp(() {
      final local = LocalRecipeRepository(db);
      repo = SyncingRecipeRepository(local, queue, engine, db);
    });

    test('createRecipe stores data and enqueues with isNew:true', () async {
      await repo.createRecipe(_familyId, _recipe());

      final record = await StoreRefs.recipes.record('rec-1').get(db);
      expect(record, isNotNull);
      expect(record!['name'], 'omelette');

      final pending = await queue.getPending();
      expect(pending.length, 1);
      expect(pending.first.collection, 'recipes');
      expect(pending.first.isNew, true);
      expect(engine.notifyWriteCount, 1);
    });

    test('updateRecipe stores data and enqueues', () async {
      await repo.createRecipe(_familyId, _recipe());
      engine.notifyWriteCount = 0;

      final updated = RecipeModel(
        id: 'rec-1',
        name: 'omelette',
        ingredients: const ['egg', 'milk', 'cheese'],
        createdBy: 'user-1',
        createdAt: _now,
        modifiedAt: _now.add(const Duration(hours: 1)),
      );
      await repo.updateRecipe(_familyId, updated);

      final record = await StoreRefs.recipes.record('rec-1').get(db);
      expect((record!['ingredients'] as List).length, 3);
      expect(engine.notifyWriteCount, 1);
    });

    test('softDeleteRecipe sets isDeleted and enqueues', () async {
      await repo.createRecipe(_familyId, _recipe());
      engine.notifyWriteCount = 0;

      await repo.softDeleteRecipe(_familyId, 'rec-1');

      final record = await StoreRefs.recipes.record('rec-1').get(db);
      expect(record!['isDeleted'], true);
      expect(engine.notifyWriteCount, 1);
    });

    test('getRecipe returns stored recipe', () async {
      await repo.createRecipe(_familyId, _recipe());

      final result = await repo.getRecipe(_familyId, 'rec-1');
      expect(result, isNotNull);
      expect(result!.name, 'omelette');
    });
  });

  group('SyncingTargetRepository', () {
    late SyncingTargetRepository repo;

    setUp(() {
      final local = LocalTargetRepository(db);
      repo = SyncingTargetRepository(local, queue, engine, db);
    });

    test('createTarget stores data and enqueues with isNew:true', () async {
      await repo.createTarget(_familyId, _target());

      final record = await StoreRefs.targets.record('tgt-1').get(db);
      expect(record, isNotNull);
      expect(record!['activityType'], 'bottle_feed');

      final pending = await queue.getPending();
      expect(pending.length, 1);
      expect(pending.first.collection, 'targets');
      expect(pending.first.isNew, true);
      expect(engine.notifyWriteCount, 1);
    });

    test('updateTarget stores data and enqueues', () async {
      await repo.createTarget(_familyId, _target());
      engine.notifyWriteCount = 0;

      final updated = TargetModel(
        id: 'tgt-1',
        childId: _childId,
        activityType: 'bottle_feed',
        metric: 'count',
        period: 'daily',
        targetValue: 8,
        createdBy: 'user-1',
        createdAt: _now,
        modifiedAt: _now.add(const Duration(hours: 1)),
      );
      await repo.updateTarget(_familyId, updated);

      final record = await StoreRefs.targets.record('tgt-1').get(db);
      expect(record!['targetValue'], 8);
      expect(engine.notifyWriteCount, 1);
    });

    test('deactivateTarget sets isActive false and enqueues', () async {
      await repo.createTarget(_familyId, _target());
      engine.notifyWriteCount = 0;

      await repo.deactivateTarget(_familyId, 'tgt-1');

      final record = await StoreRefs.targets.record('tgt-1').get(db);
      expect(record!['isActive'], false);
      expect(engine.notifyWriteCount, 1);
    });
  });

  group('SyncingFamilyRepository', () {
    late SyncingFamilyRepository repo;

    setUp(() {
      final local = LocalFamilyRepository(db);
      repo = SyncingFamilyRepository(local, queue, engine, db);
    });

    test('createFamily stores data and enqueues with isNew:true', () async {
      final family = FamilyModel(
        id: _familyId,
        name: 'Test Family',
        createdBy: 'user-1',
        memberUids: const ['user-1'],
        createdAt: _now,
        modifiedAt: _now,
      );
      await repo.createFamily(family);

      final record = await StoreRefs.families.record(_familyId).get(db);
      expect(record, isNotNull);
      expect(record!['name'], 'Test Family');

      final pending = await queue.getPending();
      expect(pending.length, 1);
      expect(pending.first.collection, 'families');
      expect(pending.first.isNew, true);
      expect(engine.notifyWriteCount, 1);
    });

    test('createChild stores data and enqueues with isNew:true', () async {
      // Pre-create family.
      final family = FamilyModel(
        id: _familyId,
        name: 'Test Family',
        createdBy: 'user-1',
        memberUids: const ['user-1'],
        createdAt: _now,
        modifiedAt: _now,
      );
      await repo.createFamily(family);
      engine.notifyWriteCount = 0;

      final child = ChildModel(
        id: _childId,
        name: 'Baby',
        dateOfBirth: DateTime(2025, 6, 1),
        createdAt: _now,
        modifiedAt: _now,
      );
      await repo.createChild(_familyId, child);

      final record = await StoreRefs.children.record(_childId).get(db);
      expect(record, isNotNull);
      expect(record!['name'], 'Baby');

      final pending = await queue.getPending();
      final childEntry =
          pending.where((e) => e.collection == 'children').first;
      expect(childEntry.isNew, true);
      expect(engine.notifyWriteCount, 1);
    });

    test('createFamilyWithChild enqueues 3 entries atomically', () async {
      final family = FamilyModel(
        id: _familyId,
        name: 'Test Family',
        createdBy: 'user-1',
        memberUids: const ['user-1'],
        createdAt: _now,
        modifiedAt: _now,
      );
      final child = ChildModel(
        id: _childId,
        name: 'Baby',
        dateOfBirth: DateTime(2025, 6, 1),
        createdAt: _now,
        modifiedAt: _now,
      );
      final carer = CarerModel(
        id: 'carer-1',
        uid: 'user-1',
        displayName: 'Parent',
        role: 'parent',
        createdAt: _now,
        modifiedAt: _now,
      );

      await repo.createFamilyWithChild(
        family: family,
        child: child,
        carer: carer,
      );

      final pending = await queue.getPending();
      expect(pending.length, 3);
      final collections = pending.map((e) => e.collection).toSet();
      expect(collections, {'families', 'children', 'carers'});
      expect(pending.every((e) => e.isNew), true);
      expect(engine.notifyWriteCount, 1);
    });

    test('updateAllergenCategories enqueues family change', () async {
      final family = FamilyModel(
        id: _familyId,
        name: 'Test Family',
        createdBy: 'user-1',
        memberUids: const ['user-1'],
        createdAt: _now,
        modifiedAt: _now,
      );
      await repo.createFamily(family);
      engine.notifyWriteCount = 0;

      await repo.updateAllergenCategories(
          _familyId, ['egg', 'dairy', 'peanut']);

      final record = await StoreRefs.families.record(_familyId).get(db);
      expect((record!['allergenCategories'] as List).length, 3);
      expect(engine.notifyWriteCount, 1);
    });
  });

  group('atomic write+queue guarantee', () {
    test('queue entry uses deterministic key for collapse', () async {
      final local = LocalActivityRepository(db);
      final repo = SyncingActivityRepository(local, queue, engine, db);

      await repo.insertActivity(_familyId, _activity());
      await repo.updateActivity(_familyId, _activity(notes: 'v2'));

      // Same document → queue collapses to 1 entry.
      final pending = await queue.getPending();
      expect(pending.length, 1);
      expect(pending.first.id, 'activities_act-1');
    });

    test('multiple documents create separate queue entries', () async {
      final local = LocalActivityRepository(db);
      final repo = SyncingActivityRepository(local, queue, engine, db);

      await repo.insertActivity(_familyId, _activity(id: 'a1'));
      await repo.insertActivity(_familyId, _activity(id: 'a2'));

      final pending = await queue.getPending();
      expect(pending.length, 2);
      expect(pending.map((e) => e.documentId).toSet(), {'a1', 'a2'});
    });
  });
}
