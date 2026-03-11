import 'package:sembast/sembast.dart';

import '../local/store_refs.dart';
import '../models/recipe_model.dart';
import 'duplicate_name_exception.dart';
import 'recipe_repository.dart';

class LocalRecipeRepository implements RecipeRepository {
  final Database _db;

  LocalRecipeRepository(this._db);

  StoreRef<String, Map<String, dynamic>> get _store => StoreRefs.recipes;

  @override
  Stream<List<RecipeModel>> watchRecipes(String familyId) {
    final finder = Finder(
      filter: Filter.and([
        Filter.equals('familyId', familyId),
        Filter.notEquals('isDeleted', true),
      ]),
      sortOrders: [SortOrder('name')],
    );
    return _store.query(finder: finder).onSnapshots(_db).map(
          (snapshots) => snapshots
              .map((s) => RecipeModel.fromMap(s.key, s.value))
              .toList(),
        );
  }

  @override
  Future<RecipeModel?> getRecipe(String familyId, String recipeId) async {
    final record = await _store.record(recipeId).get(_db);
    if (record == null) return null;
    return RecipeModel.fromMap(recipeId, record);
  }

  @override
  Future<void> createRecipe(String familyId, RecipeModel recipe,
      {DatabaseClient? txn}) async {
    final client = txn ?? _db;
    await _checkNameUnique(familyId, recipe.name, client: client);
    final map = recipe.toMap();
    map['familyId'] = familyId;
    await _store.record(recipe.id).put(client, map);
  }

  @override
  Future<void> updateRecipe(String familyId, RecipeModel recipe,
      {DatabaseClient? txn}) async {
    final client = txn ?? _db;
    await _checkNameUnique(familyId, recipe.name,
        excludeId: recipe.id, client: client);
    final map = recipe.toMap();
    map['familyId'] = familyId;
    await _store.record(recipe.id).put(client, map);
  }

  @override
  Future<void> softDeleteRecipe(String familyId, String recipeId,
      {DatabaseClient? txn}) async {
    final client = txn ?? _db;
    final record = await _store.record(recipeId).get(client);
    if (record != null) {
      final updated = Map<String, dynamic>.from(record);
      updated['isDeleted'] = true;
      updated['modifiedAt'] = DateTime.now().toIso8601String();
      await _store.record(recipeId).put(client, updated);
    }
  }

  /// Throws [DuplicateNameException] if a non-deleted recipe with the
  /// same name already exists in the family.
  Future<void> _checkNameUnique(String familyId, String name,
      {String? excludeId, DatabaseClient? client}) async {
    final db = client ?? _db;
    final filters = [
      Filter.equals('familyId', familyId),
      Filter.equals('name', name),
      Filter.notEquals('isDeleted', true),
    ];
    if (excludeId != null) {
      filters.add(Filter.not(Filter.byKey(excludeId)));
    }
    final existing = await _store.findFirst(db,
        finder: Finder(filter: Filter.and(filters)));
    if (existing != null) {
      throw DuplicateNameException(entityType: 'Recipe', name: name);
    }
  }
}
