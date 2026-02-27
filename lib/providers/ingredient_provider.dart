import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ingredient_model.dart';
import 'child_provider.dart';
import 'repository_provider.dart';

/// All ingredients in the selected family.
final ingredientsProvider = StreamProvider<List<IngredientModel>>((ref) {
  final familyId = ref.watch(selectedFamilyIdProvider);
  final repo = ref.watch(ingredientRepositoryProvider);
  if (familyId == null) return Stream.value([]);
  return repo.watchIngredients(familyId);
});
