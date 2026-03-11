# Data Integrity & Sync Reliability Analysis

## Storage Architecture Summary

DataBabe uses a **local-first** architecture:
- **Sembast** (document-oriented) for local storage
- **Firebase Firestore** (document-oriented) for cloud sync
- Custom **SyncEngine** for push/pull orchestration

This is NOT a relational database — both local and remote stores are document-based. The tradeoff: simpler per-document CRUD, but no referential integrity, no server-side joins, no ACID transactions across documents.

### Why Firebase/Firestore?

**Pros** (and why it works for current scale):
- Zero backend to maintain — serverless, fully managed
- Built-in auth (Firebase Auth + Google Sign-In)
- Real-time capable (though we use polling)
- Generous free tier (50K reads, 20K writes, 1GB storage/day)
- Security rules for access control
- Works well for document-per-entity patterns

**Cons** (scaling and structural concerns):
- **Per-document pricing**: Every read/write costs. Aggregation queries (e.g., "count all allergen exposures this week") require reading N documents client-side.
- **No server-side aggregation**: All computation happens on-device. Analytics queries scan full activity histories.
- **No relational queries**: Can't JOIN activities with ingredients — must denormalize or resolve client-side.
- **Hard-delete detection**: No way to know a remote document was deleted vs never existed. Requires full collection scans (reconciliation).
- **Custom sync engine complexity**: ~700 lines of hand-rolled sync code with edge cases around ordering, conflicts, and failure recovery.

### Alternatives Considered

| Backend | Pros | Cons |
|---------|------|------|
| **Supabase** (PostgreSQL) | Relational, server-side aggregation, SQL joins, row-level security | Requires hosting, no built-in offline sync |
| **PowerSync + Supabase** | Best of both: local SQLite + server PostgreSQL, automatic sync | Additional dependency, newer ecosystem |
| **PocketBase** | Self-hosted, SQLite-based, real-time | Self-hosting burden, smaller community |
| **Appwrite** | Open-source BaaS, relational-ish | Younger ecosystem, fewer Flutter plugins |

**Recommendation**: Firebase is adequate for current scale (1-2 families, <10K activities). If the app grows to support many families or needs complex analytics, **PowerSync + Supabase** would be the natural migration path — it provides the same local-first guarantees with relational integrity server-side.

---

## Data Loss Vectors

Thorough audit of the sync infrastructure identified the following data loss risks, ordered by severity.

### CRITICAL: Non-Atomic Local Write + Queue Enqueue

**Impact**: Permanent data loss. Data written to local DB but never synced to cloud; subsequently deleted by reconciliation.

**Root cause**: All 24 write methods across all 5 syncing repository wrappers follow this pattern:

```dart
// syncing_activity_repository.dart, line 38-44
await _local.insertActivity(familyId, activity);   // Step 1: write to Sembast
await _queue.enqueue(                                // Step 2: add to sync queue
  collection: 'activities',
  documentId: activity.id,
  familyId: familyId,
  isNew: true,
);
_engine.notifyWrite();                               // Step 3: trigger debounce
```

**Failure scenario**:
1. App crashes or is killed between Step 1 and Step 2
2. Data exists in local Sembast but has NO sync queue entry
3. Data appears in the app (reads from local DB) — user thinks it's saved
4. On next sync, `_reconcileCollection()` finds the local record is NOT in Firestore
5. Reconciliation checks for pending queue entry — there is none (it was never created)
6. Reconciliation **deletes the local record** as an "orphan"
7. Data is now gone from both local and remote — **permanent data loss**

**Affected methods** (all 24):
- `SyncingActivityRepository`: insertActivity, insertActivities, updateActivity, softDeleteActivity
- `SyncingRecipeRepository`: createRecipe, updateRecipe, softDeleteRecipe
- `SyncingTargetRepository`: createTarget, updateTarget, deactivateTarget
- `SyncingIngredientRepository`: createIngredient, updateIngredient, softDeleteIngredient, renameIngredient
- `SyncingFamilyRepository`: createFamily, createChild, createCarer, createFamilyWithChild, updateCarerRole, removeMember, updateAllergenCategories, renameAllergenCategory, removeAllergenCategory

**Fix**: Use a single Sembast transaction for both the local write and the queue enqueue. This requires the local repositories to accept an optional `DatabaseClient` parameter (transaction or database) and the syncing wrappers to orchestrate a transaction that spans both stores.

### HIGH: No Stuck Queue Detection or Retry Escalation

**Impact**: Permanently failing sync entries silently block document updates and waste push attempts.

**Root cause**: When a push fails (Firestore error, auth error, validation error), the entry remains in the queue:

```dart
// sync_engine.dart, line 232-259
for (final entry in updateEntries) {
  try {
    // ... push logic ...
    completedIds.add(entry.id);
  } catch (e) {
    failCount++;
    debugPrint('[Sync] push ${entry.collection}/${entry.documentId}: $e');
  }
}
```

