import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/recipe_model.dart';
import 'recipe_repository.dart';

class FirebaseRecipeRepository implements RecipeRepository {
  final FirebaseFirestore _firestore;

  FirebaseRecipeRepository(this._firestore);

  CollectionReference<Map<String, dynamic>> _recipesCol(String familyId) =>
      _firestore.collection('families').doc(familyId).collection('recipes');

  @override
  Stream<List<RecipeModel>> watchRecipes(String familyId) {
    return _recipesCol(familyId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('name')
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => RecipeModel.fromFirestore(doc)).toList());
  }

  @override
  Future<RecipeModel?> getRecipe(String familyId, String recipeId) async {
    final doc = await _recipesCol(familyId).doc(recipeId).get();
    if (!doc.exists) return null;
    return RecipeModel.fromFirestore(doc);
  }

  @override
  Future<void> createRecipe(String familyId, RecipeModel recipe) async {
    await _recipesCol(familyId).doc(recipe.id).set(recipe.toFirestore());
  }

  @override
  Future<void> updateRecipe(String familyId, RecipeModel recipe) async {
    await _recipesCol(familyId).doc(recipe.id).set(recipe.toFirestore());
  }

  @override
  Future<void> softDeleteRecipe(String familyId, String recipeId) async {
    await _recipesCol(familyId).doc(recipeId).update({'isDeleted': true});
  }
}
