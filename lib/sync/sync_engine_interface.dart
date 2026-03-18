/// Abstract interface for the sync engine.
///
/// Both the real [SyncEngine] and test fakes implement this interface.
/// Syncing repositories and providers reference this interface, not the
/// concrete class, enabling headless widget tests without Firebase.
abstract class SyncEngineInterface {
  void start();
  void dispose();

  /// Called by syncing wrappers after a local write.
  void notifyWrite();

  /// Manual sync trigger (from Settings > Sync Now).
  Future<SyncResult> syncNow();

  /// Current sync status stream.
  Stream<SyncStatus> get statusStream;

  /// Current sync status snapshot.
  SyncStatus get currentStatus;

  /// Last successful sync time.
  Future<DateTime?> get lastSyncTime;

  /// Number of pending changes in the sync queue.
  Future<int> get pendingCount;

  /// Full pull of all data for given family IDs.
  Future<void> initialSync(List<String> familyIds);

  /// Clear all pull timestamps and re-pull everything.
  Future<void> forceFullResync(List<String> familyIds);

  /// Clear all local data (entity stores + sync queue + metadata).
  Future<void> clearLocalData();

  /// Query Firestore for family IDs where user is a member.
  Future<List<String>> fetchFamilyIds();

  /// Get diagnostic info about local DB state for a family.
  Future<Map<String, dynamic>> getDiagnostics(String familyId);

  /// Audit activities for a specific date — compares Firestore vs local DB.
  Future<Map<String, dynamic>> dateAudit(
      String familyId, DateTime date);
}

/// Sync status for UI display.
enum SyncStatus { idle, syncing, error, offline }

/// Result of a full sync cycle (push + pull + reconcile).
class SyncResult {
  final int pushed;
  final int pushFailed;
  final int reconciled;
  final String? reconcileError;

  const SyncResult({
    this.pushed = 0,
    this.pushFailed = 0,
    this.reconciled = 0,
    this.reconcileError,
  });

  static const empty = SyncResult();
}
