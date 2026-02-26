import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../sync/cloud_storage_provider.dart';
import '../sync/google_drive_provider.dart';
import '../sync/sync_service.dart';
import 'database_provider.dart';

// ---------------------------------------------------------------------------
// Cloud storage provider (singleton)
// ---------------------------------------------------------------------------

final cloudStorageProvider = Provider<CloudStorageProvider>((ref) {
  return GoogleDriveProvider();
});

// ---------------------------------------------------------------------------
// Sync enabled flag (persisted via SharedPreferences)
// ---------------------------------------------------------------------------

const _syncEnabledKey = 'sync_enabled';

final syncEnabledProvider =
    StateNotifierProvider<SyncEnabledNotifier, bool>((ref) {
  return SyncEnabledNotifier();
});

class SyncEnabledNotifier extends StateNotifier<bool> {
  SyncEnabledNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_syncEnabledKey) ?? false;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_syncEnabledKey, value);
    state = value;
  }
}

// ---------------------------------------------------------------------------
// Last synced timestamp (persisted via SharedPreferences)
// ---------------------------------------------------------------------------

const _lastSyncedKey = 'last_synced_at';

final lastSyncedAtProvider =
    StateNotifierProvider<LastSyncedAtNotifier, DateTime?>((ref) {
  return LastSyncedAtNotifier();
});

class LastSyncedAtNotifier extends StateNotifier<DateTime?> {
  LastSyncedAtNotifier() : super(null) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_lastSyncedKey);
    if (ms != null) {
      state = DateTime.fromMillisecondsSinceEpoch(ms);
    }
  }

  Future<void> update(DateTime value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSyncedKey, value.millisecondsSinceEpoch);
    state = value;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastSyncedKey);
    state = null;
  }
}

// ---------------------------------------------------------------------------
// Sync status
// ---------------------------------------------------------------------------

final syncStatusProvider = StateProvider<SyncStatus>((ref) => SyncStatus.idle);

// ---------------------------------------------------------------------------
// Sync service
// ---------------------------------------------------------------------------

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    db: ref.watch(databaseProvider),
    cloudProvider: ref.watch(cloudStorageProvider),
  );
});

// ---------------------------------------------------------------------------
// Auto-sync controller
// ---------------------------------------------------------------------------

final autoSyncProvider = Provider<AutoSyncController>((ref) {
  return AutoSyncController(ref);
});

class AutoSyncController {
  final Ref _ref;
  Timer? _debounceTimer;

  AutoSyncController(this._ref);

  /// Call once after app start (via addPostFrameCallback).
  /// Runs initial sync after a short delay.
  void initialize() {
    Future.delayed(const Duration(seconds: 2), () {
      _triggerSync();
    });
  }

  /// Call after any data mutation. Debounces to 5 seconds.
  void onDataChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 5), () {
      _triggerSync();
    });
  }

  Future<void> _triggerSync() async {
    final enabled = _ref.read(syncEnabledProvider);
    if (!enabled) return;

    _ref.read(syncStatusProvider.notifier).state = SyncStatus.syncing;

    try {
      final result = await _ref.read(syncServiceProvider).sync();
      _ref.read(syncStatusProvider.notifier).state = result.status;

      if (result.status == SyncStatus.success) {
        _ref.read(lastSyncedAtProvider.notifier).update(DateTime.now());
      }

      if (result.status == SyncStatus.error) {
        debugPrint('Sync error: ${result.errorMessage}');
      }
    } catch (e) {
      _ref.read(syncStatusProvider.notifier).state = SyncStatus.error;
      debugPrint('Sync exception: $e');
    }
  }

  /// Run sync immediately (for "Sync Now" button). Returns the result.
  Future<SyncResult> syncNow() async {
    _ref.read(syncStatusProvider.notifier).state = SyncStatus.syncing;

    try {
      final result = await _ref.read(syncServiceProvider).sync();
      _ref.read(syncStatusProvider.notifier).state = result.status;

      if (result.status == SyncStatus.success) {
        _ref.read(lastSyncedAtProvider.notifier).update(DateTime.now());
      }

      return result;
    } catch (e) {
      _ref.read(syncStatusProvider.notifier).state = SyncStatus.error;
      return SyncResult(
        status: SyncStatus.error,
        errorMessage: e.toString(),
      );
    }
  }
}
