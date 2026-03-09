# DataBabe Cost Analysis & Hosting Strategy

*Last updated: 2026-03-09*

## 1. Data Volume Estimates

Based on real production data: ~3,000 activities over the first 6 months for one child (primarily feeds and nappies).

### Activity growth projections per child

| Period | Dominant types | Est. activities/month | Cumulative |
|--------|---------------|----------------------|------------|
| 0-6 months | Feeds (bottle/breast), diapers | ~500 | ~3,000 |
| 6-12 months | + solids, play, meds, tummy time | ~700 | ~7,200 |
| 12-24 months | Tapering feeds, more solids/play | ~400 | ~12,000 |
| 24+ months | Potty training, meals, play | ~300 | ~15,600 |

### Supporting data per family (typical)

| Collection | Typical count | Growth rate |
|------------|--------------|-------------|
| activities | 3,000-15,000 | ~500-700/month |
| ingredients | 10-30 | Slow (new foods introduced gradually) |
| recipes | 5-20 | Slow |
| targets | 5-15 | Stable after initial setup |
| children | 1-3 | Rare |
| carers | 2-4 | Rare |
| families | 1 | Fixed |

### Storage estimate

Each activity document has ~31 fields, averaging ~500 bytes in Firestore. For 15,000 activities:
- Activities: ~7.5 MB
- Other collections: ~50 KB
- **Total per family: ~8 MB**
- 100 families: ~800 MB (within 1 GiB free tier)

---

## 2. Firebase Pricing Reference

*Prices as of 2025-2026. Source: firebase.google.com/pricing*

### Firestore

| Resource | Free (daily) | Blaze overage (single-region) | Blaze overage (multi-region nam5) |
|----------|-------------|-------------------------------|-----------------------------------|
| Document reads | 50,000/day | $0.03 / 100K | $0.06 / 100K |
| Document writes | 20,000/day | $0.09 / 100K | $0.18 / 100K |
| Document deletes | 20,000/day | $0.01 / 100K | $0.02 / 100K |
| Storage | 1 GiB | $0.15 / GiB/month | $0.18 / GiB/month |
| Network egress | 10 GiB/month | $0.12 / GiB | $0.12 / GiB |

**Critical billing detail**: Each document in a query result = 1 read. A query returning 0 results = 1 read. Each document in a WriteBatch = 1 write (batches are a network optimization, NOT a billing optimization). `count()` queries = 1 read regardless of collection size.

### Firebase Auth

| MAU range | Cost per MAU |
|-----------|-------------|
| 0-49,999 | **Free** |
| 50,000-99,999 | $0.0055 |
| 100,000+ | $0.0046-$0.0025 |

Google Sign-In is Tier 1. Auth is not a cost concern for this app.

### Firebase Hosting

| Resource | Free | Blaze overage |
|----------|------|---------------|
| Storage | 10 GB | $0.026/GB |
| Transfer | 10 GB/month | $0.15/GB |

Flutter web build is ~15 MB. Hosting is not a cost concern.

---

## 3. Firestore Operation Counts Per Scenario

### 3.1 CSV Import of N Activities

The import writes to local Sembast first, then sync pushes to Firestore.

| Phase | Reads | Writes | Notes |
|-------|-------|--------|-------|
| Import (dedup query) | 0 | 0 | `findByTimeRange` reads from local Sembast, not Firestore |
| Sync push (new docs) | 0 | **N** | Each doc in WriteBatch = 1 write op. Batched in 500-doc chunks. |
| **Total** | **0** | **N** | 5,000 activities = 5,000 writes = 25% of daily free tier |

### 3.2 Initial Sync (App Open After Login)

Called by `initialSyncProvider` on every app start. Code path: `initialSync()` → `_push()` → `_pullForFamily()`.

