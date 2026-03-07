import '../models/recipe_model.dart';
import '../repositories/recipe_repository.dart';
import 'sync_engine.dart';
import 'sync_queue.dart';

class SyncingRecipeRepository implements RecipeRepository {
  final RecipeRepository _local;
  final SyncQueue _queue;
  final SyncEngine _engine;

  SyncingRecipeRepository(this._local, this._queue, this._engine);

  @override
  Stream<List<RecipeModel>> watchRecipes(String familyId) =>
      _local.watchRecipes(familyId);

  @override
  Future<RecipeModel?> getRecipe(String familyId, String recipeId) =>
      _local.getRecipe(familyId, recipeId);

  @override
  Future<void> createRecipe(String familyId, RecipeModel recipe) async {
    await _local.createRecipe(familyId, recipe);
    await _queue.enqueue(
      collection: 'recipes',
      documentId: recipe.id,
      familyId: familyId,
      isNew: true,
    );
    _engine.notifyWrite();
  }

  @override
  Future<void> updateRecipe(String familyId, RecipeModel recipe) async {
    await _local.updateRecipe(familyId, recipe);
    await _queue.enqueue(
      collection: 'recipes',
      documentId: recipe.id,
      familyId: familyId,
    );
    _engine.notifyWrite();
  }

  @override
  Future<void> softDeleteRecipe(String familyId, String recipeId) async {
    await _local.softDeleteRecipe(familyId, recipeId);
    await _queue.enqueue(
      collection: 'recipes',
      documentId: recipeId,
      familyId: familyId,
    );
    _engine.notifyWrite();
  }
}
