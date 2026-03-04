import 'package:sembast/sembast.dart';

import '../local/store_refs.dart';
import '../models/ingredient_model.dart';
import 'ingredient_repository.dart';

class LocalIngredientRepository implements IngredientRepository {
  final Database _db;

  LocalIngredientRepository(this._db);

  StoreRef<String, Map<String, dynamic>> get _store => StoreRefs.ingredients;

  @override
  Stream<List<IngredientModel>> watchIngredients(String familyId) {
    final finder = Finder(
      filter: Filter.and([
        Filter.equals('familyId', familyId),
        Filter.equals('isDeleted', false),
      ]),
      sortOrders: [SortOrder('name')],
    );
    return _store.query(finder: finder).onSnapshots(_db).map(
          (snapshots) => snapshots
              .map((s) => IngredientModel.fromMap(s.key, s.value))
              .toList(),
        );
  }

  @override
  Future<IngredientModel?> getIngredient(
      String familyId, String ingredientId) async {
    final record = await _store.record(ingredientId).get(_db);
    if (record == null) return null;
    return IngredientModel.fromMap(ingredientId, record);
  }

  @override
  Future<void> createIngredient(
      String familyId, IngredientModel ingredient) async {
    final map = ingredient.toMap();
    map['familyId'] = familyId;
    await _store.record(ingredient.id).put(_db, map);
  }

  @override
  Future<void> updateIngredient(
      String familyId, IngredientModel ingredient) async {
    final map = ingredient.toMap();
    map['familyId'] = familyId;
    await _store.record(ingredient.id).put(_db, map);
  }

  @override
  Future<void> softDeleteIngredient(
      String familyId, String ingredientId) async {
    final record = await _store.record(ingredientId).get(_db);
    if (record != null) {
      final updated = Map<String, dynamic>.from(record);
      updated['isDeleted'] = true;
      updated['modifiedAt'] = DateTime.now().toIso8601String();
      await _store.record(ingredientId).put(_db, updated);
    }
  }
}
