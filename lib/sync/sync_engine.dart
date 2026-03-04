import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:sembast/sembast.dart';

import '../local/store_refs.dart';
import 'connectivity_monitor.dart';
import 'firestore_converter.dart';
import 'sync_metadata.dart';
import 'sync_queue.dart';

/// Sync status for UI display.
enum SyncStatus { idle, syncing, error, offline }

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
  ];

  /// Collections that are small and always pulled in full.
  static const _fullPullCollections = ['children', 'carers'];

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
  Future<void> syncNow() => _pushThenPull();

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

  Future<void> _pushThenPull() async {
    if (_isSyncing) return;
    if (!_connectivity.isOnline) {
      _setStatus(SyncStatus.offline);
      return;
    }
    _isSyncing = true;
    _setStatus(SyncStatus.syncing);

    try {
      await _push();
      await _pullAll();
      _setStatus(SyncStatus.idle);
    } catch (e) {
      _setStatus(SyncStatus.error);
    } finally {
      _isSyncing = false;
    }
  }

  /// Push pending local changes to Firestore.
  Future<void> _push() async {
    if (!_connectivity.isOnline) return;

    final entries = await _queue.getPending();
    if (entries.isEmpty) return;

    final completedIds = <String>[];

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

        await docRef.set(firestoreData);
        completedIds.add(entry.id);
      } catch (e) {
        debugPrint('[Sync] push ${entry.collection}/${entry.documentId}: $e');
      }
    }

    if (completedIds.isNotEmpty) {
      await _queue.removeAll(completedIds);
    }
  }

  /// Pull remote changes for all families the user belongs to.
  Future<void> _pullAll() async {
    // Get family IDs from local store.
    var familyIds = (await StoreRefs.families.find(_db))
        .map((r) => r.key)
        .toList();

    // Fallback: if local store is empty, fetch from Firestore user doc.
    if (familyIds.isEmpty) {
      familyIds = await _fetchFamilyIdsFromUserDoc();
    }

    for (final familyId in familyIds) {
      await _pullForFamily(familyId);
    }
  }

  /// Fetch family IDs from the Firestore user document.
  Future<List<String>> _fetchFamilyIdsFromUserDoc() async {
    final uid = _getUid();
    if (uid == null) return [];

    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return [];
      return List<String>.from(doc.data()?['familyIds'] ?? []);
    } catch (e) {
      debugPrint('[Sync] fetchFamilyIds: $e');
      return [];
    }
  }

  /// Pull changes for a specific family.
  Future<void> _pullForFamily(String familyId) async {
    // Delta collections: use modifiedAt > lastPull.
    for (final collection in _deltaCollections) {
      if (collection == 'families') {
        await _pullFamilyDoc(familyId);
      } else {
        await _pullDelta(familyId, collection);
      }
    }

    // Full-pull small collections.
    for (final collection in _fullPullCollections) {
      await _pullFull(familyId, collection);
    }
  }

  /// Pull a single family document.
  Future<void> _pullFamilyDoc(String familyId) async {
    try {
      final doc = await _firestore
          .collection('families')
          .doc(familyId)
          .get();
      if (!doc.exists) return;

      final remoteData = FirestoreConverter.fromFirestore(
        doc.data()!,
        familyId,
      );

      // Check for pending local changes.
      final hasPending = await _hasPendingForDoc('families', doc.id);
      if (!hasPending) {
        await StoreRefs.families.record(doc.id).put(_db, remoteData);
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

  /// Full pull for small collections (children, carers).
  Future<void> _pullFull(String familyId, String collection) async {
    try {
      final snapshot = await _firestore
          .collection('families')
          .doc(familyId)
          .collection(collection)
          .get();

      final store = _storeMap[collection]!;

      await _db.transaction((txn) async {
        for (final doc in snapshot.docs) {
          final localData = FirestoreConverter.fromFirestore(
            doc.data(),
            familyId,
          );
          await store.record(doc.id).put(txn, localData);
        }
      });

      await _metadata.setLastPull(familyId, collection, DateTime.now());
    } catch (e) {
      debugPrint('[Sync] pullFull $familyId/$collection: $e');
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
        // Pull the family doc itself.
        await _pullFamilyDoc(familyId);

        // Pull all subcollections.
        for (final collection in _deltaCollections) {
          if (collection != 'families') {
            await _pullDelta(familyId, collection);
          }
        }
        for (final collection in _fullPullCollections) {
          await _pullFull(familyId, collection);
        }
      }
      _setStatus(SyncStatus.idle);
    } catch (e) {
      _setStatus(SyncStatus.error);
    }
  }
}
