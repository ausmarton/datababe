import 'package:sembast/sembast.dart';

import '../local/store_refs.dart';
import '../models/recipe_model.dart';
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
    final map = recipe.toMap();
    map['familyId'] = familyId;
    await _store.record(recipe.id).put(_db, map);
  }

  @override
  Future<void> updateRecipe(String familyId, RecipeModel recipe) async {
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
}
