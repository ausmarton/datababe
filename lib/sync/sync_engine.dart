import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' hide Filter;
import 'package:flutter/widgets.dart';
import 'package:sembast/sembast.dart';

import '../local/store_refs.dart';
import '../utils/dedup_helper.dart';
import 'connectivity_monitor.dart';
import 'firestore_converter.dart';
import 'sync_engine_interface.dart';
import 'sync_metadata.dart';
import 'sync_queue.dart';

export 'sync_engine_interface.dart';

class _PushResult {
  final int pushed;
  final int failed;
  const _PushResult({required this.pushed, required this.failed});
  static const empty = _PushResult(pushed: 0, failed: 0);
}

class _ReconcileResult {
  final int reconciled;
  final String? error;
  const _ReconcileResult({this.reconciled = 0, this.error});
  _ReconcileResult operator +(_ReconcileResult other) => _ReconcileResult(
        reconciled: reconciled + other.reconciled,
        error: error ?? other.error,
      );
}

/// Core sync orchestration: push local changes to Firestore,
/// pull remote changes to local Sembast.
class SyncEngine with WidgetsBindingObserver implements SyncEngineInterface {
  final Database _db;
  final FirebaseFirestore _firestore;
  final SyncQueue _queue;
  final SyncMetadata _metadata;
  final ConnectivityMonitor _connectivity;
  final String? Function() _getUid;

  Timer? _debounceTimer;
  Timer? _periodicTimer;
  StreamSubscription<void>? _connectivitySub;
  bool _isSyncing = false;

  final _statusController =
      StreamController<SyncStatus>.broadcast();
  SyncStatus _currentStatus = SyncStatus.idle;

  /// Collections that use modifiedAt for delta sync.
  static const _deltaCollections = [
    'activities',
    'ingredients',
    'recipes',
    'targets',
    'families',
    'children',
    'carers',
  ];

  /// Subcollections to reconcile (all except 'families' — single doc).
  static const _reconcileCollections = [
    'children',
    'carers',
    'ingredients',
    'recipes',
    'targets',
    'activities',
  ];


  /// Map from collection name to Sembast store.
  static final _storeMap = <String, StoreRef<String, Map<String, dynamic>>>{
    'activities': StoreRefs.activities,
    'ingredients': StoreRefs.ingredients,
    'recipes': StoreRefs.recipes,
    'targets': StoreRefs.targets,
    'families': StoreRefs.families,
    'children': StoreRefs.children,
    'carers': StoreRefs.carers,
  };

  SyncEngine({
    required Database db,
    required FirebaseFirestore firestore,
    required SyncQueue queue,
    required SyncMetadata metadata,
    required ConnectivityMonitor connectivity,
    required String? Function() getUid,
  })  : _db = db,
        _firestore = firestore,
        _queue = queue,
        _metadata = metadata,
        _connectivity = connectivity,
        _getUid = getUid;

