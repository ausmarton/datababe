import 'dart:convert';

import 'package:sembast/sembast.dart';

import '../local/store_refs.dart';

/// Per-store import result.
class StoreResult {
  final int inserted;
  final int updated;
  final int skipped;

  const StoreResult({
    this.inserted = 0,
    this.updated = 0,
    this.skipped = 0,
  });
}

/// Aggregate backup restore result.
class BackupResult {
  final Map<String, StoreResult> stores;

  const BackupResult(this.stores);

  int get totalInserted =>
      stores.values.fold(0, (sum, s) => sum + s.inserted);
  int get totalUpdated =>
      stores.values.fold(0, (sum, s) => sum + s.updated);
  int get totalSkipped =>
      stores.values.fold(0, (sum, s) => sum + s.skipped);
}

/// Exports and imports family data as JSON for backup/restore.
class BackupService {
  final Database _db;

  /// Current backup format version.
  static const currentVersion = 1;

  /// Entity stores in export/import order.
  static final _entityStores = <String, StoreRef<String, Map<String, dynamic>>>{
    'families': StoreRefs.families,
    'children': StoreRefs.children,
    'carers': StoreRefs.carers,
    'activities': StoreRefs.activities,
    'ingredients': StoreRefs.ingredients,
    'recipes': StoreRefs.recipes,
    'targets': StoreRefs.targets,
  };

  BackupService(this._db);

  /// Export all data for a family as a JSON string.
  Future<String> exportFamily(String familyId, {String appVersion = ''}) async {
    final stores = <String, Map<String, dynamic>>{};

    for (final entry in _entityStores.entries) {
      final storeName = entry.key;
      final store = entry.value;

      final records = await store.find(
        _db,
        finder: storeName == 'families'
            ? Finder(filter: Filter.byKey(familyId))
            : Finder(filter: Filter.equals('familyId', familyId)),
      );

      final storeData = <String, dynamic>{};
      for (final record in records) {
        storeData[record.key] = record.value;
      }
      stores[storeName] = storeData;
    }

    final envelope = {
      'version': currentVersion,
      'appVersion': appVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'familyId': familyId,
      'stores': stores,
    };

    return json.encode(envelope);
  }

  /// Restore (merge) data from a JSON backup string.
  ///
  /// Merge strategy:
  /// - Not exists locally -> insert
  /// - Exists + incoming modifiedAt > local -> overwrite
  /// - Exists + local is newer -> skip
  Future<BackupResult> restoreFamily(String jsonContent) async {
    final data = json.decode(jsonContent) as Map<String, dynamic>;

    final version = data['version'] as int?;
    if (version == null || version > currentVersion) {
      throw FormatException(
        'Unsupported backup version: $version (expected <= $currentVersion)',
      );
    }

    final storesData = data['stores'] as Map<String, dynamic>?;
    if (storesData == null) {
      throw const FormatException('Missing "stores" in backup');
    }

    final familyId = data['familyId'] as String?;
    final results = <String, StoreResult>{};

    for (final entry in _entityStores.entries) {
      final storeName = entry.key;
      final store = entry.value;

      final incoming = storesData[storeName] as Map<String, dynamic>?;
      if (incoming == null || incoming.isEmpty) {
        results[storeName] = const StoreResult();
        continue;
      }

      var inserted = 0;
      var updated = 0;
      var skipped = 0;
      final changedIds = <String>[];

      await _db.transaction((txn) async {
        for (final recordEntry in incoming.entries) {
          final recordId = recordEntry.key;
          final incomingData =
              Map<String, dynamic>.from(recordEntry.value as Map);

          // Ensure familyId is set for subcollections.
          if (storeName != 'families' && familyId != null) {
            incomingData['familyId'] = familyId;
          }

          final existing = await store.record(recordId).get(txn);

          if (existing == null) {
            await store.record(recordId).put(txn, incomingData);
            inserted++;
            changedIds.add(recordId);
          } else {
            final incomingModified = _parseTimestamp(incomingData, 'modifiedAt')
                ?? _parseTimestamp(incomingData, 'createdAt');
            final localModified = _parseTimestamp(existing, 'modifiedAt')
                ?? _parseTimestamp(existing, 'createdAt');

            if (incomingModified != null &&
                localModified != null &&
                incomingModified.isAfter(localModified)) {
              await store.record(recordId).put(txn, incomingData);
              updated++;
              changedIds.add(recordId);
            } else if (incomingModified != null && localModified == null) {
              await store.record(recordId).put(txn, incomingData);
              updated++;
              changedIds.add(recordId);
            } else {
              skipped++;
            }
          }
        }
      });

      // Enqueue only inserted/updated records for sync.
      if (changedIds.isNotEmpty) {
        final syncStore = StoreRefs.syncQueue;
        await _db.transaction((txn) async {
          for (final recordId in changedIds) {
            final key = '${storeName}_$recordId';
            await syncStore.record(key).put(txn, {
              'collection': storeName,
              'documentId': recordId,
              'familyId': familyId ?? '',
              'createdAt': DateTime.now().toIso8601String(),
            });
          }
        });
      }

      results[storeName] =
          StoreResult(inserted: inserted, updated: updated, skipped: skipped);
    }

    return BackupResult(results);
  }

  DateTime? _parseTimestamp(Map<String, dynamic> data, String field) {
    final value = data[field];
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