| Phase | Reads | Notes |
|-------|-------|-------|
| Fetch family IDs | 1 + F | Query returns F family docs |
| Push pending (if any) | U | 1 read per update entry (transaction `txn.get()`) |
| Pull family doc | 1 per family | `_pullFamilyDoc` |
| Delta pull: 6 sub-collections | 6 per family | 1 query each; result docs add to count |
| Delta pull result docs | D | D = total new/changed docs across all collections |
| Reconcile children | C_children | Full collection fetch (every sync) |
| Reconcile carers | C_carers | Full collection fetch (every sync) |
| Reconcile ingredients | C_ingredients | Full collection fetch (every sync) |
| Reconcile recipes | C_recipes | Full collection fetch (every sync) |
| Reconcile targets | C_targets | Full collection fetch (every sync) |
| Reconcile activities | 1 (count) | `_countsMatch` pre-check; full fetch only if mismatch |
| **Total (no changes)** | **1 + 8F + C_small** | C_small = sum of all small collection doc counts |

**Example**: 1 family, 1 child, 3 carers, 20 ingredients, 10 recipes, 10 targets:
- 1 (family query) + 1 (family doc) + 7 (delta pulls, 0 results) + 1 + 3 + 20 + 10 + 10 (reconcile) + 1 (activities count) = **54 reads**

### 3.3 Regular Sync Cycle (`syncNow` / `_pushThenPull`)

Triggered by: 30s debounce after write, foreground event, reconnect, 15-min safety net, manual "Sync Now".

| Scenario | Reads | Writes |
|----------|-------|--------|
| No changes, 1 family | ~53 | 0 |
| 1 new activity logged | ~53 | 1 |
| 5 activity updates | ~53 + 5 | 5 |
| Activities count mismatch (full reconcile) | ~53 + A | 0 |

Where A = total activity count in Firestore for the family.

### 3.4 Logging a Single Activity

| Phase | Reads | Writes | Notes |
|-------|-------|--------|-------|
| Insert to Sembast | 0 | 0 | Local only |
| Enqueue to sync queue | 0 | 0 | Local only |
| 30s debounce fires → push | 0 | 1 | New doc via WriteBatch (isNew=true, no remote read) |
| Pull after push | ~53 | 0 | Full sync cycle |
| **Total** | **~53** | **1** | |

### 3.5 Updating an Existing Activity

| Phase | Reads | Writes | Notes |
|-------|-------|--------|-------|
| Update in Sembast | 0 | 0 | Local only |
| Push (update, isNew=false) | 1 | 1 | `runTransaction`: 1 read (`txn.get`) + conditional write |
| Pull after push | ~53 | 0 | Full sync cycle |
| **Total** | **~54** | **1** | |

### 3.6 Force Full Re-sync

| Phase | Reads | Writes | Notes |
|-------|-------|--------|-------|
| Push pending | varies | varies | Best-effort |
| Clear sync metadata | 0 | 0 | Local only |
| Full pull (all collections) | 8 + A + C_small | 0 | All delta pulls return all docs (lastPull=null) |

Where A = total activities, C_small = sum of small collection counts.

**Example**: 5,215 activities + 44 other docs = **~5,267 reads**.

### 3.7 `fetchFamilyIds`

1 read (query). Called by `_pullAll` fallback and `forceFullResync`.

---

## 4. Daily Usage Model

### Per-user daily reads (1 family)

| Trigger | Frequency | Reads each | Daily total |
|---------|-----------|------------|-------------|
| Initial sync (app open) | 1 | ~54 | 54 |
| Foreground events | ~24 | ~53 | 1,272 |
| 15-min safety net (unique) | ~48 | ~53 | 2,544 |
| Activities reconciliation (24h) | 1 | 1 (count only, if match) | 1 |
| **Subtotal** | | | **~3,871** |
| Activities reconciliation (mismatch) | rare | up to ~5,000 | +5,000 |
| **Total range** | | | **~4,000-9,000** |

### Per-user daily writes

| Action | Frequency | Writes each | Daily total |
|--------|-----------|-------------|-------------|
| Log activities | ~30 | 1 | 30 |
| Edit activities | ~5 | 1 | 5 |
| **Total** | | | **~35** |

### Free tier capacity

| Resource | Free limit | Per user/day | Max users |
|----------|-----------|-------------|-----------|
| Reads | 50,000 | ~6,500 (avg) | **~7** |
| Writes | 20,000 | ~35 | **~571** |

**Reads are the bottleneck.** Writes only become a problem during CSV import spikes.

---

## 5. The Reconciliation Problem

**85% of per-sync reads come from reconciliation**, not delta pulls.

