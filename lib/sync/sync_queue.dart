import 'package:sembast/sembast.dart';

import '../local/store_refs.dart';

/// Represents a pending change that needs to be synced to Firestore.
class SyncEntry {
  final String id;
  final String collection;
  final String documentId;
  final String familyId;
  final DateTime createdAt;
  final bool isNew;

  const SyncEntry({
    required this.id,
    required this.collection,
    required this.documentId,
    required this.familyId,
    required this.createdAt,
    this.isNew = false,
  });

  Map<String, dynamic> toMap() => {
        'collection': collection,
        'documentId': documentId,
        'familyId': familyId,
        'createdAt': createdAt.toIso8601String(),
        'isNew': isNew,
      };

  factory SyncEntry.fromMap(String id, Map<String, dynamic> d) {
    return SyncEntry(
      id: id,
      collection: d['collection'] as String,
      documentId: d['documentId'] as String,
      familyId: d['familyId'] as String,
      createdAt: DateTime.parse(d['createdAt'] as String),
      isNew: d['isNew'] as bool? ?? false,
    );
  }
}

/// Manages the queue of pending sync operations.
class SyncQueue {
  final Database _db;

  SyncQueue(this._db);

  StoreRef<String, Map<String, dynamic>> get _store => StoreRefs.syncQueue;

  /// Enqueue a document change for sync.
  ///
  /// Set [isNew] to true for newly created documents — these skip the remote
  /// read during push and use batch writes instead of transactions.
  Future<void> enqueue({
    required String collection,
    required String documentId,
    required String familyId,
    bool isNew = false,
  }) async {
    await enqueueTxn(
      _db,
      collection: collection,
      documentId: documentId,
      familyId: familyId,
      isNew: isNew,
    );
  }

  /// Transaction-aware enqueue. Use this to atomically write data and
  /// enqueue the sync entry in the same Sembast transaction.
  Future<void> enqueueTxn(
    DatabaseClient client, {
    required String collection,
    required String documentId,
    required String familyId,
    bool isNew = false,
  }) async {
    // Use a deterministic key to collapse duplicates for the same document.
    final key = '${collection}_$documentId';

    // On queue collapse, preserve isNew: true from existing entry — the doc
    // still hasn't been pushed, so it's still "new" to Firestore.
    var effectiveIsNew = isNew;
    if (!isNew) {
      final existing = await _store.record(key).get(client);
      if (existing != null && existing['isNew'] == true) {
        effectiveIsNew = true;
      }
    }

    await _store.record(key).put(client, SyncEntry(
      id: key,
      collection: collection,
      documentId: documentId,
      familyId: familyId,
      createdAt: DateTime.now(),
      isNew: effectiveIsNew,
    ).toMap());
  }

  /// Get all pending sync entries.
  Future<List<SyncEntry>> getPending() async {
    final records = await _store.find(_db,
        finder: Finder(sortOrders: [SortOrder('createdAt')]));
    return records
        .map((r) => SyncEntry.fromMap(r.key, r.value))
        .toList();
  }

  /// Remove a completed sync entry.
  Future<void> remove(String id) async {
    await _store.record(id).delete(_db);
  }

  /// Remove multiple completed sync entries.
  Future<void> removeAll(List<String> ids) async {
    await _db.transaction((txn) async {
      for (final id in ids) {
        await _store.record(id).delete(txn);
      }
    });
  }

  /// Check if there are any pending changes.
  Future<bool> hasPendingChanges() async {
    final count = await _store.count(_db);
    return count > 0;
  }

  /// Count of pending changes.
  Future<int> pendingCount() async {
    return _store.count(_db);
  }
}
