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

  // ── Pull failure tracking ──────────────────────────────────────────

  String _failureKey(String familyId, String collection) =>
      '${familyId}_${collection}_failure';

  /// Get consecutive pull failure count for a family+collection.
  Future<int> getPullFailureCount(
      String familyId, String collection) async {
    final record =
        await _store.record(_failureKey(familyId, collection)).get(_db);
    if (record == null) return 0;
    return (record['failureCount'] as int?) ?? 0;
  }

  /// Increment the failure count and store the last error message.
  Future<void> incrementPullFailure(
      String familyId, String collection, String error) async {
    final key = _failureKey(familyId, collection);
    final existing = await _store.record(key).get(_db);
    final currentCount =
        (existing != null ? existing['failureCount'] as int? : null) ?? 0;

    await _store.record(key).put(_db, {
      'familyId': familyId,
      'collection': collection,
      'failureCount': currentCount + 1,
      'lastError': error,
      'lastFailedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Reset failure count (called on successful pull).
  Future<void> resetPullFailure(
      String familyId, String collection) async {
    await _store.record(_failureKey(familyId, collection)).delete(_db);
  }

  /// Get the last error message for a family+collection.
  Future<String?> getLastPullError(
      String familyId, String collection) async {
    final record =
        await _store.record(_failureKey(familyId, collection)).get(_db);
    if (record == null) return null;
    return record['lastError'] as String?;
  }

  /// Get the worst pull failure across all family+collection combos.
  /// Returns null if no failures exist.
  Future<({int count, String error})?> getWorstPullFailure() async {
    final records = await _store.find(_db,
        finder: Finder(
          filter: Filter.greaterThan('failureCount', 0),
          sortOrders: [SortOrder('failureCount', false)],
          limit: 1,
        ));
    if (records.isEmpty) return null;
    final data = records.first.value;
    final count = (data['failureCount'] as int?) ?? 0;
    if (count == 0) return null;
    final error = (data['lastError'] as String?) ?? 'Unknown error';
    return (count: count, error: error);
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
