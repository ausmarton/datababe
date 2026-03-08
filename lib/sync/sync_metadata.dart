import 'package:sembast/sembast.dart';

import '../local/store_refs.dart';

/// Tracks the last pull timestamp per family per collection.
class SyncMetadata {
  final Database _db;

  SyncMetadata(this._db);

  StoreRef<String, Map<String, dynamic>> get _store => StoreRefs.syncMeta;

  String _key(String familyId, String collection) =>
      '${familyId}_$collection';

  /// Get the last pull timestamp for a family+collection.
  Future<DateTime?> getLastPull(
      String familyId, String collection) async {
    final record =
        await _store.record(_key(familyId, collection)).get(_db);
    if (record == null) return null;
    final ts = record['lastPull'] as String?;
    return ts != null ? DateTime.parse(ts) : null;
  }

  /// Update the last pull timestamp for a family+collection.
  Future<void> setLastPull(
      String familyId, String collection, DateTime timestamp) async {
    await _store.record(_key(familyId, collection)).put(_db, {
      'familyId': familyId,
      'collection': collection,
      'lastPull': timestamp.toIso8601String(),
    });
  }

  String _reconcileKey(String familyId, String collection) =>
      '${familyId}_${collection}_reconcile';

  /// Get the last reconciliation timestamp for a family+collection.
  Future<DateTime?> getLastReconcile(
      String familyId, String collection) async {
    final record =
        await _store.record(_reconcileKey(familyId, collection)).get(_db);
    if (record == null) return null;
    final ts = record['lastReconcile'] as String?;
    return ts != null ? DateTime.parse(ts) : null;
  }

  /// Update the last reconciliation timestamp for a family+collection.
  Future<void> setLastReconcile(
      String familyId, String collection, DateTime timestamp) async {
    await _store.record(_reconcileKey(familyId, collection)).put(_db, {
      'familyId': familyId,
      'collection': collection,
      'lastReconcile': timestamp.toIso8601String(),
    });
  }

  /// Clear all pull timestamps, forcing the next pull to be a full re-pull.
  Future<void> clearAllPullTimestamps() async {
    final records = await _store.find(_db);
    await _db.transaction((txn) async {
      for (final record in records) {
        await _store.record(record.key).delete(txn);
      }
    });
  }

  /// Get the last sync time across all collections for display.
  Future<DateTime?> getLastSyncTime() async {
    final records = await _store.find(_db,
        finder: Finder(sortOrders: [SortOrder('lastPull', false)], limit: 1));
    if (records.isEmpty) return null;
    final ts = records.first.value['lastPull'] as String?;
    return ts != null ? DateTime.parse(ts) : null;
  }
}
