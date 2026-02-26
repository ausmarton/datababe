import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../backup/backup_service.dart';
import '../database/database.dart';
import 'cloud_storage_provider.dart';
import 'merge.dart';

enum SyncStatus {
  idle,
  syncing,
  success,
  error,
  offline,
  notSignedIn,
}

class SyncResult {
  final SyncStatus status;
  final String? errorMessage;
  final MergeResult? mergeResult;

  const SyncResult({
    required this.status,
    this.errorMessage,
    this.mergeResult,
  });
}

class SyncService {
  final AppDatabase db;
  final CloudStorageProvider cloudProvider;

  SyncService({required this.db, required this.cloudProvider});

  Completer<SyncResult>? _activeSyncLock;

  /// Run a full sync cycle. Returns immediately if a sync is already running
  /// (and returns the same future).
  Future<SyncResult> sync() async {
    // If already syncing, wait for the active sync to finish
    if (_activeSyncLock != null) {
      return _activeSyncLock!.future;
    }

    _activeSyncLock = Completer<SyncResult>();

    try {
      final result = await _doSync();
      _activeSyncLock!.complete(result);
      return result;
    } catch (e) {
      final result = SyncResult(
        status: SyncStatus.error,
        errorMessage: e.toString(),
      );
      _activeSyncLock!.complete(result);
      return result;
    } finally {
      _activeSyncLock = null;
    }
  }

  Future<SyncResult> _doSync() async {
    // 1. Check connectivity
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return const SyncResult(status: SyncStatus.offline);
    }

    // 2. Authenticate
    final signedIn = await cloudProvider.isSignedIn ||
        await cloudProvider.signInSilently();
    if (!signedIn) {
      return const SyncResult(status: SyncStatus.notSignedIn);
    }

    // 3. Export local data
    final localJson = await exportToJson(db);

    // 4. Download cloud data
    final cloudJson = await cloudProvider.download();

    // 5. First sync: just upload local data
    if (cloudJson == null) {
      await cloudProvider.upload(localJson);
      return const SyncResult(status: SyncStatus.success);
    }

    // 6. Merge
    final mergeResult = mergeBackups(localJson, cloudJson);

    // 7. If cloud had changes we don't have locally, import merged data
    if (mergeResult.localChanged) {
      await importFromJson(db, mergeResult.mergedJson);
      debugPrint(
        'Sync: imported ${mergeResult.addedToLocal} new + '
        '${mergeResult.updatedLocal} updated records from cloud',
      );
    }

    // 8. If local had changes cloud doesn't have, upload merged data
    if (mergeResult.cloudChanged) {
      await cloudProvider.upload(mergeResult.mergedJson);
      debugPrint(
        'Sync: uploaded ${mergeResult.addedToCloud} new + '
        '${mergeResult.updatedCloud} updated records to cloud',
      );
    }

    // Even if neither changed, upload to update the exportedAt timestamp
    if (!mergeResult.cloudChanged && !mergeResult.localChanged) {
      // Nothing changed, skip upload
    }

    return SyncResult(
      status: SyncStatus.success,
      mergeResult: mergeResult,
    );
  }
}
