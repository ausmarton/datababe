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
        Filter.equals('isDeleted', false),
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
  Future<void> createRecipe(String familyId, RecipeModel recipe) async {
    await _checkNameUnique(familyId, recipe.name);
    final map = recipe.toMap();
    map['familyId'] = familyId;
    await _store.record(recipe.id).put(_db, map);
  }

  @override
  Future<void> updateRecipe(String familyId, RecipeModel recipe) async {
    await _checkNameUnique(familyId, recipe.name, excludeId: recipe.id);
    final map = recipe.toMap();
    map['familyId'] = familyId;
    await _store.record(recipe.id).put(_db, map);
  }

  @override
  Future<void> softDeleteRecipe(String familyId, String recipeId) async {
    final record = await _store.record(recipeId).get(_db);
    if (record != null) {
      final updated = Map<String, dynamic>.from(record);
      updated['isDeleted'] = true;
      updated['modifiedAt'] = DateTime.now().toIso8601String();
      await _store.record(recipeId).put(_db, updated);
    }
  }

  /// Throws [DuplicateNameException] if a non-deleted recipe with the
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
      throw DuplicateNameException(entityType: 'Recipe', name: name);
    }
  }
}
