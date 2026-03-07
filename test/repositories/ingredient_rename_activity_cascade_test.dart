import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import 'package:datababe/local/store_refs.dart';
import 'package:datababe/models/ingredient_model.dart';
import 'package:datababe/repositories/local_ingredient_repository.dart';

void main() {
  late LocalIngredientRepository repo;
  late Database db;
  const familyId = 'fam-1';
  final baseTime = DateTime(2026, 3, 1);

  setUp(() async {
    db = await newDatabaseFactoryMemory().openDatabase('test.db');
    repo = LocalIngredientRepository(db);
  });

  IngredientModel make(String id,
      {String name = 'egg', List<String> allergens = const []}) {
    return IngredientModel(
      id: id,
      name: name,
      allergens: allergens,
      createdBy: 'uid-1',
      createdAt: baseTime,
      modifiedAt: baseTime,
    );
  }

  Future<void> addActivity(String id,
      {List<String>? ingredientNames,
      List<String>? allergenNames,
      String family = familyId}) async {
    await StoreRefs.activities.record(id).put(db, {
      'childId': 'child-1',
      'type': 'solids',
      'startTime': baseTime.toIso8601String(),
      'createdAt': baseTime.toIso8601String(),
      'modifiedAt': baseTime.toIso8601String(),
      'isDeleted': false,
      'familyId': family,
      if (ingredientNames != null) 'ingredientNames': ingredientNames,
      if (allergenNames != null) 'allergenNames': allergenNames,
    });
  }

  test('updates ingredientNames in activities containing old name', () async {
    await repo.createIngredient(familyId, make('ing-1', name: 'cod'));
    await addActivity('act-1', ingredientNames: ['cod', 'potato']);

    final renamed = make('ing-1', name: 'haddock');
    await repo.renameIngredient(familyId, renamed, 'cod');

    final activity = await StoreRefs.activities.record('act-1').get(db);
    expect(activity!['ingredientNames'], ['haddock', 'potato']);
  });

  test('recomputes allergenNames after rename', () async {
    await repo.createIngredient(
        familyId, make('ing-1', name: 'cod', allergens: ['fish']));
    await addActivity('act-1',
        ingredientNames: ['cod'], allergenNames: ['fish']);

    final renamed = make('ing-1', name: 'haddock', allergens: ['fish']);
    await repo.renameIngredient(familyId, renamed, 'cod');

    final activity = await StoreRefs.activities.record('act-1').get(db);
    expect(activity!['ingredientNames'], ['haddock']);
    expect(activity['allergenNames'], ['fish']);
  });

  test('does not affect activities without old ingredient', () async {
    await repo.createIngredient(familyId, make('ing-1', name: 'cod'));
    await addActivity('act-1', ingredientNames: ['potato', 'carrot']);

    final renamed = make('ing-1', name: 'haddock');
    final changes = await repo.renameIngredient(familyId, renamed, 'cod');

    final activity = await StoreRefs.activities.record('act-1').get(db);
    expect(activity!['ingredientNames'], ['potato', 'carrot']);
    expect(changes.where((c) => c.documentId == 'act-1'), isEmpty);
  });

  test('does not affect activities in other families', () async {
    await repo.createIngredient(familyId, make('ing-1', name: 'cod'));
    await addActivity('act-other',
        ingredientNames: ['cod'], family: 'fam-2');

    final renamed = make('ing-1', name: 'haddock');
    await repo.renameIngredient(familyId, renamed, 'cod');

    final activity = await StoreRefs.activities.record('act-other').get(db);
    expect(activity!['ingredientNames'], ['cod']);
  });

  test('returns activity changes in change list', () async {
    await repo.createIngredient(familyId, make('ing-1', name: 'cod'));
    await addActivity('act-1', ingredientNames: ['cod']);
    await addActivity('act-2', ingredientNames: ['cod', 'potato']);

    final renamed = make('ing-1', name: 'haddock');
    final changes = await repo.renameIngredient(familyId, renamed, 'cod');

    expect(
        changes,
        containsAll([
          (collection: 'activities', documentId: 'act-1'),
          (collection: 'activities', documentId: 'act-2'),
        ]));
  });

  test('handles activities with null ingredientNames', () async {
    await repo.createIngredient(familyId, make('ing-1', name: 'cod'));
    await addActivity('act-1'); // no ingredientNames

    final renamed = make('ing-1', name: 'haddock');
    final changes = await repo.renameIngredient(familyId, renamed, 'cod');

    final activity = await StoreRefs.activities.record('act-1').get(db);
    expect(activity!['ingredientNames'], isNull);
    expect(changes.where((c) => c.documentId == 'act-1'), isEmpty);
  });
}