| Component | Reads per sync | % of total |
|-----------|---------------|------------|
| Delta pulls (7 collections) | 8 | 15% |
| Reconcile small collections (5) | ~44 | 83% |
| Activities count check | 1 | 2% |
| **Total** | **~53** | 100% |

Reconciliation fetches ALL documents from 5 small collections on EVERY sync cycle to detect hard-deletes. For typical data: 1 child + 3 carers + 20 ingredients + 10 recipes + 10 targets = 44 reads per sync.

Since all deletes in DataBabe use soft-delete (`isDeleted` flag), these hard-delete checks are a safety net for a scenario that shouldn't happen in normal operation.

---

## 6. Optimization Options (Ranked by Impact)

### Option A: Eliminate reconciliation entirely

**Impact: ~85% read reduction → supports ~47 users on free tier**

Since all deletes use soft-delete (`isDeleted` flag), delta sync already captures deletions. Reconciliation only catches hard-deletes (manual Firestore console edits, admin scripts). Remove `_reconcileCollection` calls from `_pullForFamily`.

| Metric | Before | After |
|--------|--------|-------|
| Reads per sync | ~53 | ~8 |
| Daily reads per user | ~6,500 | ~1,000 |
| Users on free tier | ~7 | **~50** |

**Risk**: If a document is hard-deleted from Firestore (not through the app), the local copy persists as an orphan. Mitigated by keeping `forceFullResync` as a manual recovery tool.

**Implementation**: Remove lines in `_pullForFamily` that call `_reconcileCollection`. Keep the method itself for use by `forceFullResync`.

### Option B: Rate-limit reconciliation for all collections

**Impact: ~80% read reduction → supports ~40 users on free tier**

Apply the same 24-hour rate-limiting currently used for activities to ALL collections.

| Metric | Before | After |
|--------|--------|-------|
| Reads per sync | ~53 | ~8 (+ ~44 once/24h) |
| Daily reads per user | ~6,500 | ~1,044 |
| Users on free tier | ~7 | **~47** |

**Implementation**: Add `getLastReconcile`/`setLastReconcile` checks for all collections in `_reconcileCollection`, not just activities.

### Option C: Increase sync intervals

**Impact: ~50% read reduction (stacks with A or B)**

- Change 15-min safety net to 30 min: halves background syncs
- Change 30s push debounce to 60s: fewer push-then-pull cycles

| Metric | Before | After (with Option A) |
|--------|--------|----------------------|
| Daily syncs per user | ~72 | ~36 |
| Daily reads per user | ~1,000 | ~500 |
| Users on free tier | ~50 | **~100** |

**Trade-off**: Multi-carer families see changes with up to 30-min delay instead of 15-min.

### Option D: Use Firestore `.select([])` for reconciliation

**Impact: Minimal read reduction, significant egress reduction**

Firestore `.select([])` still counts as 1 read per doc, but transfers zero field data (only doc IDs). Reduces network egress but NOT read operation count.

**Not worth the effort for read optimization.** Only useful if egress becomes a concern.

### Combined impact

| Configuration | Daily reads/user | Free tier users |
|---------------|-----------------|-----------------|
| Current | ~6,500 | ~7 |
| Option A only | ~1,000 | ~50 |
| Option A + C | ~500 | ~100 |
| Option A + C + more aggressive | ~300 | ~170 |

---

## 7. Alternative Hosting Platforms

### 7.1 Firebase Blaze (pay-as-you-go)

Stay on Firebase, pay for overages. Free quotas still apply.

| Users | Est. monthly reads | Est. monthly writes | Est. cost |
|-------|-------------------|--------------------|----|
| 10 | 2M | 10K | **~$0.60** |
| 50 | 10M | 50K | **~$3.00** |
| 100 | 20M | 100K | **~$6.00** |
| 500 | 100M | 500K | **~$30.00** |

*Assumes single-region pricing ($0.03/100K reads, $0.09/100K writes) with current sync pattern. Optimizations would reduce by 5-10x.*

**Pros**: Zero migration, same code, same SDK, same auth.
**Cons**: Per-document billing makes costs unpredictable at scale. CSV import spikes can cause surprise bills.

### 7.2 Supabase

PostgreSQL-based backend with real-time subscriptions, row-level security, and auth.