**Failure scenario**:
1. A document has invalid data (e.g., field type mismatch with Firestore security rules)
2. Every push attempt fails with the same error
3. The queue entry remains forever — no retry counter, no expiry, no user notification
4. `_hasPendingForDoc()` returns true for this document forever
5. `_pullDelta()` skips pulling updates for this document (line 447-448)
6. The document's local version becomes increasingly stale
7. User has no visibility — the error is only in debug logs (stripped in release builds)

**Fix**: Add retry counting and age-based escalation:
- Track `retryCount` and `lastAttemptAt` on `SyncEntry`
- After N failures (e.g., 10), surface the error to the user via `SyncStatus`
- After M failures (e.g., 50), quarantine the entry (move to a dead-letter store)
- Expose stuck-entry diagnostics in Settings → Sync

### MEDIUM: Batch Write All-or-Nothing Failure

**Impact**: One malformed document prevents up to 499 valid documents from being pushed. They retry next cycle but waste Firestore quota.

**Root cause**: `_pushNewBatch()` processes up to 500 entries per Firestore `WriteBatch`. If any document causes the batch to fail, all 500 entries remain in the queue:

```dart
// sync_engine.dart, line 280-313
try {
  final batch = _firestore.batch();
  // ... add up to 500 docs ...
  await batch.commit();          // All-or-nothing
  completedIds.addAll(chunkIds);
} catch (e) {
  failCount += chunk.length;     // ALL entries marked as failed
}
```

**Fix**: On batch failure, fall back to individual pushes for the failed chunk. This isolates the bad document while allowing the rest to succeed.

### MEDIUM: BackupService Bypasses SyncQueue API

**Impact**: Restored records get sync queue entries without the `isNew` flag and without queue-collapse dedup.

**Root cause**: `BackupService.restoreFamily()` writes directly to `StoreRefs.syncQueue` instead of using `SyncQueue.enqueue()`:

```dart
// backup_service.dart, line 170-181
await _db.transaction((txn) async {
  for (final recordId in changedIds) {
    final key = '${storeName}_$recordId';
    await syncStore.record(key).put(txn, {
      'collection': storeName,
      'documentId': recordId,
      'familyId': familyId ?? '',
      'createdAt': DateTime.now().toIso8601String(),
      // Missing: 'isNew' flag
    });
  }
});
```

**Fix**: Use `SyncQueue.enqueue()` or add transaction-aware method to SyncQueue. Include `isNew: true` for inserted records.

### LOW: Silent Error Swallowing in Pull

**Impact**: Persistent pull failures are invisible to users. Data divergence grows silently.

**Root cause**: All pull errors are caught and logged with `debugPrint`, which is stripped from release builds:

```dart
// sync_engine.dart, line 469-471
} catch (e) {
  debugPrint('[Sync] pullDelta $familyId/$collection: $e');
}
```

**Mitigated by**: `lastPull` is correctly NOT advanced on failure, so the next sync cycle retries. The 15-minute periodic timer ensures retries happen. The self-healing mechanism resets `lastPull` when local store is empty.

**Fix**: Track consecutive pull failure count per collection. After N failures, set `SyncStatus.error` with diagnostic info.

---

## Existing Safeguards

The sync infrastructure already has several safety mechanisms:

| Safeguard | What it prevents |
|-----------|-----------------|
| `_hasPendingForDoc()` check in pull | Prevents overwriting un-pushed local changes |
| `lastPull` not advanced when docs skipped | Prevents missing remote updates |
| Self-healing `lastPull` reset | Recovers from empty-store after skipped pull |
| 50% orphan safety limit in reconciliation | Prevents mass deletion from incomplete Firestore queries |
| Queue entry check in reconciliation | Prevents deleting freshly-created local records |
| Queue collapse (deterministic key) | Prevents duplicate queue entries for same document |
| `shouldPush()` LWW check | Prevents overwriting newer remote data |
| Conditional write (Firestore transaction) | Prevents race conditions between concurrent pushers |
| Push before pull (in initialSync/forceFullResync) | Prevents pull from skipping pending docs |
| Debounced push (30s) | Reduces Firestore write costs |
| Periodic safety net (15min) | Catches missed sync triggers |
| Count pre-check for activities reconciliation | Avoids expensive full-scan when counts match |

---

## Priority Fix Order

1. **Atomic write+queue** (Critical) — Eliminates the primary data loss vector
2. **Stuck queue detection** (High) — Prevents silent sync stalls
3. **Batch fallback** (Medium) — Prevents one bad doc from blocking 499 good ones
4. **BackupService queue API** (Medium) — Consistency improvement
5. **Pull error tracking** (Low) — Observability improvement
