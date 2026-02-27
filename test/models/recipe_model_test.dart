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
  });
}
