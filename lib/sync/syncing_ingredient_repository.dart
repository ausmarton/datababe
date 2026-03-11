import 'package:sembast/sembast.dart';

import '../models/ingredient_model.dart';
import '../repositories/ingredient_repository.dart'
    show IngredientRepository, CascadedChange;
import '../repositories/local_ingredient_repository.dart';
import 'sync_engine_interface.dart';
import 'sync_queue.dart';

class SyncingIngredientRepository implements IngredientRepository {
  final LocalIngredientRepository _local;
  final SyncQueue _queue;
  final SyncEngineInterface _engine;
  final Database _db;

  SyncingIngredientRepository(
      this._local, this._queue, this._engine, this._db);

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
    await _db.transaction((txn) async {
      await _local.createIngredient(familyId, ingredient, txn: txn);
      await _queue.enqueueTxn(txn,
        collection: 'ingredients',
        documentId: ingredient.id,
        familyId: familyId,
        isNew: true,
      );
    });
    _engine.notifyWrite();
  }

  @override
  Future<void> updateIngredient(
      String familyId, IngredientModel ingredient) async {
    await _db.transaction((txn) async {
      await _local.updateIngredient(familyId, ingredient, txn: txn);
      await _queue.enqueueTxn(txn,
        collection: 'ingredients',
        documentId: ingredient.id,
        familyId: familyId,
      );
    });
    _engine.notifyWrite();
  }

  @override
  Future<void> softDeleteIngredient(
      String familyId, String ingredientId) async {
    await _db.transaction((txn) async {
      await _local.softDeleteIngredient(familyId, ingredientId, txn: txn);
      await _queue.enqueueTxn(txn,
        collection: 'ingredients',
        documentId: ingredientId,
        familyId: familyId,
      );
    });
    _engine.notifyWrite();
  }

  @override
  Future<List<CascadedChange>> renameIngredient(
      String familyId, IngredientModel ingredient, String oldName) async {
    late List<CascadedChange> changes;
    await _db.transaction((txn) async {
      changes =
          await _local.renameIngredient(familyId, ingredient, oldName, txn: txn);
      await _queue.enqueueTxn(txn,
        collection: 'ingredients',
        documentId: ingredient.id,
        familyId: familyId,
      );
      for (final change in changes) {
        await _queue.enqueueTxn(txn,
          collection: change.collection,
          documentId: change.documentId,
          familyId: familyId,
        );
      }
    });
    _engine.notifyWrite();
    return changes;
  }
}
