import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import 'package:datababe/local/store_refs.dart';
import 'package:datababe/repositories/local_family_repository.dart';

void main() {
  late LocalFamilyRepository repo;
  late Database db;
  const familyId = 'fam-1';
  final baseTime = DateTime(2026, 3, 1);

  setUp(() async {
    db = await newDatabaseFactoryMemory().openDatabase('test.db');
    repo = LocalFamilyRepository(db);

    // Seed family with allergen categories.
    await StoreRefs.families.record(familyId).put(db, {
      'name': 'Test Family',
      'createdBy': 'uid-1',
      'memberUids': ['uid-1'],
      'allergenCategories': ['dairy', 'nuts', 'gluten'],
      'createdAt': baseTime.toIso8601String(),
      'modifiedAt': baseTime.toIso8601String(),
    });
  });

  Future<void> addIngredient(String id,
      {required String name, List<String> allergens = const []}) async {
    await StoreRefs.ingredients.record(id).put(db, {
      'name': name,
      'allergens': allergens,
      'isDeleted': false,
      'createdBy': 'uid-1',
      'createdAt': baseTime.toIso8601String(),
      'modifiedAt': baseTime.toIso8601String(),
      'familyId': familyId,
    });
  }

  Future<void> addTarget(String id, {String? allergenName}) async {
    await StoreRefs.targets.record(id).put(db, {
      'childId': 'child-1',
      'activityType': 'solids',
      'metric': 'allergenExposures',
      'period': 'daily',
      'targetValue': 1.0,
      'isActive': true,
      'allergenName': ?allergenName,
      'isDeleted': false,
      'createdBy': 'uid-1',
      'createdAt': baseTime.toIso8601String(),
      'modifiedAt': baseTime.toIso8601String(),
      'familyId': familyId,
    });
  }

  Future<void> addActivity(String id,
      {List<String>? allergenNames, String family = familyId}) async {
    await StoreRefs.activities.record(id).put(db, {
      'childId': 'child-1',
      'type': 'solids',
      'startTime': baseTime.toIso8601String(),
      'createdAt': baseTime.toIso8601String(),
      'modifiedAt': baseTime.toIso8601String(),
      'isDeleted': false,
      'familyId': family,
      'allergenNames': ?allergenNames,
    });
  }

  group('renameAllergenCategory', () {
    test('updates family allergenCategories list', () async {
      final changes =
          await repo.renameAllergenCategory(familyId, 'dairy', 'lactose');

      final family = await StoreRefs.families.record(familyId).get(db);
      final categories =
          List<String>.from(family!['allergenCategories'] as List);
      expect(categories, contains('lactose'));
      expect(categories, isNot(contains('dairy')));
      expect(changes, isNotNull);
    });

    test('updates ingredient allergen lists', () async {
      await addIngredient('i-1', name: 'milk', allergens: ['dairy']);
      await addIngredient('i-2', name: 'cheese', allergens: ['dairy', 'nuts']);

      final changes =
          await repo.renameAllergenCategory(familyId, 'dairy', 'lactose');

      final milk = await StoreRefs.ingredients.record('i-1').get(db);
      expect(List<String>.from(milk!['allergens'] as List), ['lactose']);

      final cheese = await StoreRefs.ingredients.record('i-2').get(db);
      expect(
          List<String>.from(cheese!['allergens'] as List), ['lactose', 'nuts']);

      expect(changes,
          containsAll([
            (collection: 'ingredients', documentId: 'i-1'),
            (collection: 'ingredients', documentId: 'i-2'),
          ]));
    });

    test('updates target allergenName', () async {
      await addTarget('t-1', allergenName: 'dairy');

      final changes =
          await repo.renameAllergenCategory(familyId, 'dairy', 'lactose');

      final target = await StoreRefs.targets.record('t-1').get(db);
      expect(target!['allergenName'], 'lactose');
      expect(changes,
          contains((collection: 'targets', documentId: 't-1')));
    });

    test('updates activity allergenNames', () async {
      await addActivity('a-1', allergenNames: ['dairy', 'nuts']);

      final changes =
          await repo.renameAllergenCategory(familyId, 'dairy', 'lactose');

      final activity = await StoreRefs.activities.record('a-1').get(db);
      expect(List<String>.from(activity!['allergenNames'] as List),
          ['lactose', 'nuts']);
      expect(changes,
          contains((collection: 'activities', documentId: 'a-1')));
    });

    test('does not affect unrelated items', () async {
      await addIngredient('i-1', name: 'almond', allergens: ['nuts']);
      await addTarget('t-1', allergenName: 'gluten');
      await addActivity('a-1', allergenNames: ['gluten']);

      final changes =
          await repo.renameAllergenCategory(familyId, 'dairy', 'lactose');

      final ingredient = await StoreRefs.ingredients.record('i-1').get(db);
      expect(List<String>.from(ingredient!['allergens'] as List), ['nuts']);

      final target = await StoreRefs.targets.record('t-1').get(db);
      expect(target!['allergenName'], 'gluten');

      final activity = await StoreRefs.activities.record('a-1').get(db);
      expect(
          List<String>.from(activity!['allergenNames'] as List), ['gluten']);

      expect(changes.where((c) => c.documentId == 'i-1'), isEmpty);
      expect(changes.where((c) => c.documentId == 't-1'), isEmpty);
      expect(changes.where((c) => c.documentId == 'a-1'), isEmpty);
    });

    test('returns correct change list', () async {
      await addIngredient('i-1', name: 'milk', allergens: ['dairy']);
      await addTarget('t-1', allergenName: 'dairy');
      await addActivity('a-1', allergenNames: ['dairy']);

      final changes =
          await repo.renameAllergenCategory(familyId, 'dairy', 'lactose');

      expect(changes.length, 3);
      expect(
          changes,
          containsAll([
            (collection: 'ingredients', documentId: 'i-1'),
            (collection: 'targets', documentId: 't-1'),
            (collection: 'activities', documentId: 'a-1'),
          ]));
    });
  });

  group('removeAllergenCategory', () {
    test('removes from family allergenCategories', () async {
      await repo.removeAllergenCategory(familyId, 'dairy');

      final family = await StoreRefs.families.record(familyId).get(db);
      final categories =
          List<String>.from(family!['allergenCategories'] as List);
      expect(categories, isNot(contains('dairy')));
      expect(categories, containsAll(['nuts', 'gluten']));
    });

    test('removes from ingredient allergen lists', () async {
      await addIngredient('i-1', name: 'milk', allergens: ['dairy', 'nuts']);

      await repo.removeAllergenCategory(familyId, 'dairy');

      final ingredient = await StoreRefs.ingredients.record('i-1').get(db);
      expect(List<String>.from(ingredient!['allergens'] as List), ['nuts']);
    });

    test('deactivates matching targets', () async {
      await addTarget('t-1', allergenName: 'dairy');

      final changes =
          await repo.removeAllergenCategory(familyId, 'dairy');

      final target = await StoreRefs.targets.record('t-1').get(db);
      expect(target!['isActive'], false);
      expect(changes,
          contains((collection: 'targets', documentId: 't-1')));
    });

    test('removes from activity allergenNames', () async {
      await addActivity('a-1', allergenNames: ['dairy', 'nuts']);

      await repo.removeAllergenCategory(familyId, 'dairy');

      final activity = await StoreRefs.activities.record('a-1').get(db);
      expect(
          List<String>.from(activity!['allergenNames'] as List), ['nuts']);
    });

    test('does not affect unrelated items', () async {
      await addIngredient('i-1', name: 'almond', allergens: ['nuts']);
      await addTarget('t-1', allergenName: 'gluten');
      await addActivity('a-1', allergenNames: ['gluten']);

      final changes =
          await repo.removeAllergenCategory(familyId, 'dairy');

      final ingredient = await StoreRefs.ingredients.record('i-1').get(db);
      expect(List<String>.from(ingredient!['allergens'] as List), ['nuts']);

      final target = await StoreRefs.targets.record('t-1').get(db);
      expect(target!['isActive'], true);

      expect(changes.where((c) => c.documentId == 'i-1'), isEmpty);
      expect(changes.where((c) => c.documentId == 't-1'), isEmpty);
      expect(changes.where((c) => c.documentId == 'a-1'), isEmpty);
    });

    test('returns correct change list', () async {
      await addIngredient('i-1', name: 'milk', allergens: ['dairy']);
      await addTarget('t-1', allergenName: 'dairy');
      await addActivity('a-1', allergenNames: ['dairy']);

      final changes =
          await repo.removeAllergenCategory(familyId, 'dairy');

      expect(changes.length, 3);
      expect(
          changes,
          containsAll([
            (collection: 'ingredients', documentId: 'i-1'),
            (collection: 'targets', documentId: 't-1'),
            (collection: 'activities', documentId: 'a-1'),
          ]));
    });
  });
}
