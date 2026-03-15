# DataBabe — Baby Care Tracking App

## What this is
A local-first baby care tracking app for parents and caregivers. Tracks feeds, diapers, medications, growth, play, and other daily care activities. Also tracks **recipes, ingredients, allergen exposure, and goals/targets**.

## Tech stack
- **Flutter + Dart** — Android native + Flutter Web (for iOS/desktop browsers)
- **Sembast** — Local database (file-based on mobile, IndexedDB on web)
- **Firebase** — Firestore (cloud sync), Firebase Auth (authentication)
- **Riverpod** — State management
- **go_router** — Declarative routing
- **fl_chart** — Charts and data visualisation
- **csv** — CSV import
- **uuid** — UUID generation for all entity IDs
- **connectivity_plus** — Network status monitoring

## Architecture
- **Local-first**: all reads/writes go to local Sembast DB, then sync to Firestore
- **Sync engine**: event-driven push (debounced 30s) + pull on foreground/reconnect
- Firebase Auth with Google Sign-In
- Multi-carer: Family groups with parent/carer roles
- Repository pattern: abstract interfaces → local repos (Sembast) → syncing wrappers → Firestore sync
- All data is **family-scoped** — local repos filter by `familyId` field, Firestore uses path segments
- Models have dual serialization: `toMap()`/`fromMap()` (Sembast, ISO 8601 dates) + `toFirestore()`/`fromFirestore()` (Firestore Timestamps)
- Deletion: **soft delete** via `isDeleted` flag (ingredients, recipes) or `isActive: false` (targets)
- Deletion UI: **confirmation dialog → awaited delete → try/catch** (not Dismissible/fire-and-forget)
- Duplicate prevention: client-side checks in `_save()` before writing
- Names normalized to **lowercase** (ingredients and recipes)
- **Invites remain online-only** (Firebase direct, not synced locally)

## Data flow
```
UI ← Riverpod Providers ← Syncing Repos → Local Repos (Sembast)
                                         ↘ SyncQueue → SyncEngine → Firestore
```

## Project structure
```
lib/
  main.dart              — App entry point (Firebase + Sembast init)
  app.dart               — MaterialApp with router + auth guard
  firebase_options.dart  — Generated Firebase config (real values, public by design)
  models/                — Data model classes + enums (toMap/fromMap + toFirestore/fromFirestore)
    activity_model.dart, app_user.dart, bulk_entry.dart, carer_model.dart,
    child_model.dart, enums.dart, family_model.dart, ingredient_model.dart,
    invite_model.dart, recipe_model.dart, target_model.dart
  local/                 — Sembast database setup
    database_provider.dart, store_refs.dart
  repositories/          — Abstract interfaces + Firebase + Local implementations
    activity, auth, family, ingredient, invite, recipe, target
    local_*_repository.dart — Sembast implementations
    firebase_*_repository.dart — Firestore implementations
    cascaded_change.dart          — Shared CascadedChange typedef
    duplicate_name_exception.dart — Typed exception for name collisions
  sync/                  — Sync infrastructure
    sync_engine.dart     — Push/pull orchestration with debounce
    sync_queue.dart      — Pending change tracking
    sync_metadata.dart   — Last-pull timestamps
    connectivity_monitor.dart — Online/offline detection
    firestore_converter.dart  — Map ↔ Firestore format conversion
    syncing_*_repository.dart — Write-intercepting decorator wrappers
    ingredient_dedup_migration.dart — One-time ingredient dedup migration
  backup/                — Backup/restore service (JSON export/import with merge)
    backup_service.dart  — Export/import logic + BackupResult types
  providers/             — Riverpod providers (auth, repositories, sync, UI state)
    activity_provider, auth_provider, backup_provider, child_provider,
    family_provider, ingredient_provider, initial_sync_provider,
    insights_provider, invite_provider, recipe_provider, repository_provider,
    sync_provider, target_provider
  screens/               — Feature screens
    auth/                — LoginScreen with Google Sign-In
    bulk_add/            — Bulk add activities screen
    home/                — Home screen
    timeline/            — Timeline view with time window modes
    log_entry/           — Activity logging
    charts/              — Charts and data visualisation
    goals/               — goals_screen.dart, add_target_screen.dart
    ingredients/         — ingredient_list_screen.dart, add_ingredient_screen.dart
    recipes/             — recipe_list_screen.dart, add_recipe_screen.dart
    insights/            — insights_screen, allergen_detail, metric_detail, growth_detail_screen
    import/              — import_preview_screen.dart, import_result_dialog.dart
    settings/            — settings_screen.dart, manage_allergens_screen.dart (+ sync controls)
    family/              — Family management
  widgets/               — Shared UI components (summary_card, shell_scaffold with sync dot)
  import/                — CSV import logic (CsvParser pure + CsvImporter with dedup + CsvAnalyzer + ImportPreview models)
  utils/                 — Helpers
    activity_aggregator.dart, activity_helpers.dart,
    allergen_helpers.dart, date_range_helpers.dart, dedup_helper.dart,
    file_reader.dart (conditional import barrel), file_reader_io.dart, file_reader_web.dart
```

