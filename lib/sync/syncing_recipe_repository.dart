import 'package:sembast/sembast.dart';

import '../models/recipe_model.dart';
import '../repositories/local_recipe_repository.dart';
import '../repositories/recipe_repository.dart';
import 'sync_engine.dart';
import 'sync_queue.dart';

class SyncingRecipeRepository implements RecipeRepository {
  final LocalRecipeRepository _local;
  final SyncQueue _queue;
  final SyncEngine _engine;
  final Database _db;

  SyncingRecipeRepository(this._local, this._queue, this._engine, this._db);

  @override
  Stream<List<RecipeModel>> watchRecipes(String familyId) =>
      _local.watchRecipes(familyId);

  @override
  Future<RecipeModel?> getRecipe(String familyId, String recipeId) =>
      _local.getRecipe(familyId, recipeId);

  @override
  Future<void> createRecipe(String familyId, RecipeModel recipe) async {
    await _db.transaction((txn) async {
      await _local.createRecipe(familyId, recipe, txn: txn);
      await _queue.enqueueTxn(txn,
        collection: 'recipes',
        documentId: recipe.id,
        familyId: familyId,
        isNew: true,
      );
    });
    _engine.notifyWrite();
  }

  @override
  Future<void> updateRecipe(String familyId, RecipeModel recipe) async {
    await _db.transaction((txn) async {
      await _local.updateRecipe(familyId, recipe, txn: txn);
      await _queue.enqueueTxn(txn,
        collection: 'recipes',
        documentId: recipe.id,
        familyId: familyId,
      );
    });
    _engine.notifyWrite();
  }

  @override
  Future<void> softDeleteRecipe(String familyId, String recipeId) async {
    await _db.transaction((txn) async {
      await _local.softDeleteRecipe(familyId, recipeId, txn: txn);
      await _queue.enqueueTxn(txn,
        collection: 'recipes',
        documentId: recipeId,
        familyId: familyId,
      );
    });
    _engine.notifyWrite();
  }
}
