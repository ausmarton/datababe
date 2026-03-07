import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import 'package:datababe/local/store_refs.dart';
import 'package:datababe/utils/dedup_helper.dart';

void main() {
  late Database db;
  late DedupHelper helper;
  const familyId = 'fam-1';
  final t1 = DateTime(2026, 3, 1);
  final t2 = DateTime(2026, 3, 2);

  setUp(() async {
    db = await newDatabaseFactoryMemory().openDatabase('test.db');
    helper = DedupHelper(db);
  });

  Map<String, dynamic> makeIngredient(String name,
      {List<String> allergens = const [],
      DateTime? createdAt,
      bool isDeleted = false}) {
    final ca = createdAt ?? t1;
    return {
      'name': name,
      'allergens': allergens,
      'isDeleted': isDeleted,
      'createdBy': 'uid-1',
      'createdAt': ca.toIso8601String(),
      'modifiedAt': ca.toIso8601String(),
      'familyId': familyId,
    };
  }

  Map<String, dynamic> makeRecipe(String name,
      {List<String> ingredients = const [],
      DateTime? createdAt,
      bool isDeleted = false}) {
    final ca = createdAt ?? t1;
    return {
      'name': name,
      'ingredients': ingredients,
      'isDeleted': isDeleted,
      'createdBy': 'uid-1',
      'createdAt': ca.toIso8601String(),
      'modifiedAt': ca.toIso8601String(),
      'familyId': familyId,
    };
  }

  group('dedupIngredients', () {
    test('no duplicates returns empty', () async {
      await StoreRefs.ingredients
          .record('i-1')
          .put(db, makeIngredient('egg'));
      await StoreRefs.ingredients
          .record('i-2')
          .put(db, makeIngredient('milk'));

      final result = await helper.dedupIngredients(familyId);
      expect(result, isEmpty);
    });

    test('keeps oldest, soft-deletes rest', () async {
      await StoreRefs.ingredients
          .record('i-1')
          .put(db, makeIngredient('egg', createdAt: t1));
      await StoreRefs.ingredients
          .record('i-2')
          .put(db, makeIngredient('egg', createdAt: t2));

      final result = await helper.dedupIngredients(familyId);
      expect(result, ['i-2']);

      final kept = await StoreRefs.ingredients.record('i-1').get(db);
      expect(kept!['isDeleted'], false);

      final deleted = await StoreRefs.ingredients.record('i-2').get(db);
      expect(deleted!['isDeleted'], true);
    });

    test('merges allergens into keeper', () async {
      await StoreRefs.ingredients
          .record('i-1')
          .put(db, makeIngredient('egg', allergens: ['egg'], createdAt: t1));
      await StoreRefs.ingredients
          .record('i-2')
          .put(db, makeIngredient('egg', allergens: ['dairy'], createdAt: t2));

      await helper.dedupIngredients(familyId);

      final kept = await StoreRefs.ingredients.record('i-1').get(db);
      final allergens = List<String>.from(kept!['allergens'] as List);
      expect(allergens, containsAll(['dairy', 'egg']));
    });

    test('does not affect different families', () async {
      await StoreRefs.ingredients
          .record('i-1')
          .put(db, makeIngredient('egg', createdAt: t1));
      final otherFamily = Map<String, dynamic>.from(
          makeIngredient('egg', createdAt: t2));
      otherFamily['familyId'] = 'fam-2';
      await StoreRefs.ingredients.record('i-2').put(db, otherFamily);

      final result = await helper.dedupIngredients(familyId);
      expect(result, isEmpty);
    });

    test('does not affect soft-deleted records', () async {
      await StoreRefs.ingredients
          .record('i-1')
          .put(db, makeIngredient('egg', createdAt: t1));
      await StoreRefs.ingredients
          .record('i-2')
          .put(db, makeIngredient('egg', createdAt: t2, isDeleted: true));

      final result = await helper.dedupIngredients(familyId);
      expect(result, isEmpty);
    });
  });

  group('dedupRecipes', () {
    test('keeps oldest, soft-deletes rest', () async {
      await StoreRefs.recipes
          .record('r-1')
          .put(db, makeRecipe('omelette', ingredients: ['egg'], createdAt: t1));
      await StoreRefs.recipes
          .record('r-2')
          .put(db, makeRecipe('omelette', ingredients: ['milk'], createdAt: t2));

      final result = await helper.dedupRecipes(familyId);
      expect(result, ['r-2']);

      final kept = await StoreRefs.recipes.record('r-1').get(db);
      expect(kept!['isDeleted'], false);

      final deleted = await StoreRefs.recipes.record('r-2').get(db);
      expect(deleted!['isDeleted'], true);
    });

    test('merges ingredient lists into keeper', () async {
      await StoreRefs.recipes
          .record('r-1')
          .put(db, makeRecipe('omelette', ingredients: ['egg'], createdAt: t1));
      await StoreRefs.recipes.record('r-2').put(
          db, makeRecipe('omelette', ingredients: ['milk'], createdAt: t2));

      await helper.dedupRecipes(familyId);

      final kept = await StoreRefs.recipes.record('r-1').get(db);
      final ingredients = List<String>.from(kept!['ingredients'] as List);
      expect(ingredients, containsAll(['egg', 'milk']));
    });
  });
}
