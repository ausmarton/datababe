import 'package:flutter_test/flutter_test.dart';
import 'package:datababe/models/recipe_model.dart';

void main() {
  group('RecipeModel', () {
    test('toFirestore includes all fields', () {
      final now = DateTime(2026, 2, 27);
      final recipe = RecipeModel(
        id: 'recipe-1',
        name: 'Banana Porridge',
        ingredients: ['oats', "cow's milk", 'banana'],
        createdBy: 'uid-1',
        createdAt: now,
        modifiedAt: now,
      );

      final map = recipe.toFirestore();

      expect(map['name'], 'Banana Porridge');
      expect(map['ingredients'], ['oats', "cow's milk", 'banana']);
      expect(map['isDeleted'], false);
      expect(map['createdBy'], 'uid-1');
      expect(map.containsKey('id'), isFalse);
    });

    test('toFirestore does not include id', () {
      final now = DateTime(2026, 2, 27);
      final recipe = RecipeModel(
        id: 'recipe-1',
        name: 'Test',
        ingredients: ['egg'],
        createdBy: 'uid-1',
        createdAt: now,
        modifiedAt: now,
      );

      final map = recipe.toFirestore();
      expect(map.containsKey('id'), isFalse);
    });

    test('isDeleted defaults to false', () {
      final now = DateTime(2026, 2, 27);
      final recipe = RecipeModel(
        id: 'recipe-1',
        name: 'Test',
        ingredients: ['egg'],
        createdBy: 'uid-1',
        createdAt: now,
        modifiedAt: now,
      );

      expect(recipe.isDeleted, false);
      expect(recipe.toFirestore()['isDeleted'], false);
    });

    test('isDeleted true serializes correctly', () {
      final now = DateTime(2026, 2, 27);
      final recipe = RecipeModel(
        id: 'recipe-1',
        name: 'Deleted Recipe',
        ingredients: ['flour'],
        isDeleted: true,
        createdBy: 'uid-1',
        createdAt: now,
        modifiedAt: now,
      );

      expect(recipe.toFirestore()['isDeleted'], true);
    });

    test('empty ingredients list serializes', () {
      final now = DateTime(2026, 2, 27);
      final recipe = RecipeModel(
        id: 'recipe-1',
        name: 'Empty',
        ingredients: [],
        createdBy: 'uid-1',
        createdAt: now,
        modifiedAt: now,
      );

      expect(recipe.toFirestore()['ingredients'], []);
    });

    test('toMap/fromMap round-trip preserves all fields', () {
      final now = DateTime(2026, 2, 27, 10, 30);
      final recipe = RecipeModel(
        id: 'recipe-rt',
        name: 'banana porridge',
        ingredients: ['oats', 'banana', "cow's milk"],
        isDeleted: false,
        createdBy: 'uid-1',
        createdAt: now,
        modifiedAt: now,
      );

      final map = recipe.toMap();
      final restored = RecipeModel.fromMap('recipe-rt', map);

      expect(restored.id, recipe.id);
      expect(restored.name, recipe.name);
      expect(restored.ingredients, recipe.ingredients);
      expect(restored.isDeleted, recipe.isDeleted);
      expect(restored.createdBy, recipe.createdBy);
      expect(restored.createdAt, recipe.createdAt);
      expect(restored.modifiedAt, recipe.modifiedAt);
    });
  });
}
