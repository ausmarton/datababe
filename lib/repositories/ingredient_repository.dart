import '../models/ingredient_model.dart';
import 'cascaded_change.dart';

export 'cascaded_change.dart';

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