  /// Start listening for sync triggers.
  @override
  void start() {
    WidgetsBinding.instance.addObserver(this);

    // Pull on connectivity restore.
    _connectivitySub = _connectivity.onConnectivityRestored.listen((_) {
      _pushThenPull();
    });

    // Periodic safety net: every 15 minutes.
    _periodicTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => _pushThenPull(),
    );
  }

  /// Stop all listeners and timers.
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounceTimer?.cancel();
    _periodicTimer?.cancel();
    _connectivitySub?.cancel();
    _statusController.close();
  }

  /// Called by syncing wrappers after a local write.
  /// Starts/resets the 30-second debounce timer.
  @override
  void notifyWrite() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 30), () {
      _pushThenPull();
    });
  }

  /// Current sync status stream.
  @override
  Stream<SyncStatus> get statusStream => _statusController.stream;
  @override
  SyncStatus get currentStatus => _currentStatus;

  /// Last sync time.
  @override
  Future<DateTime?> get lastSyncTime => _metadata.getLastSyncTime();

  /// Pending change count.
  @override
  Future<int> get pendingCount => _queue.pendingCount();

  /// Manual sync trigger (from Settings > Sync Now).
  @override
  Future<SyncResult> syncNow() => _pushThenPull();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // App going to background: flush pending changes.
      _debounceTimer?.cancel();
      _push();
    } else if (state == AppLifecycleState.resumed) {
      // App coming to foreground: pull latest.
      _pushThenPull();
    }
  }

  void _setStatus(SyncStatus status) {
    _currentStatus = status;
    _statusController.add(status);
  }

  Future<SyncResult> _pushThenPull() async {
    if (_isSyncing) return SyncResult.empty;
    if (!_connectivity.isOnline) {
      _setStatus(SyncStatus.offline);
      return SyncResult.empty;
    }
    _isSyncing = true;
    _setStatus(SyncStatus.syncing);

    try {
      final pushResult = await _push();
      final reconcileResult = await _pullAll();
      _setStatus(SyncStatus.idle);
      return SyncResult(
        pushed: pushResult.pushed,
        pushFailed: pushResult.failed,
        reconciled: reconcileResult.reconciled,
        reconcileError: reconcileResult.error,
      );
    } catch (e) {
      _setStatus(SyncStatus.error);
      return SyncResult(reconcileError: e.toString());
    } finally {
      _isSyncing = false;
    }
  }

  /// Push pending local changes to Firestore.
  ///
  /// New documents (isNew: true) use WriteBatch (no remote read needed).
  /// Updates/deletes (isNew: false) use runTransaction with conditional write.
  Future<_PushResult> _push() async {
    if (!_connectivity.isOnline) return _PushResult.empty;

    final entries = await _queue.getPending();
    if (entries.isEmpty) return _PushResult.empty;

    final newEntries = entries.where((e) => e.isNew).toList();
    final updateEntries = entries.where((e) => !e.isNew).toList();

    final completedIds = <String>[];
    var failCount = 0;

    // Batch-push new documents (skip remote reads).
    if (newEntries.isNotEmpty) {
      final result = await _pushNewBatch(newEntries);
      completedIds.addAll(result.completedIds);
      failCount += result.failCount;
    }

    // Transaction-push updates/deletes (conditional write).
    for (final entry in updateEntries) {
      try {
        final store = _storeMap[entry.collection];
        if (store == null) continue;

        final localRecord =
            await store.record(entry.documentId).get(_db);
        if (localRecord == null) continue;

        final firestoreData =
            FirestoreConverter.toFirestore(Map<String, dynamic>.from(localRecord));

        final docRef = _docRef(
          entry.collection,
          entry.familyId,
          entry.documentId,
        );

        await _firestore.runTransaction((txn) async {
          final remote = await txn.get(docRef);
          if (!shouldPush(remote.data(), firestoreData)) return;
          txn.set(docRef, firestoreData);
        });
        completedIds.add(entry.id);
      } catch (e) {
        failCount++;
        debugPrint('[Sync] push ${entry.collection}/${entry.documentId}: $e');
      }
    }

    if (completedIds.isNotEmpty) {
      await _queue.removeAll(completedIds);
    }

    return _PushResult(pushed: completedIds.length, failed: failCount);
  }

  /// Batch-push new documents using WriteBatch (500-doc Firestore limit).
  /// No remote reads — new docs don't need shouldPush() checks.
  Future<({List<String> completedIds, int failCount})> _pushNewBatch(
      List<SyncEntry> entries) async {
    final completedIds = <String>[];
    var failCount = 0;

    // Process in chunks of 500 (Firestore WriteBatch limit).
    for (var i = 0; i < entries.length; i += 500) {
      final chunk = entries.sublist(
          i, i + 500 > entries.length ? entries.length : i + 500);
      try {
        final batch = _firestore.batch();
        final chunkIds = <String>[];

        for (final entry in chunk) {
          final store = _storeMap[entry.collection];
          if (store == null) continue;

          final localRecord =
              await store.record(entry.documentId).get(_db);
          if (localRecord == null) continue;

          final firestoreData = FirestoreConverter.toFirestore(
              Map<String, dynamic>.from(localRecord));

          final docRef = _docRef(
            entry.collection,
            entry.familyId,
            entry.documentId,
          );

          batch.set(docRef, firestoreData);
          chunkIds.add(entry.id);
        }

        await batch.commit();
        completedIds.addAll(chunkIds);
      } catch (e) {
        failCount += chunk.length;
        debugPrint('[Sync] pushNewBatch chunk $i: $e');
      }
    }

    return (completedIds: completedIds, failCount: failCount);
  }

  /// Pull remote changes for all families the user belongs to.
  Future<_ReconcileResult> _pullAll() async {
    // Get family IDs from local store.
    var familyIds = (await StoreRefs.families.find(_db))
        .map((r) => r.key)
        .toList();

    // Fallback: if local store is empty, query Firestore directly.
    if (familyIds.isEmpty) {
      familyIds = await _fetchFamilyIdsFromFirestore();
    }

    var result = const _ReconcileResult();
    for (final familyId in familyIds) {
      result = result + await _pullForFamily(familyId);
    }
    return result;
  }

  /// Fetch family IDs by querying families where the user is a member.
  /// More reliable than reading from user doc (which can have stale IDs).
  @override
  Future<List<String>> fetchFamilyIds() => _fetchFamilyIdsFromFirestore();

  Future<List<String>> _fetchFamilyIdsFromFirestore() async {
    final uid = _getUid();
    if (uid == null) return [];

    try {
      final snapshot = await _firestore
          .collection('families')
          .where('memberUids', arrayContains: uid)
          .get();
      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      debugPrint('[Sync] fetchFamilyIds: $e');
      return [];
    }
  }

  /// Pull changes for a specific family.
  Future<_ReconcileResult> _pullForFamily(String familyId) async {
    for (final collection in _deltaCollections) {
      if (collection == 'families') {
        await _pullFamilyDoc(familyId);
      } else {
        await _pullDelta(familyId, collection);
      }
    }

    // Resolve duplicates introduced by sync pull.
    await _resolveIngredientDuplicates(familyId);
    await _resolveRecipeDuplicates(familyId);

    // Reconcile: remove local records whose Firestore counterparts were hard-deleted.
    var result = const _ReconcileResult();
    for (final collection in _reconcileCollections) {
      result = result + await _reconcileCollection(familyId, collection);
    }
    return result;
  }

  /// Pull a single family document.
  Future<void> _pullFamilyDoc(String familyId) async {
    try {
      final doc = await _firestore
          .collection('families')
          .doc(familyId)
          .get();
      if (!doc.exists) {
        debugPrint('[Sync] pullFamilyDoc $familyId: doc does not exist');
        return;
      }

      final remoteData = FirestoreConverter.fromFirestore(
        doc.data()!,
        familyId,
      );

      // Check for pending local changes.
      final hasPending = await _hasPendingForDoc('families', doc.id);
      if (!hasPending) {
        await StoreRefs.families.record(doc.id).put(_db, remoteData);
        debugPrint('[Sync] pullFamilyDoc $familyId: stored "${remoteData['name']}"');
      } else {
        debugPrint('[Sync] pullFamilyDoc $familyId: skipped (pending local changes)');
      }

      await _metadata.setLastPull(familyId, 'families', DateTime.now());
    } catch (e) {
      debugPrint('[Sync] pullFamilyDoc $familyId: $e');
    }
  }

  /// Delta pull: only documents modified since last pull.
  Future<void> _pullDelta(String familyId, String collection) async {
    try {
      var lastPull = await _metadata.getLastPull(familyId, collection);
      final store = _storeMap[collection]!;

      // Self-healing: if lastPull is set but no local records exist for
      // this family, a previous pull likely skipped all docs (due to
      // pending sync entries). Reset to force a full re-pull.
      if (lastPull != null) {
        final localCount = await store.count(_db,
            filter: Filter.equals('familyId', familyId));
        if (localCount == 0) {
          debugPrint('[Sync] pullDelta $familyId/$collection: '
              'lastPull set but 0 local records — full re-pull');
          lastPull = null;
        }
      }

      Query<Map<String, dynamic>> query = _firestore
          .collection('families')
          .doc(familyId)
          .collection(collection);

      if (lastPull != null) {
        query = query.where('modifiedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(lastPull));
      }

      final snapshot = await query.get();

      debugPrint('[Sync] pullDelta $familyId/$collection: ${snapshot.docs.length} docs');

      var skipped = 0;
      DateTime? maxModifiedAt;

      await _db.transaction((txn) async {
        for (final doc in snapshot.docs) {
          try {
            final hasPending =
                await _hasPendingForDoc(collection, doc.id);
            if (!hasPending) {
              final localData = FirestoreConverter.fromFirestore(
                doc.data(),
                familyId,
              );
              await store.record(doc.id).put(txn, localData);
              // Track the latest modifiedAt we actually stored.
              final docModifiedAt =
                  (doc.data()['modifiedAt'] as Timestamp?)?.toDate();
              if (docModifiedAt != null &&
                  (maxModifiedAt == null ||
                      docModifiedAt.isAfter(maxModifiedAt!))) {
                maxModifiedAt = docModifiedAt;
              }
            } else {
              skipped++;
            }
          } catch (e) {
            debugPrint('[Sync] pullDelta $familyId/$collection '
                'doc ${doc.id}: $e');
            skipped++;
          }
        }
      });

      // Advance lastPull with a 2-minute safety overlap.
      //
      // Why the overlap: another device may create an activity at T1 but not
      // push it for 30+ seconds (debounce). Meanwhile, THIS device pulls and
      // sees other docs with modifiedAt up to T5 (T5 > T1). Without the
      // overlap, lastPull = T5 and the next query (modifiedAt >= T5) would
      // permanently miss the T1 activity once it's finally pushed.
      //
      // By subtracting 2 minutes, we re-fetch recent docs on every pull.
      // This is safe because Sembast put() is an idempotent upsert.
      if (skipped == 0 && maxModifiedAt != null) {
        final safeLastPull =
            maxModifiedAt!.subtract(const Duration(minutes: 2));
        await _metadata.setLastPull(familyId, collection, safeLastPull);
      } else if (skipped > 0) {
        debugPrint('[Sync] pullDelta $familyId/$collection: '
            '$skipped skipped (pending), lastPull NOT advanced');
      }
    } catch (e) {
      debugPrint('[Sync] pullDelta $familyId/$collection: $e');
    }
  }

  /// Check if there's a pending sync entry for a specific document.
  Future<bool> _hasPendingForDoc(
      String collection, String documentId) async {
    final key = '${collection}_$documentId';
    final record = await StoreRefs.syncQueue.record(key).get(_db);
    return record != null;
  }

  /// Get Firestore document reference for a collection/document.
  DocumentReference<Map<String, dynamic>> _docRef(
    String collection,
    String familyId,
    String documentId,
  ) {
    if (collection == 'families') {
      return _firestore.collection('families').doc(documentId);
    }
    return _firestore
        .collection('families')
        .doc(familyId)
        .collection(collection)
        .doc(documentId);
  }

  /// Returns true if local data should overwrite remote.
  /// Exposed as static for testability.
  static bool shouldPush(
      Map<String, dynamic>? remoteData, Map<String, dynamic> localData) {
    if (remoteData == null) return true;
    final remoteModifiedAt = remoteData['modifiedAt'];
    if (remoteModifiedAt is! Timestamp) return true;
    final localModifiedAt = localData['modifiedAt'];
    if (localModifiedAt is! Timestamp) return true;
    return localModifiedAt.toDate().isAfter(remoteModifiedAt.toDate());
  }

  /// Pre-check: do local and remote document counts match?
  /// Returns true if counts match (no reconciliation needed),
  /// false if they differ or the check fails.
  Future<bool> _countsMatch(String familyId, String collection) async {
    try {
      final store = _storeMap[collection]!;
      final localRecords = await store.find(_db,
          finder: Finder(filter: Filter.equals('familyId', familyId)));
      final localCount = localRecords.length;

      final remoteSnapshot = await _firestore
          .collection('families')
          .doc(familyId)
          .collection(collection)
          .count()
          .get();
      final remoteCount = remoteSnapshot.count ?? 0;

      return localCount == remoteCount;
    } catch (e) {
      debugPrint('[Sync] countsMatch $familyId/$collection: $e');
      return false; // Assume mismatch — proceed with full reconciliation.
    }
  }

  /// Reconcile: remove local records whose Firestore counterparts were hard-deleted.
  Future<_ReconcileResult> _reconcileCollection(
      String familyId, String collection) async {
    try {
      // For activities, use count pre-check to skip when nothing changed.
      if (collection == 'activities') {
        if (await _countsMatch(familyId, collection)) {
          return const _ReconcileResult();
        }
      }

      // Fetch all doc IDs from Firestore.
      final remoteSnapshot = await _firestore
          .collection('families')
          .doc(familyId)
          .collection(collection)
          .get();
      final remoteIds = remoteSnapshot.docs.map((d) => d.id).toSet();

      // Fetch all local IDs for this family.
      final store = _storeMap[collection]!;
      final localRecords = await store.find(_db,
          finder: Finder(filter: Filter.equals('familyId', familyId)));
      final localIds = localRecords.map((r) => r.key).toSet();

      // Find orphans: local records not in Firestore.
      final orphanedIds = localIds.difference(remoteIds);
      if (orphanedIds.isEmpty) return const _ReconcileResult();

      // Safety: if more than half of local records would be deleted,
      // the remote query likely returned incomplete results — skip.
      if (localIds.isNotEmpty &&
          orphanedIds.length > localIds.length * 0.5) {
        debugPrint(
            '[Sync] reconcile $familyId/$collection: SKIPPED — '
            '${orphanedIds.length}/${localIds.length} orphans exceeds 50% safety limit');
        return const _ReconcileResult();
      }

      // Skip orphans with pending sync queue entries (freshly created locally).
      final toDelete = <String>[];
      for (final id in orphanedIds) {
        if (!await _hasPendingForDoc(collection, id)) {
          toDelete.add(id);
        }
      }

      if (toDelete.isNotEmpty) {
        await _db.transaction((txn) async {
          for (final id in toDelete) {
            await store.record(id).delete(txn);
          }
        });
        debugPrint(
            '[Sync] reconcile $familyId/$collection: removed ${toDelete.length} orphaned docs');
      }

      return _ReconcileResult(reconciled: toDelete.length);
    } catch (e) {
      debugPrint('[Sync] reconcile $familyId/$collection: $e');
      return _ReconcileResult(error: '$collection: $e');
    }
  }

  /// Resolve ingredient duplicates for a single family after pull.
  Future<void> _resolveIngredientDuplicates(String familyId) async {
    try {
      final deletedIds = await DedupHelper(_db).dedupIngredients(familyId);
      for (final id in deletedIds) {
        await _queue.enqueue(
          collection: 'ingredients',
          documentId: id,
          familyId: familyId,
        );
      }
      if (deletedIds.isNotEmpty) {
        debugPrint('[Sync] resolved ingredient duplicates for $familyId');
      }
    } catch (e) {
      debugPrint('[Sync] resolveIngredientDuplicates $familyId: $e');
    }
  }

  /// Resolve recipe duplicates for a single family after pull.
  Future<void> _resolveRecipeDuplicates(String familyId) async {
    try {
      final deletedIds = await DedupHelper(_db).dedupRecipes(familyId);
      for (final id in deletedIds) {
        await _queue.enqueue(
          collection: 'recipes',
          documentId: id,
          familyId: familyId,
        );
      }
      if (deletedIds.isNotEmpty) {
        debugPrint('[Sync] resolved recipe duplicates for $familyId');
      }
    } catch (e) {
      debugPrint('[Sync] resolveRecipeDuplicates $familyId: $e');
    }
  }

  /// Clear all local data (entity stores + sync queue + sync metadata).
  /// Called on logout to prevent data leaking to the next user.
  @override
  Future<void> clearLocalData() async {
    _debounceTimer?.cancel();
    await _db.transaction((txn) async {
      for (final store in _storeMap.values) {
        await store.drop(txn);
      }
      await StoreRefs.syncQueue.drop(txn);
      await StoreRefs.syncMeta.drop(txn);
    });
  }

  /// Initial sync: full pull of all data for given family IDs.
  @override
  Future<void> initialSync(List<String> familyIds) async {
    if (!_connectivity.isOnline) return;
    _setStatus(SyncStatus.syncing);

    try {
      // Push pending local changes first — prevents _pullDelta from
      // skipping documents that have pending sync queue entries.
      await _push();

      for (final familyId in familyIds) {
        await _pullForFamily(familyId);
      }
      _setStatus(SyncStatus.idle);
    } catch (e) {
      _setStatus(SyncStatus.error);
    }
  }

  /// Force a full re-sync by clearing all pull timestamps and re-pulling.
  @override
  Future<void> forceFullResync(List<String> familyIds) async {
    if (!_connectivity.isOnline) return;
    _setStatus(SyncStatus.syncing);

    try {
      // Push first to avoid losing local changes.
      await _push();

      // Clear all pull timestamps — forces full re-pull.
      await _metadata.clearAllPullTimestamps();
      debugPrint('[Sync] forceFullResync: cleared all pull timestamps');

      for (final familyId in familyIds) {
        await _pullForFamily(familyId);
      }
      _setStatus(SyncStatus.idle);
    } catch (e) {
      debugPrint('[Sync] forceFullResync failed: $e');
      _setStatus(SyncStatus.error);
    }
  }

  /// Get diagnostic info about local DB state for a family.
  @override
  Future<Map<String, dynamic>> getDiagnostics(String familyId) async {
    final result = <String, dynamic>{};
    for (final entry in _storeMap.entries) {
      final collection = entry.key;
      final store = entry.value;
      final count = await store.count(
        _db,
        filter: Filter.equals('familyId', familyId),
      );
      final lastPull = await _metadata.getLastPull(familyId, collection);
      result[collection] = {
        'localCount': count,
        'lastPull': lastPull?.toIso8601String(),
      };
    }
    result['pendingSync'] = await _queue.pendingCount();
    return result;
  }
}
