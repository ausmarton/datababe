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

  group('RecipeModel.fromMap edge cases', () {
    test('happy path — all fields present', () {
      final map = {
        'name': 'scrambled eggs',
        'ingredients': ['egg', 'butter'],
        'isDeleted': false,
        'createdBy': 'uid-42',
        'createdAt': '2026-03-01T09:00:00.000',
        'modifiedAt': '2026-03-02T14:30:00.000',
      };

      final recipe = RecipeModel.fromMap('r-1', map);

      expect(recipe.id, 'r-1');
      expect(recipe.name, 'scrambled eggs');
      expect(recipe.ingredients, ['egg', 'butter']);
      expect(recipe.isDeleted, false);
      expect(recipe.createdBy, 'uid-42');
      expect(recipe.createdAt, DateTime.parse('2026-03-01T09:00:00.000'));
      expect(recipe.modifiedAt, DateTime.parse('2026-03-02T14:30:00.000'));
    });

    test('missing name defaults to empty string', () {
      final recipe = RecipeModel.fromMap('r-2', {
        'ingredients': ['flour'],
        'createdAt': '2026-03-01T09:00:00.000',
        'modifiedAt': '2026-03-01T09:00:00.000',
      });

      expect(recipe.name, '');
    });

    test('null name defaults to empty string', () {
      final recipe = RecipeModel.fromMap('r-2b', {
        'name': null,
        'createdAt': '2026-03-01T09:00:00.000',
      });

      expect(recipe.name, '');
    });

    test('missing ingredients defaults to empty list', () {
      final recipe = RecipeModel.fromMap('r-3', {
        'name': 'toast',
        'createdAt': '2026-03-01T09:00:00.000',
        'modifiedAt': '2026-03-01T09:00:00.000',
      });

      expect(recipe.ingredients, isEmpty);
    });

    test('null ingredients defaults to empty list', () {
      final recipe = RecipeModel.fromMap('r-3b', {
        'name': 'toast',
        'ingredients': null,
        'createdAt': '2026-03-01T09:00:00.000',
      });

      expect(recipe.ingredients, isEmpty);
    });

    test('missing isDeleted defaults to false', () {
      final recipe = RecipeModel.fromMap('r-4', {
        'name': 'porridge',
        'createdAt': '2026-03-01T09:00:00.000',
        'modifiedAt': '2026-03-01T09:00:00.000',
      });

      expect(recipe.isDeleted, false);
    });

    test('null isDeleted defaults to false', () {
      final recipe = RecipeModel.fromMap('r-4b', {
        'name': 'porridge',
        'isDeleted': null,
        'createdAt': '2026-03-01T09:00:00.000',
      });

      expect(recipe.isDeleted, false);
    });

    test('missing createdAt defaults to approximately now', () {
      final before = DateTime.now();
      final recipe = RecipeModel.fromMap('r-5', {
        'name': 'soup',
      });
      final after = DateTime.now();

      expect(recipe.createdAt.isAfter(before.subtract(Duration(seconds: 1))),
          isTrue);
      expect(
          recipe.createdAt.isBefore(after.add(Duration(seconds: 1))), isTrue);
    });

    test('null createdAt defaults to approximately now', () {
      final before = DateTime.now();
      final recipe = RecipeModel.fromMap('r-5b', {
        'name': 'soup',
        'createdAt': null,
      });
      final after = DateTime.now();

      expect(recipe.createdAt.isAfter(before.subtract(Duration(seconds: 1))),
          isTrue);
      expect(
          recipe.createdAt.isBefore(after.add(Duration(seconds: 1))), isTrue);
    });

    test('missing modifiedAt defaults to createdAt', () {
      final recipe = RecipeModel.fromMap('r-6', {
        'name': 'pasta',
        'createdAt': '2026-03-01T09:00:00.000',
      });

      expect(recipe.modifiedAt, DateTime.parse('2026-03-01T09:00:00.000'));
      expect(recipe.modifiedAt, recipe.createdAt);
    });

    test('null modifiedAt defaults to createdAt', () {
      final recipe = RecipeModel.fromMap('r-6b', {
        'name': 'pasta',
        'createdAt': '2026-03-01T09:00:00.000',
        'modifiedAt': null,
      });

      expect(recipe.modifiedAt, recipe.createdAt);
    });

    test('empty ingredients list preserved', () {
      final recipe = RecipeModel.fromMap('r-7', {
        'name': 'water',
        'ingredients': [],
        'createdAt': '2026-03-01T09:00:00.000',
        'modifiedAt': '2026-03-01T09:00:00.000',
      });

      expect(recipe.ingredients, isEmpty);
      expect(recipe.ingredients, isA<List<String>>());
    });

    test('missing createdBy defaults to empty string', () {
      final recipe = RecipeModel.fromMap('r-8', {
        'name': 'rice',
        'createdAt': '2026-03-01T09:00:00.000',
      });

      expect(recipe.createdBy, '');
    });

    test('completely empty map does not crash', () {
      final recipe = RecipeModel.fromMap('r-9', {});

      expect(recipe.id, 'r-9');
      expect(recipe.name, '');
      expect(recipe.ingredients, isEmpty);
      expect(recipe.isDeleted, false);
      expect(recipe.createdBy, '');
    });

    test('round-trip with isDeleted true', () {
      final now = DateTime(2026, 3, 10, 12, 0);
      final original = RecipeModel(
        id: 'r-del',
        name: 'old recipe',
        ingredients: ['salt', 'pepper'],
        isDeleted: true,
        createdBy: 'uid-99',
        createdAt: now,
        modifiedAt: now,
      );

      final restored = RecipeModel.fromMap('r-del', original.toMap());

      expect(restored.isDeleted, true);
      expect(restored.name, 'old recipe');
      expect(restored.ingredients, ['salt', 'pepper']);
      expect(restored.createdBy, 'uid-99');
    });

    test('round-trip with different createdAt and modifiedAt', () {
      final created = DateTime(2026, 1, 15, 8, 0);
      final modified = DateTime(2026, 3, 10, 16, 45);
      final original = RecipeModel(
        id: 'r-ts',
        name: 'evolving recipe',
        ingredients: ['flour', 'sugar', 'egg'],
        createdBy: 'uid-1',
        createdAt: created,
        modifiedAt: modified,
      );

      final restored = RecipeModel.fromMap('r-ts', original.toMap());

      expect(restored.createdAt, created);
      expect(restored.modifiedAt, modified);
      expect(restored.createdAt != restored.modifiedAt, isTrue);
    });
  });
}