## Key commands
```bash
flutter pub get                                              # Install dependencies
flutter analyze                                              # Lint check
flutter test                                                 # Run tests (812 tests)
flutter run -d chrome                                        # Run on web
flutter run -d <device>                                      # Run on Android
```

## Firebase config
- Client-side API keys are **hardcoded** in `lib/firebase_options.dart` (public by design, protected by security rules)
- `android/app/google-services.json` is committed (required by Google Services Gradle plugin)
- No `--dart-define` needed — `flutter build` / `flutter run` works directly
- Firebase project name: `data-babe`

## Git hooks
```bash
git config core.hooksPath .githooks      # Enable pre-commit secrets detection
```

## Firestore data model
```
users/{uid}                              — User profile + familyIds
families/{familyId}                      — Family name + memberUids + allergenCategories[]
families/{familyId}/children/{childId}   — Child records
families/{familyId}/activities/{id}      — Activity entries (all types)
families/{familyId}/carers/{carerId}     — Carer records
families/{familyId}/ingredients/{id}     — Ingredient with name + allergens[]
families/{familyId}/recipes/{id}         — Recipe with name + ingredients[]
families/{familyId}/targets/{id}         — Goals/targets (activityType, metric, period, targetValue)
invites/{id}                             — Email-based family invites
```

## Conventions
- No code generation needed (no Drift, no build_runner)
- Activity types: each type has its own typed fields (not generic columns)
- UUIDs for all entity IDs (not auto-increment)
- Soft delete via `isDeleted` flag on all models (targets also have `isActive`)
- Local dates as ISO 8601 strings (Sembast), Firestore dates as Timestamps
- Ingredient and recipe names stored **lowercase**
- All list screens use **IconButton + confirmation dialog** for deletion (not Dismissible swipe)
- All save/delete operations use **await + try/catch** with SnackBar feedback
- Duplicate checks happen **client-side** in `_save()` before write
- Sembast maps are immutable — always `Map.from()` before mutating
- **Ingredient name uniqueness**: enforced per family at repository level; renaming cascades to recipes, targets, and activities
- **Recipe name uniqueness**: enforced per family at repository level; post-pull dedup merges ingredient lists
- **Allergen category rename/delete**: cascades to ingredients, targets, and activities via `FamilyRepository`
- **Dedup logic**: shared `DedupHelper` used by SyncEngine, IngredientDedupMigration, and BackupService

## Sync behavior
- **Push**: debounced 30s after writes, immediate on app background, on reconnect
- **Pull**: on app foreground, after push, on reconnect, every 15 min safety net, manual "Sync Now"
- **Conflict resolution**: last-write-wins on `modifiedAt`
- **Delta sync**: all collections (including children, carers) use `where('modifiedAt', isGreaterThan: lastPull)`
- **Queue collapse**: multiple writes to same document produce one push
- **Initial sync**: on login, fetches `familyIds` from user doc, pulls all data
- **Logout**: best-effort push → `clearLocalData()` (drops all stores) → sign out
- **Error logging**: `debugPrint('[Sync] ...')` in all catch blocks (stripped in release)
- **Atomic write+queue**: All syncing wrappers use `_db.transaction()` to atomically write data AND enqueue the sync entry — prevents orphaned local data if the app crashes between the two operations

