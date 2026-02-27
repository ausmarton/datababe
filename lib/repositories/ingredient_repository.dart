import '../models/ingredient_model.dart';

abstract class IngredientRepository {
  Stream<List<IngredientModel>> watchIngredients(String familyId);

  Future<IngredientModel?> getIngredient(String familyId, String ingredientId);

  Future<void> createIngredient(String familyId, IngredientModel ingredient);

  Future<void> updateIngredient(String familyId, IngredientModel ingredient);

  Future<void> softDeleteIngredient(String familyId, String ingredientId);
}
