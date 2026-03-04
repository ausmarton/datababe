import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import 'package:datababe/models/recipe_model.dart';
import 'package:datababe/repositories/local_recipe_repository.dart';

void main() {
  late LocalRecipeRepository repo;
  const familyId = 'fam-1';

  setUp(() async {
    final db = await newDatabaseFactoryMemory().openDatabase('test.db');
    repo = LocalRecipeRepository(db);
  });

  RecipeModel make(String id, {String name = 'porridge'}) {
    final now = DateTime(2026, 3, 1);
    return RecipeModel(
      id: id,
      name: name,
      ingredients: ['oats', 'banana'],
      createdBy: 'uid-1',
      createdAt: now,
      modifiedAt: now,
    );
  }

  test('create and watch returns recipe', () async {
    await repo.createRecipe(familyId, make('r-1'));
    final list = await repo.watchRecipes(familyId).first;
    expect(list.length, 1);
    expect(list.first.name, 'porridge');
  });

  test('getRecipe returns created recipe', () async {
    await repo.createRecipe(familyId, make('r-2'));
    final result = await repo.getRecipe(familyId, 'r-2');
    expect(result, isNotNull);
    expect(result!.ingredients, ['oats', 'banana']);
  });

  test('softDeleteRecipe hides from watch', () async {
    await repo.createRecipe(familyId, make('r-3'));
    await repo.softDeleteRecipe(familyId, 'r-3');
    final list = await repo.watchRecipes(familyId).first;
    expect(list, isEmpty);
  });

  test('updateRecipe modifies existing', () async {
    await repo.createRecipe(familyId, make('r-4'));
    final now = DateTime(2026, 3, 1);
    await repo.updateRecipe(
      familyId,
      RecipeModel(
        id: 'r-4',
        name: 'updated porridge',
        ingredients: ['oats', 'banana', 'milk'],
        createdBy: 'uid-1',
        createdAt: now,
        modifiedAt: now,
      ),
    );
    final result = await repo.getRecipe(familyId, 'r-4');
    expect(result!.name, 'updated porridge');
    expect(result.ingredients.length, 3);
  });
}
