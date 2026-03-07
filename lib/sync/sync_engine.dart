import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' hide Filter;
import 'package:flutter/widgets.dart';
import 'package:sembast/sembast.dart';

import '../local/store_refs.dart';
import 'connectivity_monitor.dart';
import 'firestore_converter.dart';
import 'sync_metadata.dart';
import 'sync_queue.dart';

/// Sync status for UI display.
enum SyncStatus { idle, syncing, error, offline }

/// Result of a push operation.
class PushResult {
  final int pushed;
  final int failed;

  const PushResult({required this.pushed, required this.failed});

  static const empty = PushResult(pushed: 0, failed: 0);
}

/// Core sync orchestration: push local changes to Firestore,
/// pull remote changes to local Sembast.
class SyncEngine with WidgetsBindingObserver {
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
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounceTimer?.cancel();
    _periodicTimer?.cancel();
    _connectivitySub?.cancel();
    _statusController.close();
  }

  /// Called by syncing wrappers after a local write.
  /// Starts/resets the 30-second debounce timer.
  void notifyWrite() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 30), () {
      _pushThenPull();
    });
  }

  /// Current sync status stream.
  Stream<SyncStatus> get statusStream => _statusController.stream;
  SyncStatus get currentStatus => _currentStatus;

  /// Last sync time.
  Future<DateTime?> get lastSyncTime => _metadata.getLastSyncTime();

  /// Pending change count.
  Future<int> get pendingCount => _queue.pendingCount();

  /// Manual sync trigger (from Settings > Sync Now).
  Future<PushResult> syncNow() => _pushThenPull();

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

  Future<PushResult> _pushThenPull() async {
    if (_isSyncing) return PushResult.empty;
    if (!_connectivity.isOnline) {
      _setStatus(SyncStatus.offline);
      return PushResult.empty;
    }
    _isSyncing = true;
    _setStatus(SyncStatus.syncing);

    try {
      final result = await _push();
      await _pullAll();
      _setStatus(SyncStatus.idle);
      return result;
    } catch (e) {
      _setStatus(SyncStatus.error);
      return PushResult.empty;
    } finally {
      _isSyncing = false;
    }
  }

  /// Push pending local changes to Firestore.
  Future<PushResult> _push() async {
    if (!_connectivity.isOnline) return PushResult.empty;

    final entries = await _queue.getPending();
    if (entries.isEmpty) return PushResult.empty;

    final completedIds = <String>[];
    var failCount = 0;

    for (final entry in entries) {
      try {
        final store = _storeMap[entry.collection];
        if (store == null) continue;

        final localRecord =
            await store.record(entry.documentId).get(_db);
        if (localRecord == null) continue;

        final firestoreData =
            FirestoreConverter.toFirestore(Map<String, dynamic>.from(localRecord));

        // Determine Firestore path.
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

    return PushResult(pushed: completedIds.length, failed: failCount);
  }

  /// Pull remote changes for all families the user belongs to.
  Future<void> _pullAll() async {
    // Get family IDs from local store.
    var familyIds = (await StoreRefs.families.find(_db))
        .map((r) => r.key)
        .toList();

    // Fallback: if local store is empty, query Firestore directly.
    if (familyIds.isEmpty) {
      familyIds = await _fetchFamilyIdsFromFirestore();
    }

    for (final familyId in familyIds) {
      await _pullForFamily(familyId);
    }
  }

  /// Fetch family IDs by querying families where the user is a member.
  /// More reliable than reading from user doc (which can have stale IDs).
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
  Future<void> _pullForFamily(String familyId) async {
    for (final collection in _deltaCollections) {
      if (collection == 'families') {
        await _pullFamilyDoc(familyId);
      } else {
        await _pullDelta(familyId, collection);
      }
    }

    // Reconcile: remove local records whose Firestore counterparts were hard-deleted.
    for (final collection in _reconcileCollections) {
      await _reconcileCollection(familyId, collection);
    }
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
      final lastPull = await _metadata.getLastPull(familyId, collection);

      Query<Map<String, dynamic>> query = _firestore
          .collection('families')
          .doc(familyId)
          .collection(collection);

      if (lastPull != null) {
        query = query.where('modifiedAt',
            isGreaterThan: Timestamp.fromDate(lastPull));
      }

      final snapshot = await query.get();
      final store = _storeMap[collection]!;

      debugPrint('[Sync] pullDelta $familyId/$collection: ${snapshot.docs.length} docs');

      await _db.transaction((txn) async {
        for (final doc in snapshot.docs) {
          final hasPending =
              await _hasPendingForDoc(collection, doc.id);
          if (!hasPending) {
            final localData = FirestoreConverter.fromFirestore(
              doc.data(),
              familyId,
            );
            await store.record(doc.id).put(txn, localData);
          }
        }
      });

      await _metadata.setLastPull(familyId, collection, DateTime.now());
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
  Future<void> _reconcileCollection(
      String familyId, String collection) async {
    try {
      // For activities, use count pre-check to skip when nothing changed.
      if (collection == 'activities') {
        if (await _countsMatch(familyId, collection)) {
          return;
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
      if (orphanedIds.isEmpty) return;

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

    } catch (e) {
      debugPrint('[Sync] reconcile $familyId/$collection: $e');
    }
  }

  /// Clear all local data (entity stores + sync queue + sync metadata).
  /// Called on logout to prevent data leaking to the next user.
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
  Future<void> initialSync(List<String> familyIds) async {
    if (!_connectivity.isOnline) return;
    _setStatus(SyncStatus.syncing);

    try {
      for (final familyId in familyIds) {
        await _pullForFamily(familyId);
      }
      _setStatus(SyncStatus.idle);
    } catch (e) {
      _setStatus(SyncStatus.error);
    }
  }
}
