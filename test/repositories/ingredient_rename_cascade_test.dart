import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import 'package:datababe/local/store_refs.dart';
import 'package:datababe/models/ingredient_model.dart';
import 'package:datababe/repositories/duplicate_name_exception.dart';
import 'package:datababe/repositories/local_ingredient_repository.dart';

void main() {
  late LocalIngredientRepository repo;
  late Database db;
  const familyId = 'fam-1';

  setUp(() async {
    db = await newDatabaseFactoryMemory().openDatabase('test.db');
    repo = LocalIngredientRepository(db);
  });

  IngredientModel make(String id,
      {String name = 'egg', List<String> allergens = const []}) {
    final now = DateTime(2026, 3, 1);
    return IngredientModel(
      id: id,
      name: name,
      allergens: allergens,
      createdBy: 'uid-1',
      createdAt: now,
      modifiedAt: now,
    );
  }

  Future<void> addRecipe(String id, String name, List<String> ingredients) async {
    await StoreRefs.recipes.record(id).put(db, {
      'name': name,
      'ingredients': ingredients,
      'isDeleted': false,
      'createdBy': 'uid-1',
      'createdAt': DateTime(2026, 3, 1).toIso8601String(),
      'modifiedAt': DateTime(2026, 3, 1).toIso8601String(),
      'familyId': familyId,
    });
  }

  Future<void> addTarget(String id,
      {required String ingredientName}) async {
    await StoreRefs.targets.record(id).put(db, {
      'childId': 'child-1',
      'activityType': 'solids',
      'metric': 'ingredientExposures',
      'period': 'daily',
      'targetValue': 1.0,
      'isActive': true,
      'ingredientName': ingredientName,
      'isDeleted': false,
      'createdBy': 'uid-1',
      'createdAt': DateTime(2026, 3, 1).toIso8601String(),
      'modifiedAt': DateTime(2026, 3, 1).toIso8601String(),
      'familyId': familyId,
    });
  }

  test('renameIngredient updates recipes containing old name', () async {
    await repo.createIngredient(familyId, make('ing-1', name: 'cod'));
    await addRecipe('r-1', 'fish pie', ['cod', 'potato']);

    final renamed = make('ing-1', name: 'haddock');
    final changes = await repo.renameIngredient(familyId, renamed, 'cod');

    // Recipe should be updated.
    final recipe = await StoreRefs.recipes.record('r-1').get(db);
    expect(recipe!['ingredients'], ['haddock', 'potato']);

    // Should report the recipe as a cascaded change.
    expect(changes, contains((collection: 'recipes', documentId: 'r-1')));
  });

  test('renameIngredient updates targets with matching ingredientName',
      () async {
    await repo.createIngredient(familyId, make('ing-1', name: 'cod'));
    await addTarget('t-1', ingredientName: 'cod');

    final renamed = make('ing-1', name: 'haddock');
    final changes = await repo.renameIngredient(familyId, renamed, 'cod');

    final target = await StoreRefs.targets.record('t-1').get(db);
    expect(target!['ingredientName'], 'haddock');
    expect(changes, contains((collection: 'targets', documentId: 't-1')));
  });

  test('renameIngredient does not affect unrelated recipes', () async {
    await repo.createIngredient(familyId, make('ing-1', name: 'cod'));
    await addRecipe('r-1', 'fish pie', ['cod', 'potato']);
    await addRecipe('r-2', 'salad', ['tomato', 'lettuce']);

    final renamed = make('ing-1', name: 'haddock');
    final changes = await repo.renameIngredient(familyId, renamed, 'cod');

    // Unrelated recipe should not change.
    final salad = await StoreRefs.recipes.record('r-2').get(db);
    expect(salad!['ingredients'], ['tomato', 'lettuce']);

    // Should not report unrelated recipe.
    expect(changes.where((c) => c.documentId == 'r-2'), isEmpty);
  });

  test('renameIngredient throws on name collision', () async {
    await repo.createIngredient(familyId, make('ing-1', name: 'cod'));
    await repo.createIngredient(familyId, make('ing-2', name: 'salmon'));

    final renamed = make('ing-1', name: 'salmon');
    expect(
      () => repo.renameIngredient(familyId, renamed, 'cod'),
      throwsA(isA<DuplicateNameException>()),
    );
  });

  test('renameIngredient returns correct changed doc list', () async {
    await repo.createIngredient(familyId, make('ing-1', name: 'cod'));
    await addRecipe('r-1', 'fish pie', ['cod']);
    await addRecipe('r-2', 'fish tacos', ['cod', 'tortilla']);
    await addTarget('t-1', ingredientName: 'cod');

    final renamed = make('ing-1', name: 'haddock');
    final changes = await repo.renameIngredient(familyId, renamed, 'cod');

    expect(changes.length, 3);
    expect(changes, containsAll([
      (collection: 'recipes', documentId: 'r-1'),
      (collection: 'recipes', documentId: 'r-2'),
      (collection: 'targets', documentId: 't-1'),
    ]));
  });

  test('renameIngredient does not affect recipes in other families', () async {
    await repo.createIngredient(familyId, make('ing-1', name: 'cod'));
    // Recipe in a different family.
    await StoreRefs.recipes.record('r-other').put(db, {
      'name': 'other fish',
      'ingredients': ['cod'],
      'isDeleted': false,
      'createdBy': 'uid-1',
      'createdAt': DateTime(2026, 3, 1).toIso8601String(),
      'modifiedAt': DateTime(2026, 3, 1).toIso8601String(),
      'familyId': 'fam-2',
    });

    final renamed = make('ing-1', name: 'haddock');
    final changes = await repo.renameIngredient(familyId, renamed, 'cod');

    // Other family's recipe should not change.
    final otherRecipe = await StoreRefs.recipes.record('r-other').get(db);
    expect(otherRecipe!['ingredients'], ['cod']);
    expect(changes.where((c) => c.documentId == 'r-other'), isEmpty);
  });
}
