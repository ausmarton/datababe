import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import 'package:datababe/models/recipe_model.dart';
import 'package:datababe/repositories/duplicate_name_exception.dart';
import 'package:datababe/repositories/local_recipe_repository.dart';

void main() {
  late LocalRecipeRepository repo;
  late Database db;
  const familyId = 'fam-1';

  setUp(() async {
    db = await newDatabaseFactoryMemory().openDatabase('test.db');
    repo = LocalRecipeRepository(db);
  });

  RecipeModel make(String id,
      {String name = 'omelette', List<String> ingredients = const ['egg']}) {
    final now = DateTime(2026, 3, 1);
    return RecipeModel(
      id: id,
      name: name,
      ingredients: ingredients,
      createdBy: 'uid-1',
      createdAt: now,
      modifiedAt: now,
    );
  }

  test('createRecipe throws on duplicate name+familyId', () async {
    await repo.createRecipe(familyId, make('r-1', name: 'omelette'));
    expect(
      () => repo.createRecipe(familyId, make('r-2', name: 'omelette')),
      throwsA(isA<DuplicateNameException>()),
    );
  });

  test('createRecipe allows same name in different family', () async {
    await repo.createRecipe('fam-1', make('r-1', name: 'omelette'));
    await repo.createRecipe('fam-2', make('r-2', name: 'omelette'));
    final list1 = await repo.watchRecipes('fam-1').first;
    final list2 = await repo.watchRecipes('fam-2').first;
    expect(list1.length, 1);
    expect(list2.length, 1);
  });

  test('createRecipe allows same name when existing is soft-deleted', () async {
    await repo.createRecipe(familyId, make('r-1', name: 'omelette'));
    await repo.softDeleteRecipe(familyId, 'r-1');
    await repo.createRecipe(familyId, make('r-2', name: 'omelette'));
    final list = await repo.watchRecipes(familyId).first;
    expect(list.length, 1);
    expect(list.first.id, 'r-2');
  });

  test('updateRecipe throws on name collision (excluding self)', () async {
    await repo.createRecipe(familyId, make('r-1', name: 'omelette'));
    await repo.createRecipe(familyId, make('r-2', name: 'pancake'));
    expect(
      () => repo.updateRecipe(familyId, make('r-2', name: 'omelette')),
      throwsA(isA<DuplicateNameException>()),
    );
  });

  test('updateRecipe allows update without name change', () async {
    await repo.createRecipe(
        familyId, make('r-1', name: 'omelette', ingredients: ['egg']));
    await repo.updateRecipe(
        familyId, make('r-1', name: 'omelette', ingredients: ['egg', 'milk']));
    final result = await repo.getRecipe(familyId, 'r-1');
    expect(result!.ingredients, ['egg', 'milk']);
  });
}