| Plan | Monthly cost | Database | Bandwidth | MAUs |
|------|-------------|----------|-----------|------|
| Free | $0 | 500 MB | 5 GB | 50K |
| Pro | $25 | 8 GB | 250 GB | 100K |
| Team | $599 | 16 GB | 250 GB | 100K |

**Pros**: No per-query billing (flat rate), PostgreSQL (relational, powerful queries), built-in auth with Google Sign-In, real-time subscriptions, row-level security, generous free tier.
**Cons**: Requires rewriting sync engine from Firestore to Supabase SDK (REST + Realtime). Different data model (tables vs documents). Migration effort: medium-high.

**Migration path**: Replace `firebase_*_repository.dart` files with Supabase equivalents. Replace `FirestoreConverter` with Supabase column mapping. Replace Firebase Auth with Supabase Auth (Google provider). Sync engine would use Supabase Realtime instead of delta polling.

### 7.3 PocketBase (self-hosted)

Single-binary Go server with SQLite, REST API, real-time subscriptions, and auth.

| Hosting | Monthly cost | Storage | Bandwidth |
|---------|-------------|---------|-----------|
| Hetzner CAX11 (ARM) | ~$4 | 40 GB SSD | 20 TB |
| DigitalOcean Basic | $6 | 25 GB SSD | 1 TB |
| Fly.io (free tier) | $0 | 3 GB volume | Shared |

**Pros**: No per-query billing, full control, single binary (~15 MB), built-in auth (including Google OAuth), real-time via SSE, REST API, admin dashboard, automatic backups, SQLite (fast, simple).
**Cons**: Self-hosted (need to manage uptime, backups, TLS). No Flutter SDK (use HTTP/REST). Migration effort: medium.

**Migration path**: Replace Firestore repositories with HTTP client calling PocketBase REST API. Replace Firebase Auth with PocketBase auth. Sync engine could use PocketBase's real-time events instead of polling. Keep Sembast for local-first with PocketBase as the remote.

### 7.4 Turso (libSQL on the edge)

Distributed SQLite with HTTP API.

| Plan | Monthly cost | Storage | Reads | Writes |
|------|-------------|---------|-------|--------|
| Starter | $0 | 9 GB | 1B/month | 25M/month |
| Scaler | $29 | 24 GB | 100B/month | 100M/month |

**Pros**: Absurdly generous free tier (1 billion reads/month). SQLite compatibility. Edge locations for low latency.
**Cons**: No auth, no hosting, no real-time subscriptions. Need to build a custom API layer on top (e.g., Dart Shelf server or Cloudflare Worker). Migration effort: high.

### 7.5 Self-hosted PostgreSQL on VPS

Full custom backend with Dart Shelf/shelf_router or similar.

| Hosting | Monthly cost | Notes |
|---------|-------------|-------|
| Hetzner CAX11 | ~$4 | ARM VPS, 40 GB, 2 vCPU |
| DigitalOcean + managed DB | ~$15 | App + managed Postgres |

**Pros**: Full control, cheapest at scale, no per-operation billing.
**Cons**: Most development effort. Need to build auth, API, real-time sync from scratch. Migration effort: very high.

### Platform comparison matrix

| Factor | Firebase | Supabase | PocketBase | Turso | Self-hosted |
|--------|----------|----------|------------|-------|-------------|
| Monthly cost (10 users) | $0 | $0 | $4 | $0 | $4-15 |
| Monthly cost (100 users) | $6 | $0-25 | $4 | $0 | $4-15 |
| Monthly cost (1000 users) | $30+ | $25 | $4-10 | $0-29 | $10-30 |
| Migration effort | None | Medium-High | Medium | High | Very High |
| Auth built-in | Yes | Yes | Yes | No | No |
| Real-time sync | Polling | Yes | Yes (SSE) | No | Custom |
| Flutter SDK | Official | Community | HTTP/REST | HTTP | Custom |
| Offline-first support | Good | Limited | Limited | None | Custom |
| Ops burden | None | None (cloud) | Low | None | Medium |
| Vendor lock-in | High | Medium | None | Low | None |

---

## 8. Cost Projection Scenarios

### Scenario 1: Organic growth, no optimization

Stay on Firebase free tier with current sync pattern.

