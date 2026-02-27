import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/ingredient_model.dart';
import 'ingredient_repository.dart';

class FirebaseIngredientRepository implements IngredientRepository {
  final FirebaseFirestore _firestore;

  FirebaseIngredientRepository(this._firestore);

  CollectionReference<Map<String, dynamic>> _ingredientsCol(
          String familyId) =>
      _firestore
          .collection('families')
          .doc(familyId)
          .collection('ingredients');

  @override
  Stream<List<IngredientModel>> watchIngredients(String familyId) {
    return _ingredientsCol(familyId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => IngredientModel.fromFirestore(doc))
            .toList());
  }

  @override
  Future<IngredientModel?> getIngredient(
      String familyId, String ingredientId) async {
    final doc = await _ingredientsCol(familyId).doc(ingredientId).get();
    if (!doc.exists) return null;
    return IngredientModel.fromFirestore(doc);
  }

  @override
  Future<void> createIngredient(
      String familyId, IngredientModel ingredient) async {
    await _ingredientsCol(familyId)
        .doc(ingredient.id)
        .set(ingredient.toFirestore());
  }

  @override
  Future<void> updateIngredient(
      String familyId, IngredientModel ingredient) async {
    await _ingredientsCol(familyId)
        .doc(ingredient.id)
        .set(ingredient.toFirestore());
  }

  @override
  Future<void> softDeleteIngredient(
      String familyId, String ingredientId) async {
    await _ingredientsCol(familyId)
        .doc(ingredientId)
        .update({'isDeleted': true});
  }
}
