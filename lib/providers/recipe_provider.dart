import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/recipe_model.dart';
import 'child_provider.dart';
import 'repository_provider.dart';

/// All recipes in the selected family.
final recipesProvider = StreamProvider<List<RecipeModel>>((ref) {
  final familyId = ref.watch(selectedFamilyIdProvider);
  final repo = ref.watch(recipeRepositoryProvider);
  if (familyId == null) return Stream.value([]);
  return repo.watchRecipes(familyId);
});
