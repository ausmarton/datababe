import '../models/recipe_model.dart';

abstract class RecipeRepository {
  Stream<List<RecipeModel>> watchRecipes(String familyId);

  Future<RecipeModel?> getRecipe(String familyId, String recipeId);

  Future<void> createRecipe(String familyId, RecipeModel recipe);

  Future<void> updateRecipe(String familyId, RecipeModel recipe);

  Future<void> softDeleteRecipe(String familyId, String recipeId);
}
