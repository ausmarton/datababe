import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import 'package:datababe/models/ingredient_model.dart';
import 'package:datababe/repositories/local_ingredient_repository.dart';

void main() {
  late LocalIngredientRepository repo;
  const familyId = 'fam-1';

  setUp(() async {
    final db = await newDatabaseFactoryMemory().openDatabase('test.db');
    repo = LocalIngredientRepository(db);
  });

  IngredientModel make(String id, {String name = 'egg', List<String> allergens = const []}) {
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

  test('create and watch returns ingredient', () async {
    await repo.createIngredient(familyId, make('ing-1'));
    final list = await repo.watchIngredients(familyId).first;
    expect(list.length, 1);
    expect(list.first.name, 'egg');
  });

  test('getIngredient returns created ingredient', () async {
    await repo.createIngredient(familyId, make('ing-2'));
    final result = await repo.getIngredient(familyId, 'ing-2');
    expect(result, isNotNull);
    expect(result!.id, 'ing-2');
  });

  test('softDeleteIngredient hides from watch', () async {
    await repo.createIngredient(familyId, make('ing-3'));
    await repo.softDeleteIngredient(familyId, 'ing-3');
    final list = await repo.watchIngredients(familyId).first;
    expect(list, isEmpty);
  });

  test('updateIngredient modifies existing', () async {
    await repo.createIngredient(familyId, make('ing-4'));
    final now = DateTime(2026, 3, 1);
    await repo.updateIngredient(
      familyId,
      IngredientModel(
        id: 'ing-4',
        name: 'cheese',
        allergens: ['lactose'],
        createdBy: 'uid-1',
        createdAt: now,
        modifiedAt: now,
      ),
    );
    final result = await repo.getIngredient(familyId, 'ing-4');
    expect(result!.name, 'cheese');
    expect(result.allergens, ['lactose']);
  });
}
