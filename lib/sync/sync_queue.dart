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
  final int retryCount;
  final String? lastError;

  const SyncEntry({
    required this.id,
    required this.collection,
    required this.documentId,
    required this.familyId,
    required this.createdAt,
    this.isNew = false,
    this.retryCount = 0,
    this.lastError,
  });

  Map<String, dynamic> toMap() => {
        'collection': collection,
        'documentId': documentId,
        'familyId': familyId,
        'createdAt': createdAt.toIso8601String(),
        'isNew': isNew,
        'retryCount': retryCount,
        if (lastError != null) 'lastError': lastError,
      };

  factory SyncEntry.fromMap(String id, Map<String, dynamic> d) {
    return SyncEntry(
      id: id,
      collection: d['collection'] as String,
      documentId: d['documentId'] as String,
      familyId: d['familyId'] as String,
      createdAt: DateTime.parse(d['createdAt'] as String),
      isNew: d['isNew'] as bool? ?? false,
      retryCount: d['retryCount'] as int? ?? 0,
      lastError: d['lastError'] as String?,
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

  // ── Retry tracking ────────────────────────────────────────────────

  /// Increment the retry count for a failed entry and store the error.
  Future<void> incrementRetry(String id, String error) async {
    final existing = await _store.record(id).get(_db);
    if (existing == null) return;
    final updated = Map<String, dynamic>.from(existing);
    updated['retryCount'] = ((existing['retryCount'] as int?) ?? 0) + 1;
    updated['lastError'] = error;
    await _store.record(id).put(_db, updated);
  }

  // ── Dead letter / quarantine ──────────────────────────────────────

  StoreRef<String, Map<String, dynamic>> get _deadLetterStore =>
      StoreRefs.syncDeadLetter;

  /// Move a permanently failing entry to the dead letter store.
  Future<void> quarantine(String id, String error) async {
    await _db.transaction((txn) async {
      final existing = await _store.record(id).get(txn);
      if (existing == null) return;

      final data = Map<String, dynamic>.from(existing);
      data['lastError'] = error;
      data['quarantinedAt'] = DateTime.now().toIso8601String();
      await _deadLetterStore.record(id).put(txn, data);
      await _store.record(id).delete(txn);
    });
  }

  /// Get all quarantined entries.
  Future<List<SyncEntry>> getQuarantined() async {
    final records = await _deadLetterStore.find(_db);
    return records
        .map((r) => SyncEntry.fromMap(r.key, r.value))
        .toList();
  }

  /// Count of quarantined entries.
  Future<int> quarantinedCount() async {
    return _deadLetterStore.count(_db);
  }

  /// Clear all quarantined entries (discard permanently).
  Future<void> clearQuarantined() async {
    await _deadLetterStore.drop(_db);
  }

  /// Move a quarantined entry back to the active queue for retry.
  /// Resets retryCount and lastError.
  Future<void> retryQuarantined(String id) async {
    await _db.transaction((txn) async {
      final existing = await _deadLetterStore.record(id).get(txn);
      if (existing == null) return;

      final data = Map<String, dynamic>.from(existing);
      data['retryCount'] = 0;
      data.remove('lastError');
      data.remove('quarantinedAt');
      data['createdAt'] = DateTime.now().toIso8601String();
      await _store.record(id).put(txn, data);
      await _deadLetterStore.record(id).delete(txn);
    });
  }
}
