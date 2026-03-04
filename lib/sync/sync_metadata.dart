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

  /// Get the last sync time across all collections for display.
  Future<DateTime?> getLastSyncTime() async {
    final records = await _store.find(_db,
        finder: Finder(sortOrders: [SortOrder('lastPull', false)], limit: 1));
    if (records.isEmpty) return null;
    final ts = records.first.value['lastPull'] as String?;
    return ts != null ? DateTime.parse(ts) : null;
  }
}