| Month | Users | Daily reads | Status |
|-------|-------|-------------|--------|
| Now | 3 | ~19,500 | OK (39% of limit) |
| +3 months | 5 | ~32,500 | OK (65%) |
| +6 months | 8 | ~52,000 | **Exceeds free tier** |
| +12 months | 15 | ~97,500 | Need Blaze (~$2/mo) |

### Scenario 2: Optimize reconciliation (Option A), stay on Firebase

| Month | Users | Daily reads | Status |
|-------|-------|-------------|--------|
| Now | 3 | ~3,000 | OK (6% of limit) |
| +6 months | 15 | ~15,000 | OK (30%) |
| +12 months | 40 | ~40,000 | OK (80%) |
| +18 months | 55 | ~55,000 | **Exceeds free tier** |

### Scenario 3: Full optimization (A + C), stay on Firebase

| Month | Users | Daily reads | Status |
|-------|-------|-------------|--------|
| +12 months | 80 | ~40,000 | OK (80%) |
| +18 months | 100 | ~50,000 | At limit |
| +24 months | 150 | ~75,000 | Need Blaze (~$1/mo) |

### Scenario 4: Migrate to PocketBase at ~50 users

| Month | Action | Monthly cost |
|-------|--------|-------------|
| Now-12mo | Firebase free | $0 |
| 12mo | Migrate to PocketBase on Hetzner | $4/month |
| 12-36mo | Scale on same VPS | $4/month |
| 36mo+ | Upgrade VPS if needed | $8/month |

---

## 9. Decision Framework

Use this flowchart when it's time to optimize:

```
Are we hitting the Firebase free tier limit?
├── No → Do nothing. Re-check monthly.
└── Yes → Are we over by <20%?
    ├── Yes → Implement Option A (remove reconciliation).
    │         Expected: 5-7x more headroom.
    └── No → Are we over by <50%?
        ├── Yes → Implement Options A + C.
        │         Expected: 10-15x more headroom.
        └── No → Is user count > 100?
            ├── No → Switch to Blaze pay-as-you-go.
            │         Expected cost: $3-10/month.
            └── Yes → Evaluate migration to PocketBase or Supabase.
                      See Section 7 for comparison.
```

---

## 10. Key Files Reference

| File | Relevance |
|------|-----------|
| `lib/sync/sync_engine.dart` | All Firestore operations (push, pull, reconcile) |
| `lib/sync/sync_engine.dart:71-89` | `_deltaCollections` and `_reconcileCollections` lists |
| `lib/sync/sync_engine.dart:536-597` | `_reconcileCollection` — the main cost driver |
| `lib/sync/sync_engine.dart:508-533` | `_countsMatch` — activities count pre-check |
| `lib/sync/sync_engine.dart:212-314` | `_push` — WriteBatch and transaction logic |
| `lib/sync/sync_engine.dart:407-470` | `_pullDelta` — delta sync with self-healing |
| `lib/sync/sync_engine.dart:648-665` | `initialSync` — push-before-pull |
| `lib/sync/sync_metadata.dart` | Pull timestamps and reconcile timestamps |
| `lib/import/csv_importer.dart` | CSV import (local-first, then sync push) |
| `tools/diagnose_firestore.mjs` | Firestore diagnostic script |
| `.github/workflows/deploy-web.yml` | Web deployment pipeline |

---

## Appendix: Firebase Billing Gotchas

1. **WriteBatch ≠ 1 operation.** Each `.set()`, `.update()`, `.delete()` in a batch = 1 billed operation. The batch is a network optimization only.

2. **Queries returning 0 results = 1 read.** Even an empty delta pull costs 1 read.

3. **`count()` = 1 read.** Regardless of collection size. Very efficient.

4. **Transactions count reads and writes separately.** A `runTransaction` with `txn.get()` + `txn.set()` = 1 read + 1 write.

5. **Security rules evaluation does NOT cost extra reads** (as of 2023 change). But `exists()` and `get()` in rules DO count.

6. **Free quota resets at midnight Pacific time.** A global user base doesn't benefit from timezone spreading.

7. **Spark plan hard-limits at quota.** Exceeding the free tier on Spark = app stops working until midnight PT. Blaze plan allows overages with billing.