## Features implemented
- **Core tracking**: feeds (bottle/breast), diapers, potty, meds, solids, pump, growth, temperature, tummy time, indoor/outdoor play, bath, skin-to-skin
- **Timeline**: calendar day/week/month and rolling 24h/7d/30d views with summary cards
- **Charts**: fl_chart visualisations
- **CSV import**: parse exported CSV with preview, filtering (date range, activity type), and row selection before import
- **Multi-parent collaboration**: email invites, family groups, carer roles
- **Recipes**: create/edit/delete recipes with ingredient lists; allergen warnings derived from ingredients
- **Ingredients**: create/edit/delete with allergen category tags; duplicate name prevention
- **Allergen tracking**: family-level allergen categories; exposure counting in goals
- **Goals/targets**: per-child targets (count, volume, duration, unique foods, ingredient/allergen exposures) with daily/weekly/monthly periods and progress bars
- **Activity editing**: tap timeline entries to edit
- **Copy/duplicate entry**: one-tap copy from edit AppBar or long-press context menu, pre-fills form with source data and time set to "now"
- **Bulk add activities**: stage multiple activities from templates (copy from day) or quick-add chips, adjust times, save all at once
- **Activity deletion**: soft delete with confirmation
- **Offline support**: local-first with Sembast, background sync to Firestore
- **Sync indicators**: status dot in nav bar, Sync Now button in Settings
- **Initial sync**: automatic full pull after login via `initialSyncProvider`
- **Logout cleanup**: best-effort push, local data wipe, offline warning if unsynced changes
- **CSV import dedup**: fingerprint-based dedup prevents duplicate entries on re-import
- **Backup/restore**: JSON export/import of family data with last-write-wins merge
- **Separate date/time pickers**: date and time can be edited independently on log entry screen
- **Inline ingredient creation**: create new ingredients with allergen tags directly from solids log entry
- **Smart home summary**: status banner shows actual/target format, weekly/monthly targets with period labels, sorted by urgency
- **GitHub Releases**: tag-triggered CI builds signed APK + AAB

## Releasing

### GitHub Releases (current)
1. Update `version` in `pubspec.yaml` (e.g., `1.1.0+2`)
2. Commit and push to `main`
3. Tag the commit: `git tag v1.1.0 && git push origin v1.1.0`
4. The `release.yml` workflow automatically:
   - Builds a signed APK and AAB
   - Creates a GitHub Release with auto-generated release notes
   - Attaches `datababe-1.1.0.apk` and `datababe-1.1.0.aab`
5. Share the APK download link with users

### Required GitHub secrets
| Secret | Description |
|--------|-------------|
| `RELEASE_KEYSTORE` | Base64-encoded `datababe-release.jks` |
| `KEYSTORE_PASSWORD` | Keystore password (from `android/key.properties`) |
| `KEY_PASSWORD` | Key password (same as keystore password) |
| `FIREBASE_SERVICE_ACCOUNT` | Firebase service account JSON (for web deploy) |

### Android signing
- Release keystore: `android/app/datababe-release.jks` (gitignored)
- Key properties: `android/key.properties` (gitignored)
- `build.gradle.kts` auto-detects `key.properties` — falls back to debug signing when absent

### Future: Google Play Store
- AAB is already built by the release workflow
- Will need: Play Developer account ($25), store listing, privacy policy, content rating
- Upload the `.aab` from the GitHub Release to Play Console

## Privacy
- Never commit real user data (CSV files, personal names, health data)
- Sample/test data uses fake values only
- `.gitignore` excludes `*.csv`, `data/`, `private/`, `instructions.txt`
