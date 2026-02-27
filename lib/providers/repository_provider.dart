import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/activity_repository.dart';
import '../repositories/family_repository.dart';
import '../repositories/recipe_repository.dart';
import '../repositories/target_repository.dart';
import '../repositories/firebase_activity_repository.dart';
import '../repositories/firebase_family_repository.dart';
import '../repositories/firebase_recipe_repository.dart';
import '../repositories/firebase_target_repository.dart';

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  return FirebaseActivityRepository(ref.watch(firestoreProvider));
});

final familyRepositoryProvider = Provider<FamilyRepository>((ref) {
  return FirebaseFamilyRepository(ref.watch(firestoreProvider));
});

final targetRepositoryProvider = Provider<TargetRepository>((ref) {
  return FirebaseTargetRepository(ref.watch(firestoreProvider));
});

final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  return FirebaseRecipeRepository(ref.watch(firestoreProvider));
});
