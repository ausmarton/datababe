import '../models/ingredient_model.dart';

/// A (collection, documentId) pair identifying a cascaded change.
typedef CascadedChange = ({String collection, String documentId});

abstract class IngredientRepository {
  Stream<List<IngredientModel>> watchIngredients(String familyId);

  Future<IngredientModel?> getIngredient(String familyId, String ingredientId);

  Future<void> createIngredient(String familyId, IngredientModel ingredient);

  Future<void> updateIngredient(String familyId, IngredientModel ingredient);

  Future<void> softDeleteIngredient(String familyId, String ingredientId);

  /// Rename an ingredient and cascade the change to recipes and targets.
  /// Returns the list of cascaded changes (for sync enqueue).
  Future<List<CascadedChange>> renameIngredient(
      String familyId, IngredientModel ingredient, String oldName);
}
