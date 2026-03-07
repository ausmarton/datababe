import 'package:flutter/foundation.dart';
import 'package:sembast/sembast.dart';

import '../local/store_refs.dart';
import '../repositories/cascaded_change.dart';
import '../utils/dedup_helper.dart';

/// One-time migration that deduplicates ingredients and recipes with the same
/// name within each family. Keeps the oldest (by createdAt), merges field
/// lists (union), and soft-deletes the rest.
///
/// Records completion in syncMeta store so it only runs once per local DB.
/// Idempotent — re-runs harmlessly after logout/login (cleared with
/// clearLocalData).
class IngredientDedupMigration {
  static const _migrationKey = 'ingredient_dedup_v1';

  final Database _db;

  IngredientDedupMigration(this._db);

  /// Returns list of changed docs for sync enqueue.
  /// Empty list if migration already ran or no duplicates found.
  Future<List<CascadedChange>> run() async {
    // Check if already completed.
    final meta = await StoreRefs.syncMeta.record(_migrationKey).get(_db);
    if (meta != null) return [];

    final changes = <CascadedChange>[];
    final helper = DedupHelper(_db);

    // Get all family IDs.
    final familyRecords = await StoreRefs.families.find(_db);
    final familyIds = familyRecords.map((r) => r.key).toSet();

    // Also scan ingredients for familyIds not in families store (edge case).
    final allIngredients = await StoreRefs.ingredients.find(_db);
    for (final r in allIngredients) {
      final fid = r.value['familyId'] as String?;
      if (fid != null) familyIds.add(fid);
    }

    for (final familyId in familyIds) {
      final ingredientIds = await helper.dedupIngredients(familyId);
      for (final id in ingredientIds) {
        changes.add((collection: 'ingredients', documentId: id));
      }

      final recipeIds = await helper.dedupRecipes(familyId);
      for (final id in recipeIds) {
        changes.add((collection: 'recipes', documentId: id));
      }
    }

    // Mark migration as complete.
    await StoreRefs.syncMeta.record(_migrationKey).put(_db, {
      'completedAt': DateTime.now().toIso8601String(),
    });

    if (changes.isNotEmpty) {
      debugPrint(
          '[Migration] ingredient/recipe dedup: ${changes.length} docs changed');
    }

    return changes;
  }
}
