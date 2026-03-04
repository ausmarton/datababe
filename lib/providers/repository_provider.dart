import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local/database_provider.dart';
import '../repositories/activity_repository.dart';
import '../repositories/family_repository.dart';
import '../repositories/ingredient_repository.dart';
import '../repositories/invite_repository.dart';
import '../repositories/recipe_repository.dart';
import '../repositories/target_repository.dart';
import '../repositories/firebase_invite_repository.dart';
import '../repositories/local_activity_repository.dart';
import '../repositories/local_family_repository.dart';
import '../repositories/local_ingredient_repository.dart';
import '../repositories/local_recipe_repository.dart';
import '../repositories/local_target_repository.dart';
import '../sync/syncing_activity_repository.dart';
import '../sync/syncing_family_repository.dart';
import '../sync/syncing_ingredient_repository.dart';
import '../sync/syncing_recipe_repository.dart';
import '../sync/syncing_target_repository.dart';
import 'sync_provider.dart';

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  final db = ref.watch(localDatabaseProvider);
  final queue = ref.watch(syncQueueProvider);
  final engine = ref.watch(syncEngineProvider);
  return SyncingActivityRepository(LocalActivityRepository(db), queue, engine);
});

final familyRepositoryProvider = Provider<FamilyRepository>((ref) {
  final db = ref.watch(localDatabaseProvider);
  final queue = ref.watch(syncQueueProvider);
  final engine = ref.watch(syncEngineProvider);
  return SyncingFamilyRepository(LocalFamilyRepository(db), queue, engine);
});

/// Invites remain online-only (Firebase direct).
final inviteRepositoryProvider = Provider<InviteRepository>((ref) {
  return FirebaseInviteRepository(ref.watch(firestoreProvider));
});

final targetRepositoryProvider = Provider<TargetRepository>((ref) {
  final db = ref.watch(localDatabaseProvider);
  final queue = ref.watch(syncQueueProvider);
  final engine = ref.watch(syncEngineProvider);
  return SyncingTargetRepository(LocalTargetRepository(db), queue, engine);
});

final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  final db = ref.watch(localDatabaseProvider);
  final queue = ref.watch(syncQueueProvider);
  final engine = ref.watch(syncEngineProvider);
  return SyncingRecipeRepository(LocalRecipeRepository(db), queue, engine);
});

final ingredientRepositoryProvider = Provider<IngredientRepository>((ref) {
  final db = ref.watch(localDatabaseProvider);
  final queue = ref.watch(syncQueueProvider);
  final engine = ref.watch(syncEngineProvider);
  return SyncingIngredientRepository(
      LocalIngredientRepository(db), queue, engine);
});
