import 'package:sembast/sembast.dart';

import '../local/store_refs.dart';
import '../models/ingredient_model.dart';
import '../models/recipe_model.dart';

/// Shared deduplication logic for ingredients and recipes.
/// Used by SyncEngine (post-pull), IngredientDedupMigration, and BackupService.
class DedupHelper {
  final Database _db;

  DedupHelper(this._db);

  /// Dedup ingredients by name within a family.
  /// Keeps oldest by createdAt, merges allergens (union), soft-deletes rest.
  /// Returns IDs of soft-deleted duplicates.
  Future<List<String>> dedupIngredients(String familyId) async {
    return _dedup(
      familyId: familyId,
      store: StoreRefs.ingredients,
      sortByCreatedAt: (a, b) {
        final aModel = IngredientModel.fromMap(a.key, a.value);
        final bModel = IngredientModel.fromMap(b.key, b.value);
        return aModel.createdAt.compareTo(bModel.createdAt);
      },
      mergeFields: (keeper, group) {
        final mergedAllergens = <String>{};
        for (final record in group) {
          final allergens = List<String>.from(
              (record.value['allergens'] as List<dynamic>?) ?? []);
          mergedAllergens.addAll(allergens);
        }
        final keeperAllergens = List<String>.from(
            (keeper.value['allergens'] as List<dynamic>?) ?? []);
        if (_sameSet(keeperAllergens.toSet(), mergedAllergens)) return null;
        return {'allergens': mergedAllergens.toList()..sort()};
      },
    );
  }

  /// Dedup recipes by name within a family.
  /// Keeps oldest by createdAt, merges ingredient lists (union), soft-deletes rest.
  /// Returns IDs of soft-deleted duplicates.
  Future<List<String>> dedupRecipes(String familyId) async {
    return _dedup(
      familyId: familyId,
      store: StoreRefs.recipes,
      sortByCreatedAt: (a, b) {
        final aModel = RecipeModel.fromMap(a.key, a.value);
        final bModel = RecipeModel.fromMap(b.key, b.value);
        return aModel.createdAt.compareTo(bModel.createdAt);
      },
      mergeFields: (keeper, group) {
        final mergedIngredients = <String>{};
        for (final record in group) {
          final ingredients = List<String>.from(
              (record.value['ingredients'] as List<dynamic>?) ?? []);
          mergedIngredients.addAll(ingredients);
        }
        final keeperIngredients = List<String>.from(
            (keeper.value['ingredients'] as List<dynamic>?) ?? []);
        if (_sameSet(keeperIngredients.toSet(), mergedIngredients)) return null;
        return {'ingredients': mergedIngredients.toList()..sort()};
      },
    );
  }

  /// Generic dedup: groups non-deleted records by name, keeps oldest,
  /// merges via [mergeFields] callback, soft-deletes rest.
  /// Returns IDs of soft-deleted duplicates.
  Future<List<String>> _dedup({
    required String familyId,
    required StoreRef<String, Map<String, dynamic>> store,
    required int Function(
            RecordSnapshot<String, Map<String, dynamic>>,
            RecordSnapshot<String, Map<String, dynamic>>)
        sortByCreatedAt,
    required Map<String, dynamic>? Function(
            RecordSnapshot<String, Map<String, dynamic>> keeper,
            List<RecordSnapshot<String, Map<String, dynamic>>> group)
        mergeFields,
  }) async {
    final records = await store.find(_db,
        finder: Finder(
          filter: Filter.and([
            Filter.equals('familyId', familyId),
            Filter.notEquals('isDeleted', true),
          ]),
        ));

    // Group by name.
    final byName =
        <String, List<RecordSnapshot<String, Map<String, dynamic>>>>{};
    for (final record in records) {
      final name = record.value['name'] as String? ?? '';
      byName.putIfAbsent(name, () => []).add(record);
    }

    final hasDups = byName.values.any((g) => g.length > 1);
    if (!hasDups) return [];

    final now = DateTime.now().toIso8601String();
    final deletedIds = <String>[];

    await _db.transaction((txn) async {
      for (final entry in byName.entries) {
        if (entry.value.length <= 1) continue;

        final group = entry.value;
        group.sort(sortByCreatedAt);

        final keeper = group.first;

        // Merge fields into keeper if needed.
        final mergeResult = mergeFields(keeper, group);
        if (mergeResult != null) {
          final updated = Map<String, dynamic>.from(keeper.value);
          updated.addAll(mergeResult);
          updated['modifiedAt'] = now;
          await store.record(keeper.key).put(txn, updated);
        }

        // Soft-delete duplicates.
        for (var i = 1; i < group.length; i++) {
          final dup = group[i];
          final updated = Map<String, dynamic>.from(dup.value);
          updated['isDeleted'] = true;
          updated['modifiedAt'] = now;
          await store.record(dup.key).put(txn, updated);
          deletedIds.add(dup.key);
        }
      }
    });

    return deletedIds;
  }

  static bool _sameSet(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);
}
