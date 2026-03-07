import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

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
      {String name = 'egg',
      List<String> allergens = const [],
      bool isDeleted = false}) {
    final now = DateTime(2026, 3, 1);
    return IngredientModel(
      id: id,
      name: name,
      allergens: allergens,
      isDeleted: isDeleted,
      createdBy: 'uid-1',
      createdAt: now,
      modifiedAt: now,
    );
  }

  test('createIngredient throws on duplicate name+familyId', () async {
    await repo.createIngredient(familyId, make('ing-1', name: 'cod'));
    expect(
      () => repo.createIngredient(familyId, make('ing-2', name: 'cod')),
      throwsA(isA<DuplicateNameException>()),
    );
  });

  test('createIngredient allows same name in different family', () async {
    await repo.createIngredient('fam-1', make('ing-1', name: 'cod'));
    await repo.createIngredient('fam-2', make('ing-2', name: 'cod'));
    // No exception — different families.
    final list1 = await repo.watchIngredients('fam-1').first;
    final list2 = await repo.watchIngredients('fam-2').first;
    expect(list1.length, 1);
    expect(list2.length, 1);
  });

  test('createIngredient allows same name when existing is soft-deleted',
      () async {
    await repo.createIngredient(familyId, make('ing-1', name: 'cod'));
    await repo.softDeleteIngredient(familyId, 'ing-1');
    // Should succeed — soft-deleted ingredient shouldn't block.
    await repo.createIngredient(familyId, make('ing-2', name: 'cod'));
    final list = await repo.watchIngredients(familyId).first;
    expect(list.length, 1);
    expect(list.first.id, 'ing-2');
  });

  test('updateIngredient throws on name collision (excluding self)', () async {
    await repo.createIngredient(familyId, make('ing-1', name: 'cod'));
    await repo.createIngredient(familyId, make('ing-2', name: 'salmon'));
    expect(
      () => repo.updateIngredient(familyId, make('ing-2', name: 'cod')),
      throwsA(isA<DuplicateNameException>()),
    );
  });

  test('updateIngredient allows update without name change (no self-collision)',
      () async {
    await repo.createIngredient(
        familyId, make('ing-1', name: 'cod', allergens: []));
    // Update allergens only, same name — should not throw.
    await repo.updateIngredient(
        familyId, make('ing-1', name: 'cod', allergens: ['fish']));
    final result = await repo.getIngredient(familyId, 'ing-1');
    expect(result!.allergens, ['fish']);
  });
}
