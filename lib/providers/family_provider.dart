import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/carer_model.dart';
import 'child_provider.dart';
import 'repository_provider.dart';

/// All carers in the selected family.
final familyCarersProvider = StreamProvider<List<CarerModel>>((ref) {
  final familyId = ref.watch(selectedFamilyIdProvider);
  final repo = ref.watch(familyRepositoryProvider);
  if (familyId == null) return Stream.value([]);
  return repo.watchCarers(familyId);
});

/// Allergen categories defined for the selected family.
final allergenCategoriesProvider = Provider<List<String>>((ref) {
  final family = ref.watch(selectedFamilyProvider);
  return family?.allergenCategories ?? [];
});
