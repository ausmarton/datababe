import 'package:flutter/foundation.dart';
import 'package:sembast/sembast.dart';

import '../local/store_refs.dart';
import '../models/ingredient_model.dart';
import '../repositories/ingredient_repository.dart' show CascadedChange;

/// One-time migration that deduplicates ingredients with the same name
/// within each family. Keeps the oldest (by createdAt), merges allergen
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
      final familyChanges = await _dedupFamily(familyId);
      changes.addAll(familyChanges);
    }

    // Mark migration as complete.
    await StoreRefs.syncMeta.record(_migrationKey).put(_db, {
      'completedAt': DateTime.now().toIso8601String(),
    });

    if (changes.isNotEmpty) {
      debugPrint(
          '[Migration] ingredient dedup: ${changes.length} docs changed');
    }

    return changes;
  }

  Future<List<CascadedChange>> _dedupFamily(String familyId) async {
    final changes = <CascadedChange>[];

    final ingredients = await StoreRefs.ingredients.find(_db,
        finder: Finder(
          filter: Filter.and([
            Filter.equals('familyId', familyId),
            Filter.equals('isDeleted', false),
          ]),
        ));

    // Group by name.
    final byName = <String, List<RecordSnapshot<String, Map<String, dynamic>>>>{};
    for (final record in ingredients) {
      final name = record.value['name'] as String? ?? '';
      byName.putIfAbsent(name, () => []).add(record);
    }

    final now = DateTime.now().toIso8601String();

    await _db.transaction((txn) async {
      for (final entry in byName.entries) {
        if (entry.value.length <= 1) continue;

        final group = entry.value;

        // Sort by createdAt ascending — keep the oldest.
        group.sort((a, b) {
          final aModel = IngredientModel.fromMap(a.key, a.value);
          final bModel = IngredientModel.fromMap(b.key, b.value);
          return aModel.createdAt.compareTo(bModel.createdAt);
        });

        final keeper = group.first;

        // Merge allergens from all duplicates into the keeper.
        final mergedAllergens = <String>{};
        for (final record in group) {
          final allergens = List<String>.from(
              (record.value['allergens'] as List<dynamic>?) ?? []);
          mergedAllergens.addAll(allergens);
        }

        // Update keeper with merged allergens if they changed.
        final keeperAllergens = List<String>.from(
            (keeper.value['allergens'] as List<dynamic>?) ?? []);
        if (!_sameSet(keeperAllergens.toSet(), mergedAllergens)) {
          final updated = Map<String, dynamic>.from(keeper.value);
          updated['allergens'] = mergedAllergens.toList()..sort();
          updated['modifiedAt'] = now;
          await StoreRefs.ingredients.record(keeper.key).put(txn, updated);
          changes.add((collection: 'ingredients', documentId: keeper.key));
        }

        // Soft-delete duplicates.
        for (var i = 1; i < group.length; i++) {
          final dup = group[i];
          final updated = Map<String, dynamic>.from(dup.value);
          updated['isDeleted'] = true;
          updated['modifiedAt'] = now;
          await StoreRefs.ingredients.record(dup.key).put(txn, updated);
          changes.add((collection: 'ingredients', documentId: dup.key));
        }
      }
    });

    return changes;
  }

  static bool _sameSet(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);
}
