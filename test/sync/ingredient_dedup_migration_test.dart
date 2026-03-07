import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import 'package:datababe/local/store_refs.dart';
import 'package:datababe/sync/ingredient_dedup_migration.dart';

void main() {
  late Database db;

  setUp(() async {
    db = await newDatabaseFactoryMemory().openDatabase('test.db');
  });

  Future<void> addIngredient(String id, String familyId, String name,
      {List<String> allergens = const [],
      DateTime? createdAt,
      bool isDeleted = false}) async {
    final created = createdAt ?? DateTime(2026, 3, 1);
    await StoreRefs.ingredients.record(id).put(db, {
      'name': name,
      'allergens': allergens,
      'isDeleted': isDeleted,
      'createdBy': 'uid-1',
      'createdAt': created.toIso8601String(),
      'modifiedAt': created.toIso8601String(),
      'familyId': familyId,
    });
  }

  test('deduplicates same-name ingredients, keeps oldest', () async {
    await addIngredient('ing-1', 'fam-1', 'cod',
        createdAt: DateTime(2026, 1, 1));
    await addIngredient('ing-2', 'fam-1', 'cod',
        createdAt: DateTime(2026, 2, 1));
    await addIngredient('ing-3', 'fam-1', 'cod',
        createdAt: DateTime(2026, 3, 1));

    final migration = IngredientDedupMigration(db);
    final changes = await migration.run();

    // Keeper (oldest) should not be deleted.
    final keeper = await StoreRefs.ingredients.record('ing-1').get(db);
    expect(keeper!['isDeleted'], false);

    // Duplicates should be soft-deleted.
    final dup1 = await StoreRefs.ingredients.record('ing-2').get(db);
    expect(dup1!['isDeleted'], true);
    final dup2 = await StoreRefs.ingredients.record('ing-3').get(db);
    expect(dup2!['isDeleted'], true);

    // Changes should include the soft-deleted docs.
    expect(changes.where((c) => c.documentId == 'ing-2'), isNotEmpty);
    expect(changes.where((c) => c.documentId == 'ing-3'), isNotEmpty);
  });

  test('merges allergen lists', () async {
    await addIngredient('ing-1', 'fam-1', 'cod',
        allergens: ['fish'], createdAt: DateTime(2026, 1, 1));
    await addIngredient('ing-2', 'fam-1', 'cod',
        allergens: ['fish', 'shellfish'], createdAt: DateTime(2026, 2, 1));

    final migration = IngredientDedupMigration(db);
    await migration.run();

    final keeper = await StoreRefs.ingredients.record('ing-1').get(db);
    final allergens = List<String>.from(keeper!['allergens'] as List);
    expect(allergens, containsAll(['fish', 'shellfish']));
  });

  test('soft-deletes duplicates', () async {
    await addIngredient('ing-1', 'fam-1', 'cod',
        createdAt: DateTime(2026, 1, 1));
    await addIngredient('ing-2', 'fam-1', 'cod',
        createdAt: DateTime(2026, 2, 1));

    final migration = IngredientDedupMigration(db);
    await migration.run();

    final dup = await StoreRefs.ingredients.record('ing-2').get(db);
    expect(dup!['isDeleted'], true);
  });

  test('only runs once', () async {
    await addIngredient('ing-1', 'fam-1', 'cod',
        createdAt: DateTime(2026, 1, 1));
    await addIngredient('ing-2', 'fam-1', 'cod',
        createdAt: DateTime(2026, 2, 1));

    final migration = IngredientDedupMigration(db);
    final changes1 = await migration.run();
    expect(changes1, isNotEmpty);

    // Add another duplicate.
    await addIngredient('ing-3', 'fam-1', 'cod',
        createdAt: DateTime(2026, 3, 1));

    // Second run should be a no-op.
    final changes2 = await migration.run();
    expect(changes2, isEmpty);

    // The new duplicate should NOT be soft-deleted (migration didn't re-run).
    final ing3 = await StoreRefs.ingredients.record('ing-3').get(db);
    expect(ing3!['isDeleted'], false);
  });

  test('handles no duplicates gracefully', () async {
    await addIngredient('ing-1', 'fam-1', 'cod');
    await addIngredient('ing-2', 'fam-1', 'salmon');

    final migration = IngredientDedupMigration(db);
    final changes = await migration.run();
    expect(changes, isEmpty);
  });

  test('handles empty database gracefully', () async {
    final migration = IngredientDedupMigration(db);
    final changes = await migration.run();
    expect(changes, isEmpty);
  });
}
