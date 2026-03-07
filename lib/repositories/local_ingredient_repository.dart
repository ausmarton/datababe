import 'package:sembast/sembast.dart';

import '../local/store_refs.dart';
import '../models/ingredient_model.dart';
import 'duplicate_name_exception.dart';
import 'ingredient_repository.dart';

class LocalIngredientRepository implements IngredientRepository {
  final Database _db;

  LocalIngredientRepository(this._db);

  StoreRef<String, Map<String, dynamic>> get _store => StoreRefs.ingredients;

  @override
  Stream<List<IngredientModel>> watchIngredients(String familyId) {
    final finder = Finder(
      filter: Filter.and([
        Filter.equals('familyId', familyId),
        Filter.equals('isDeleted', false),
      ]),
      sortOrders: [SortOrder('name')],
    );
    return _store.query(finder: finder).onSnapshots(_db).map(
          (snapshots) => snapshots
              .map((s) => IngredientModel.fromMap(s.key, s.value))
              .toList(),
        );
  }

  @override
  Future<IngredientModel?> getIngredient(
      String familyId, String ingredientId) async {
    final record = await _store.record(ingredientId).get(_db);
    if (record == null) return null;
    return IngredientModel.fromMap(ingredientId, record);
  }

  @override
  Future<void> createIngredient(
      String familyId, IngredientModel ingredient) async {
    await _checkNameUnique(familyId, ingredient.name);
    final map = ingredient.toMap();
    map['familyId'] = familyId;
    await _store.record(ingredient.id).put(_db, map);
  }

  @override
  Future<void> updateIngredient(
      String familyId, IngredientModel ingredient) async {
    await _checkNameUnique(familyId, ingredient.name, excludeId: ingredient.id);
    final map = ingredient.toMap();
    map['familyId'] = familyId;
    await _store.record(ingredient.id).put(_db, map);
  }

  @override
  Future<void> softDeleteIngredient(
      String familyId, String ingredientId) async {
    final record = await _store.record(ingredientId).get(_db);
    if (record != null) {
      final updated = Map<String, dynamic>.from(record);
      updated['isDeleted'] = true;
      updated['modifiedAt'] = DateTime.now().toIso8601String();
      await _store.record(ingredientId).put(_db, updated);
    }
  }

  @override
  Future<List<CascadedChange>> renameIngredient(
      String familyId, IngredientModel ingredient, String oldName) async {
    final changes = <CascadedChange>[];

    await _db.transaction((txn) async {
      // 1. Check name collision (excluding self).
      final existing = await _store.findFirst(txn,
          finder: Finder(
            filter: Filter.and([
              Filter.equals('familyId', familyId),
              Filter.equals('name', ingredient.name),
              Filter.equals('isDeleted', false),
              Filter.not(Filter.byKey(ingredient.id)),
            ]),
          ));
      if (existing != null) {
        throw DuplicateNameException(
            entityType: 'Ingredient', name: ingredient.name);
      }

      // 2. Update the ingredient record.
      final map = ingredient.toMap();
      map['familyId'] = familyId;
      await _store.record(ingredient.id).put(txn, map);

      final now = DateTime.now().toIso8601String();

      // 3. Cascade to recipes containing oldName.
      final recipes = await StoreRefs.recipes.find(txn,
          finder: Finder(
            filter: Filter.equals('familyId', familyId),
          ));
      for (final recipe in recipes) {
        final ingredients = List<String>.from(
            (recipe.value['ingredients'] as List<dynamic>?) ?? []);
        if (ingredients.contains(oldName)) {
          final updated = Map<String, dynamic>.from(recipe.value);
          updated['ingredients'] = ingredients
              .map((n) => n == oldName ? ingredient.name : n)
              .toList();
          updated['modifiedAt'] = now;
          await StoreRefs.recipes.record(recipe.key).put(txn, updated);
          changes.add((collection: 'recipes', documentId: recipe.key));
        }
      }

      // 4. Cascade to targets with matching ingredientName.
      final targets = await StoreRefs.targets.find(txn,
          finder: Finder(
            filter: Filter.and([
              Filter.equals('familyId', familyId),
              Filter.equals('ingredientName', oldName),
            ]),
          ));
      for (final target in targets) {
        final updated = Map<String, dynamic>.from(target.value);
        updated['ingredientName'] = ingredient.name;
        updated['modifiedAt'] = now;
        await StoreRefs.targets.record(target.key).put(txn, updated);
        changes.add((collection: 'targets', documentId: target.key));
      }
    });

    return changes;
  }

  /// Throws [DuplicateNameException] if a non-deleted ingredient with the
  /// same name already exists in the family.
  Future<void> _checkNameUnique(String familyId, String name,
      {String? excludeId}) async {
    final filters = [
      Filter.equals('familyId', familyId),
      Filter.equals('name', name),
      Filter.equals('isDeleted', false),
    ];
    if (excludeId != null) {
      filters.add(Filter.not(Filter.byKey(excludeId)));
    }
    final existing = await _store.findFirst(_db,
        finder: Finder(filter: Filter.and(filters)));
    if (existing != null) {
      throw DuplicateNameException(entityType: 'Ingredient', name: name);
    }
  }
}
