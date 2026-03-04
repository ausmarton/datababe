import '../models/ingredient_model.dart';
import '../repositories/ingredient_repository.dart';
import 'sync_engine.dart';
import 'sync_queue.dart';

class SyncingIngredientRepository implements IngredientRepository {
  final IngredientRepository _local;
  final SyncQueue _queue;
  final SyncEngine _engine;

  SyncingIngredientRepository(this._local, this._queue, this._engine);

  @override
  Stream<List<IngredientModel>> watchIngredients(String familyId) =>
      _local.watchIngredients(familyId);

  @override
  Future<IngredientModel?> getIngredient(
          String familyId, String ingredientId) =>
      _local.getIngredient(familyId, ingredientId);

  @override
  Future<void> createIngredient(
      String familyId, IngredientModel ingredient) async {
    await _local.createIngredient(familyId, ingredient);
    await _queue.enqueue(
      collection: 'ingredients',
      documentId: ingredient.id,
      familyId: familyId,
    );
    _engine.notifyWrite();
  }

  @override
  Future<void> updateIngredient(
      String familyId, IngredientModel ingredient) async {
    await _local.updateIngredient(familyId, ingredient);
    await _queue.enqueue(
      collection: 'ingredients',
      documentId: ingredient.id,
      familyId: familyId,
    );
    _engine.notifyWrite();
  }

  @override
  Future<void> softDeleteIngredient(
      String familyId, String ingredientId) async {
    await _local.softDeleteIngredient(familyId, ingredientId);
    await _queue.enqueue(
      collection: 'ingredients',
      documentId: ingredientId,
      familyId: familyId,
    );
    _engine.notifyWrite();
  }
}
