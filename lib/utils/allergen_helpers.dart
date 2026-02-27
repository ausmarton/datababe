import '../models/ingredient_model.dart';

/// Compute allergens from ingredient names by matching against known ingredients.
Set<String> computeAllergensByName(
    List<String> ingredientNames, List<IngredientModel> allIngredients) {
  final allergens = <String>{};
  final lookup = <String, IngredientModel>{};
  for (final ingredient in allIngredients) {
    lookup[ingredient.name.toLowerCase()] = ingredient;
  }
  for (final name in ingredientNames) {
    final match = lookup[name.toLowerCase()];
    if (match != null) {
      allergens.addAll(match.allergens);
    }
  }
  return allergens;
}
