# E2E Test Plan: Headless Full-App Widget Tests (v2)

## Goal

Build a **rigorous, comprehensive** suite of headless widget tests that boot the full `DataBabeApp` with real GoRouter routing, in-memory Sembast, and controllable fakes for Firebase/auth/sync. These tests exercise **every button, every tab, every UI component** across realistic user journeys — including sync failure simulation, multi-user scenarios, data import/export, migration, and reconciliation edge cases.

**Key constraint**: Widget tests (not integration tests) so they run headlessly on CI without Xvfb. `flutter test` is all that's needed.

---

## Architecture

### What's Real vs Faked

| Layer | Real / Fake | Why |
|-------|-------------|-----|
| `DataBabeApp` + `GoRouter` | **Real** | Catches routing/wiring bugs |
| `ShellScaffold` (bottom nav + sync dot) | **Real** | Tests navigation + sync indicator |
| All screen widgets | **Real** | Tests all UI rendering and interactions |
| Sembast database | **Real** (in-memory) | Tests actual data flow through repos |
| Local repositories | **Real** | Tests actual CRUD + uniqueness + cascade |
| Syncing repositories | **Real** | Tests atomic transaction wrapping |
| `SyncQueue` | **Real** | Backed by in-memory Sembast — queue entries are observable |
| `SyncMetadata` | **Real** | Backed by in-memory Sembast |
| `BackupService` | **Real** | Backed by in-memory Sembast — testable without platform plugins |
| `CsvImporter` | **Real** | Backed by real repos — testable with string input |
| `DedupHelper` | **Real** | Backed by in-memory Sembast |
| `IngredientDedupMigration` | **Real** | Backed by in-memory Sembast |
| `SyncEngine` | **Controllable Fake** | Simulates idle/syncing/error/offline states |
| Firebase Auth | **Fake** | No Google Sign-In |
| `ConnectivityMonitor` | **Controllable Fake** | Simulates online/offline transitions |
| `InviteRepository` | **Controllable Fake** | Simulates pending invites for multi-user scenarios |
| `initialSyncProvider` | **Override** | Controllable: complete/loading/error |
| `FilePicker` / `FileSaver` | **Bypassed** | Platform plugins — test BackupService/CsvImporter directly via harness |

### Provider Override Strategy

```
authStateProvider ← OVERRIDE (controllable: logged-in / logged-out)
currentUserProvider ← OVERRIDE (controllable: user A / user B / null)
localDatabaseProvider ← OVERRIDE (in-memory Sembast)
initialSyncProvider ← OVERRIDE (controllable: complete / loading / error)
syncEngineProvider ← OVERRIDE (ControllableSyncEngine with state injection)
connectivityMonitorProvider ← OVERRIDE (ControllableConnectivityMonitor)
syncStatusProvider ← OVERRIDE (controllable stream)
isOnlineProvider ← OVERRIDE (controllable stream)
lastSyncTimeProvider ← OVERRIDE (controllable)
pendingSyncCountProvider ← OVERRIDE (reads from real SyncQueue)
inviteRepositoryProvider ← OVERRIDE (ControllableInviteRepository)
pendingInvitesProvider ← OVERRIDE (controllable stream)
familyInvitesProvider ← OVERRIDE (controllable stream)
selectedDateProvider ← OVERRIDE (fixed to seed data date for determinism)
```

### The `firebase_auth.User` Problem

`firebase_auth.User` is **sealed** — cannot instantiate or subclass.

**Recommended solution**: Refactor `currentUserProvider` to return `AppUser?` instead of `User?`. The app already has `AppUser` in `lib/models/app_user.dart`. This is a focused refactor (~10 files) that:
- Decouples all screens from `firebase_auth`
- Makes `currentUserProvider` trivially overridable with `AppUser(uid: 'test-uid', email: 'test@example.com', displayName: 'Test User')`
- Confines `firebase_auth.User` to `authStateProvider` and `authRepositoryProvider` only

**Fallback**: Use `firebase_auth_mocks` package if the refactor is too invasive.

### `SyncEngine` Testability

**Required refactor**: Extract `SyncEngineInterface` with the public API:
```dart
abstract class SyncEngineInterface {
  void start();
  void dispose();
  void notifyWrite();
  Future<SyncResult> syncNow();
  Future<int> get pendingCount;
  Stream<SyncStatus> get statusStream;
  Future<DateTime?> get lastSyncTime;
  Future<void> clearLocalData();
  Future<Map<String, dynamic>> getDiagnostics(String familyId);
  Future<void> initialSync(List<String> familyIds);
  Future<void> forceFullResync(List<String> familyIds);
  Future<List<String>> fetchFamilyIds();
}
```

Both `SyncEngine` and `ControllableSyncEngine` implement this interface. Syncing repositories accept `SyncEngineInterface` instead of `SyncEngine`.

---

## Shared Test Harness

**File**: `test/e2e/test_harness.dart`

### `TestHarness` Class

```dart
class TestHarness {
  late Database db;
  final _syncStatusController = StreamController<SyncStatus>.broadcast();
  final _onlineController = StreamController<bool>.broadcast();
  final _pendingInvitesController = StreamController<List<InviteModel>>.broadcast();
  final _familyInvitesController = StreamController<List<InviteModel>>.broadcast();

  /// Current simulated sync status.
  void setSyncStatus(SyncStatus status) => _syncStatusController.add(status);
  void setOnline(bool online) => _onlineController.add(online);
  void setPendingInvites(List<InviteModel> invites) => _pendingInvitesController.add(invites);
  void setFamilyInvites(List<InviteModel> invites) => _familyInvitesController.add(invites);

  Future<void> setUp() async {
    db = await databaseFactoryMemory.openDatabase('e2e_test_${_counter++}');
  }

  Future<void> tearDown() async {
    await db.close();
    await _syncStatusController.close();
    await _onlineController.close();
    await _pendingInvitesController.close();
    await _familyInvitesController.close();
  }

  Widget buildApp({
    bool authenticated = true,
    bool initialSyncComplete = true,
    String? initialSyncError,
    SyncStatus initialSyncStatus = SyncStatus.idle,
    bool initialOnline = true,
    String userId = 'test-uid-123',
  }) {
    return ProviderScope(
      overrides: [
        // Auth
        authStateProvider.overrideWith((_) => Stream.value(
          authenticated ? AppUser(uid: userId, email: 'test@example.com', displayName: 'Test User') : null,
        )),
        currentUserProvider.overrideWithValue(
          authenticated ? AppUser(uid: userId, email: 'test@example.com', displayName: 'Test User') : null,
        ),

        // Database
        localDatabaseProvider.overrideWithValue(db),

        // Sync — controllable
        syncEngineProvider.overrideWithValue(ControllableSyncEngine(db)),
        syncStatusProvider.overrideWith((_) => _syncStatusController.stream.isEmpty
          ? Stream.value(initialSyncStatus)
          : _syncStatusController.stream),
        isOnlineProvider.overrideWith((_) => _onlineController.stream.isEmpty
          ? Stream.value(initialOnline)
          : _onlineController.stream),
        lastSyncTimeProvider.overrideWith((_) => Future.value(DateTime.now())),
        pendingSyncCountProvider.overrideWith((_) => SyncQueue(db).pendingCount()),
        connectivityMonitorProvider.overrideWithValue(
          ControllableConnectivityMonitor(initialOnline),
        ),

        // Initial sync
        initialSyncProvider.overrideWith((_) => initialSyncComplete
          ? Future.value(InitialSyncResult(complete: true, error: initialSyncError))
          : Future.delayed(const Duration(days: 1)), // never completes → loading state
        ),

        // Invites
        inviteRepositoryProvider.overrideWithValue(ControllableInviteRepository()),
        pendingInvitesProvider.overrideWith((_) => _pendingInvitesController.stream),
        familyInvitesProvider.overrideWith((_) => _familyInvitesController.stream),

        // Fixed date for deterministic tests
        selectedDateProvider.overrideWith((_) => TestData.now),
      ],
      child: const DataBabeApp(),
    );
  }
}
```

### `TestData` — Comprehensive Seed Data

```dart
class TestData {
  static final now = DateTime(2026, 3, 10, 10, 30);
  static final yesterday = now.subtract(const Duration(days: 1));
  static final lastWeek = now.subtract(const Duration(days: 7));

  // --- Family A (primary user) ---
  static final familyA = FamilyModel(id: 'f1', name: 'Test Family', createdBy: 'test-uid-123',
    memberUids: ['test-uid-123', 'user-b-uid'], allergenCategories: ['egg', 'dairy', 'peanut', 'wheat', 'soy'], ...);
  static final childA = ChildModel(id: 'c1', name: 'Baby', dateOfBirth: DateTime(2025, 9, 1), ...);
  static final childB = ChildModel(id: 'c2', name: 'Toddler', dateOfBirth: DateTime(2023, 6, 15), ...);
  static final carerParent = CarerModel(id: 'cr1', uid: 'test-uid-123', displayName: 'Test User', role: 'parent', ...);
  static final carerOther = CarerModel(id: 'cr2', uid: 'user-b-uid', displayName: 'Partner', role: 'carer', ...);

  // --- Family B (second family for multi-family) ---
  static final familyB = FamilyModel(id: 'f2', name: 'Extended Family', createdBy: 'user-b-uid',
    memberUids: ['test-uid-123', 'user-b-uid'], allergenCategories: ['sesame'], ...);

  // Activities — one per type, all for today (matches selectedDateProvider override)
  static List<ActivityModel> todayActivities() => [
    ActivityModel(id: 'a1', childId: 'c1', type: 'feedBottle', startTime: now.subtract(Duration(hours: 2)),
      feedType: 'formula', volumeMl: 120.0, ...),
    ActivityModel(id: 'a2', childId: 'c1', type: 'feedBreast', startTime: now.subtract(Duration(hours: 4)),
      rightBreastMinutes: 10, leftBreastMinutes: 8, ...),
    ActivityModel(id: 'a3', childId: 'c1', type: 'diaper', startTime: now.subtract(Duration(hours: 3)),
      contents: 'both', contentSize: 'medium', pooColour: 'yellow', pooConsistency: 'soft', ...),
    ActivityModel(id: 'a4', childId: 'c1', type: 'solids', startTime: now.subtract(Duration(hours: 1)),
      foodDescription: 'scrambled eggs', reaction: 'loved', recipeId: 'r1',
      ingredientNames: ['egg', 'milk'], allergenNames: ['egg', 'dairy'], ...),
    ActivityModel(id: 'a5', childId: 'c1', type: 'meds', startTime: now.subtract(Duration(hours: 5)),
      medicationName: 'Vitamin D', dose: '5', doseUnit: 'drops', ...),
    ActivityModel(id: 'a6', childId: 'c1', type: 'growth', startTime: now,
      weightKg: 8.5, lengthCm: 72.0, headCircumferenceCm: 45.0, ...),
    ActivityModel(id: 'a7', childId: 'c1', type: 'tummyTime', startTime: now.subtract(Duration(hours: 6)),
      durationMinutes: 15, ...),
    ActivityModel(id: 'a8', childId: 'c1', type: 'pump', startTime: now.subtract(Duration(hours: 7)),
      volumeMl: 60.0, durationMinutes: 20, ...),
    ActivityModel(id: 'a9', childId: 'c1', type: 'temperature', startTime: now, tempCelsius: 36.8, ...),
    ActivityModel(id: 'a10', childId: 'c1', type: 'bath', startTime: yesterday, durationMinutes: 10, ...),
    ActivityModel(id: 'a11', childId: 'c1', type: 'indoorPlay', startTime: yesterday, durationMinutes: 30, ...),
    ActivityModel(id: 'a12', childId: 'c1', type: 'outdoorPlay', startTime: yesterday, durationMinutes: 45, ...),
    ActivityModel(id: 'a13', childId: 'c1', type: 'skinToSkin', startTime: yesterday, durationMinutes: 20, ...),
    ActivityModel(id: 'a14', childId: 'c1', type: 'potty', startTime: now, contents: 'pee', contentSize: 'small', ...),
  ];

  // Historical activities for trends/insights (last 7 days)
  static List<ActivityModel> historicalActivities() => [ /* 30-50 activities spread across the week */ ];

  // Ingredients
  static List<IngredientModel> ingredients() => [
    IngredientModel(id: 'i1', name: 'egg', allergens: ['egg'], createdBy: 'test-uid-123', ...),
    IngredientModel(id: 'i2', name: 'milk', allergens: ['dairy'], createdBy: 'test-uid-123', ...),
    IngredientModel(id: 'i3', name: 'bread', allergens: ['wheat'], createdBy: 'test-uid-123', ...),
    IngredientModel(id: 'i4', name: 'butter', allergens: ['dairy'], createdBy: 'test-uid-123', ...),
    IngredientModel(id: 'i5', name: 'banana', allergens: [], createdBy: 'test-uid-123', ...),
  ];

  // Recipes
  static List<RecipeModel> recipes() => [
    RecipeModel(id: 'r1', name: 'scrambled eggs', ingredients: ['egg', 'milk', 'butter'], createdBy: 'test-uid-123', ...),
    RecipeModel(id: 'r2', name: 'toast with butter', ingredients: ['bread', 'butter'], createdBy: 'test-uid-123', ...),
    RecipeModel(id: 'r3', name: 'banana mash', ingredients: ['banana'], createdBy: 'test-uid-123', ...),
  ];

  // Targets (mix of allergen and non-allergen)
  static List<TargetModel> targets() => [
    TargetModel(id: 't1', childId: 'c1', activityType: 'solids', metric: 'count', period: 'daily', targetValue: 3, ...),
    TargetModel(id: 't2', childId: 'c1', activityType: 'solids', metric: 'allergenExposures', period: 'weekly',
      targetValue: 2, allergenName: 'egg', ...),
    TargetModel(id: 't3', childId: 'c1', activityType: 'solids', metric: 'allergenExposures', period: 'weekly',
      targetValue: 2, allergenName: 'dairy', ...),
    TargetModel(id: 't4', childId: 'c1', activityType: 'feedBottle', metric: 'totalVolumeMl', period: 'daily',
      targetValue: 600, ...),
    TargetModel(id: 't5', childId: 'c1', activityType: 'tummyTime', metric: 'totalDurationMinutes', period: 'daily',
      targetValue: 30, ...),
  ];

  /// Full seed: inserts everything into Sembast for a "normal user with data" scenario.
  static Future<void> seedFull(Database db) async { /* all of the above */ }

  /// Minimal seed: just family + child + carer (no activities/ingredients/recipes/targets).
  static Future<void> seedMinimal(Database db) async { /* family, child, carer only */ }

  /// Empty seed: no data at all (new user scenario).
  static Future<void> seedEmpty(Database db) async { /* nothing */ }

  /// Multi-family seed: two families, user is member of both.
  static Future<void> seedMultiFamily(Database db) async { /* familyA + familyB */ }

  /// Multi-carer seed: family with two carers (parent + carer roles).
  static Future<void> seedMultiCarer(Database db) async { /* familyA + carerParent + carerOther */ }
}
```

### Controllable Fakes

```dart
/// Sync engine that records calls and allows state injection.
class ControllableSyncEngine implements SyncEngineInterface {
  final Database _db;
  int notifyWriteCount = 0;
  int syncNowCount = 0;
  bool clearLocalDataCalled = false;
  SyncResult nextSyncResult = SyncResult.empty;

  ControllableSyncEngine(this._db);

  @override void start() {}
  @override void dispose() {}
  @override void notifyWrite() => notifyWriteCount++;
  @override Future<SyncResult> syncNow() async { syncNowCount++; return nextSyncResult; }
  @override Future<int> get pendingCount => SyncQueue(_db).pendingCount();
  @override Stream<SyncStatus> get statusStream => Stream.value(SyncStatus.idle);
  @override Future<DateTime?> get lastSyncTime async => DateTime.now();
  @override Future<void> clearLocalData() async { clearLocalDataCalled = true; }
  @override Future<Map<String, dynamic>> getDiagnostics(String familyId) async => {};
  @override Future<void> initialSync(List<String> familyIds) async {}
  @override Future<void> forceFullResync(List<String> familyIds) async {}
  @override Future<List<String>> fetchFamilyIds() async => [];
}

/// Connectivity monitor with controllable state.
class ControllableConnectivityMonitor implements ConnectivityMonitor {
  bool _isOnline;
  final _onlineController = StreamController<bool>.broadcast();
  final _restoredController = StreamController<void>.broadcast();

  ControllableConnectivityMonitor(this._isOnline);

  void goOnline() { _isOnline = true; _onlineController.add(true); _restoredController.add(null); }
  void goOffline() { _isOnline = false; _onlineController.add(false); }

  @override bool get isOnline => _isOnline;
  @override Stream<bool> get onlineStream => _onlineController.stream;
  @override Stream<void> get onConnectivityRestored => _restoredController.stream;
  @override void dispose() { _onlineController.close(); _restoredController.close(); }
}

/// Invite repository with controllable responses.
class ControllableInviteRepository implements InviteRepository {
  final createdInvites = <InviteModel>[];
  final acceptedInviteIds = <String>[];
  final declinedInviteIds = <String>[];
  final cancelledInviteIds = <String>[];
  Exception? nextError;

  @override Future<void> createInvite(InviteModel invite) async {
    if (nextError != null) throw nextError!;
    createdInvites.add(invite);
  }
  @override Future<void> acceptInvite({required InviteModel invite, required String uid, required String displayName}) async {
    if (nextError != null) throw nextError!;
    acceptedInviteIds.add(invite.id);
  }
  @override Future<void> declineInvite(String inviteId) async { declinedInviteIds.add(inviteId); }
  @override Future<void> cancelInvite(String inviteId) async { cancelledInviteIds.add(inviteId); }
  @override Stream<List<InviteModel>> watchPendingInvites(String email) => Stream.value([]);
  @override Stream<List<InviteModel>> watchFamilyInvites(String familyId) => Stream.value([]);
}
```

---

## Test Files and Coverage

### File Structure

```
test/e2e/
  test_harness.dart                   — Shared harness, controllable fakes, seed data
  auth_flow_test.dart                 — Login/logout/redirect/deep links
  navigation_test.dart                — All 5 tabs, modals, back nav, deep links
  home_screen_test.dart               — Setup prompt, invite prompt, quick-log, today list, status banner
  activity_crud_test.dart             — Log/edit/delete for all 14 types, full field coverage
  activity_solids_deep_test.dart      — Solids: recipe picker, ingredient autocomplete, allergen derivation
  timeline_test.dart                  — All 6 window modes, filter, date nav, summary, empty state
  insights_test.dart                  — All 5 sections, period toggle, navigation, empty states
  goals_test.dart                     — Add/delete/bulk targets, grouping, expand/collapse, form validation
  ingredients_crud_test.dart          — Full CRUD, search, allergen chips, duplicate prevention, cascade verify
  recipes_crud_test.dart              — Full CRUD, search, ingredient chips, allergen derivation, duplicate prevention
  allergen_management_test.dart       — Add/rename/delete with cascade verification through to activities
  settings_test.dart                  — All tiles, navigation, sync status display, diagnostics
  family_management_test.dart         — Children CRUD, carer roles, member removal, child switching
  multi_user_test.dart                — Two-carer family, role-based UI differences, invite flows
  multi_family_test.dart              — Family switching, data isolation, child selection persistence
  sync_simulation_test.dart           — Sync states, offline mode, queue behavior, error recovery
  backup_restore_test.dart            — Export/import via BackupService, merge semantics, dedup
  csv_import_test.dart                — Import via CsvImporter, dedup, error handling
  migration_dedup_test.dart           — IngredientDedupMigration, DedupHelper through UI
  data_cascade_test.dart              — Ingredient rename → recipe/target/activity cascade visible in UI
  error_resilience_test.dart          — Error states, boundary conditions, empty data, malformed input
  user_journey_test.dart              — Multi-step workflows simulating real user sessions
```

---

### 1. `auth_flow_test.dart` (~8 tests)

| # | Test | Description |
|---|------|-------------|
| 1 | Unauthenticated → login screen | `authenticated: false` → verify "Sign in with Google" button, "DataBabe" branding, child_care icon |
| 2 | Authenticated → home screen | `authenticated: true` + seedFull → verify child name in app bar |
| 3 | Deep link /timeline while unauthenticated → redirect to /login | Set initial location, verify redirect |
| 4 | Deep link /settings/allergens while unauthenticated → redirect to /login | |
| 5 | Authenticated with no family → setup prompt | seedEmpty → verify "Welcome to DataBabe", "Add your child to get started" |
| 6 | Sign Out tile visible on settings | Navigate to settings → verify "Sign Out" ListTile |
| 7 | Sign Out tap triggers confirmation when offline with pending changes | Set offline + add queue entries → tap Sign Out → verify "Unsynced changes" dialog |
| 8 | Initial sync loading state | `initialSyncComplete: false` → verify "Syncing your data..." with CircularProgressIndicator |

---

### 2. `navigation_test.dart` (~16 tests)

| # | Test | Description |
|---|------|-------------|
| 1 | Bottom nav shows 5 labeled destinations | Verify Home, Timeline, Insights, Family, Settings |
| 2 | Home tab selected by default | Verify selectedIndex == 0 |
| 3 | Tap Timeline | Verify "Timeline" in AppBar |
| 4 | Tap Insights | Verify "Insights" in AppBar |
| 5 | Tap Family | Verify "Family" in AppBar |
| 6 | Tap Settings | Verify "Settings" in AppBar |
| 7 | Tap Home from Settings | Verify return to home screen |
| 8 | Sync dot visible in shell | Find Container with green color and circle shape |
| 9 | Sync dot changes color for offline | Set `initialSyncStatus: SyncStatus.offline` → verify grey dot |
| 10 | Sync dot changes color for error | Set `initialSyncStatus: SyncStatus.error` → verify red dot |
| 11 | Sync dot changes color for syncing | Set `initialSyncStatus: SyncStatus.syncing` → verify amber dot |
| 12 | Modal: Settings → Goals | Tap "Goals" on settings → verify GoalsScreen renders |
| 13 | Modal: Settings → Ingredients | Tap "Manage Ingredients" → verify IngredientListScreen |
| 14 | Modal: Settings → Recipes | Tap "Manage Recipes" → verify RecipeListScreen |
| 15 | Modal: Settings → Allergens | Tap "Manage Allergens" → verify ManageAllergensScreen |
| 16 | Nested modal: Ingredients → Add | From IngredientListScreen, tap FAB → verify AddIngredientScreen |

---

### 3. `home_screen_test.dart` (~14 tests)

| # | Test | Description |
|---|------|-------------|
| 1 | Child name in app bar | seedFull → verify "Baby" in SliverAppBar |
| 2 | Quick-log grid: all 14 chips present | Verify ActionChip labels: Bottle, Breast, Diaper, Meds, Solids, Growth, Tummy Time, Pump, Temperature, Bath, Indoor Play, Outdoor Play, Skin to Skin, Potty |
| 3 | Quick-log chip icons | Verify each chip has the correct icon |
| 4 | Tap Bottle chip → LogEntryScreen | Tap "Bottle" → verify "Log Bottle" in AppBar |
| 5 | Tap Solids chip → LogEntryScreen | Tap "Solids" → verify "Log Solids" in AppBar |
| 6 | Today section header | Verify "Today" text |
| 7 | Today shows activity tiles | Verify ActivityTile widgets for seeded activities |
| 8 | Empty today: "No activities logged today" | seedMinimal (no activities) → verify message |
| 9 | Status banner with metrics | seedFull (with targets) → verify metric text in status card |
| 10 | Status banner tap → insights | Tap status card → verify "Insights" in AppBar |
| 11 | Setup prompt: no families | seedEmpty → verify "Welcome to DataBabe", "Add your child", name field, DOB picker |
| 12 | Setup prompt: fill form and create family | Enter name, pick date, tap "Add Child" → verify home screen with child name |
| 13 | Invite pending prompt: with pending invites | seedEmpty + inject pending invites → verify "You have been invited!", Accept/Decline buttons |
| 14 | Invite pending prompt: "Create my own family instead" | Tap → verify SetupPrompt shown |

---

### 4. `activity_crud_test.dart` (~28 tests)

Each of the 14 types gets 2 tests: (a) render + fields verification, (b) fill + save + verify persisted.

| # | Type | Test A: Fields Rendered | Test B: Save & Verify |
|---|------|------------------------|----------------------|
| 1-2 | feedBottle | SegmentedButton (Formula/Breast Milk), Volume (ml) field | Select formula, enter 120ml, save → verify in DB |
| 3-4 | feedBreast | Right breast (min), Left breast (min) fields | Enter 10/8, save → verify |
| 5-6 | diaper | Contents (Pee/Poo/Both), Size (S/M/L), Colour dropdown, Consistency dropdown | Select Poo+Medium+Yellow+Soft, save → verify |
| 7-8 | meds | Medication name, Dose, Unit fields | Enter "Vitamin D", "5", "drops", save → verify |
| 9-10 | solids | Food description, Reaction (Loved/Meh/Disliked/N/A), Recipe picker button, Ingredient autocomplete | Enter description, select reaction, save → verify |
| 11-12 | growth | Weight (kg), Length (cm), Head circumference (cm) | Enter 8.5/72/45, save → verify |
| 13-14 | tummyTime | No type-specific fields (duration only) + Notes | Save → verify |
| 15-16 | pump | Volume (ml) field | Enter 60, save → verify |
| 17-18 | temperature | Temperature (°C) field | Enter 36.8, save → verify |
| 19-20 | bath | No type-specific fields + Notes | Save → verify |
| 21-22 | indoorPlay | No type-specific fields + Notes | Save → verify |
| 23-24 | outdoorPlay | No type-specific fields + Notes | Save → verify |
| 25-26 | skinToSkin | No type-specific fields + Notes | Save → verify |
| 27-28 | potty | Contents (Pee/Poo/Both), Size (S/M/L) | Select Pee+Small, save → verify |

**Additional activity tests (~8):**

| # | Test | Description |
|---|------|-------------|
| 29 | Edit existing activity | Seed an activity, navigate to `/log/feedBottle?id=a1` → verify pre-filled fields |
| 30 | Edit: change volume and save | Modify volume → save → verify updated in DB |
| 31 | Delete from edit screen | Tap delete icon → confirm dialog → verify soft-deleted |
| 32 | Delete confirmation dialog text | Verify "Delete entry?" and "This action cannot be undone." |
| 33 | Cancel delete returns to edit | Tap Cancel in delete dialog → verify still on edit screen |
| 34 | Diaper "Both" shows pee size selector | Select "Both" → verify extra pee size SegmentedButton appears |
| 35 | Notes field available for all types | Verify "Notes" TextFormField on every type |
| 36 | Save button disabled while saving | Tap save → verify button shows CircularProgressIndicator |

---

### 5. `activity_solids_deep_test.dart` (~10 tests)

The solids form is the most complex — deserves dedicated deep testing.

| # | Test | Description |
|---|------|-------------|
| 1 | Recipe picker button visible | Verify "Pick a Recipe" OutlinedButton |
| 2 | Pick recipe → fills ingredients + allergens | Tap picker → select "scrambled eggs" → verify ingredient names chip, allergen warning chips |
| 3 | Clear recipe | After picking, tap delete on recipe chip → verify cleared |
| 4 | Standalone ingredient autocomplete | Type "egg" → verify autocomplete suggestion → select → verify chip appears |
| 5 | Remove standalone ingredient | Tap delete on ingredient chip → verify removed |
| 6 | Allergen chips derived automatically | Add "egg" ingredient → verify "egg" allergen warning chip appears |
| 7 | Multiple ingredients with mixed allergens | Add egg + bread → verify both "egg" and "wheat" allergen chips |
| 8 | Reaction selector: all 4 options | Verify Loved/Meh/Disliked/N/A segments, tap each |
| 9 | No recipes → shows snackbar | Clear all recipes from DB → tap Pick a Recipe → verify "No recipes yet" snackbar |
| 10 | Save solids with recipe + verify DB | Pick recipe, save → verify activity has recipeId, ingredientNames, allergenNames |

---

### 6. `timeline_test.dart` (~12 tests)

| # | Test | Description |
|---|------|-------------|
| 1 | Shows today's activities | seedFull → verify ActivityTile widgets |
| 2 | Empty range: "No activities in this period" | Navigate to a date with no activities → verify message |
| 3 | Granularity toggle: Day/Week/Month | Tap each → verify SegmentedButton selection |
| 4 | Calendar/Rolling toggle | Tap → verify label changes |
| 5 | Calendar day: back arrow navigates | Tap chevron_left → verify date label changes |
| 6 | Calendar day: forward arrow disabled at today | Verify forward arrow is null/disabled |
| 7 | Activity type filter: open dropdown | Tap filter icon → verify all 14 types in popup menu |
| 8 | Filter by Bottle | Select "Bottle" → verify only bottle activities shown |
| 9 | Filter badge visible when active | After selecting filter → verify Badge isLabelVisible |
| 10 | Clear filter: "All activities" | Select "All activities" → verify all shown again |
| 11 | SummaryCard visible with activities | Verify SummaryCard widget renders |
| 12 | Activity delete from timeline | Tap delete on activity tile → verify SnackBar with undo |

---

### 7. `insights_test.dart` (~14 tests)

| # | Test | Description |
|---|------|-------------|
| 1 | Empty state: no activities | seedMinimal → verify "Start logging activities to see insights" |
| 2 | Today section: progress rings | seedFull → verify ProgressRing widgets |
| 3 | Today section: ring tap → metric detail | Tap a ring → verify MetricDetailScreen |
| 4 | Allergen tracker: progress bar | Verify LinearProgressIndicator and "X/Y covered" text |
| 5 | Allergen tracker: period toggle 7d/14d | Tap segments → verify text updates |
| 6 | Allergen tracker: "Needs attention" items | Seed overdue allergens → verify warning icons and names |
| 7 | Allergen tracker: "All on track" | Seed all covered allergens → verify check_circle + "All on track" |
| 8 | Allergen tracker: "All ▸" → detail screen | Tap → verify AllergenDetailScreen |
| 9 | No allergen categories: "Manage Allergens" prompt | Remove allergenCategories → verify prompt with TextButton |
| 10 | Weekly matrix: exposed filter | Verify "Exposed" / "All" toggle |
| 11 | Growth section: latest stats | Verify weight/length/head values |
| 12 | Growth section: tap → detail | Tap → verify GrowthDetailScreen |
| 13 | Trend section: metric toggle | Verify Feed/Diapers/Solids/Tummy Time segments |
| 14 | Trend section: period toggle 7d/30d | Verify period segments |

---

### 8. `goals_test.dart` (~14 tests)

| # | Test | Description |
|---|------|-------------|
| 1 | Allergen goals section header | Verify "Allergen Goals (weekly)" |
| 2 | Other goals section header | Verify "Other Goals" |
| 3 | Aggregate progress: "X/Y on track" | Verify text |
| 4 | LinearProgressIndicator visible | Verify widget |
| 5 | Expand allergen list | Tap "Show all" → verify allergen names |
| 6 | Collapse allergen list | Tap "Hide" → verify names hidden |
| 7 | Delete from expanded list | Tap delete icon → verify "Delete goal?" dialog |
| 8 | Other goals render as Cards | Verify Card + progress text |
| 9 | FAB → AddTargetScreen | Tap FAB → verify "Add Goal" in AppBar |
| 10 | AddTargetScreen: activity type dropdown | Verify all 14 types in dropdown |
| 11 | AddTargetScreen: metric changes with type | Select "Solids" → verify allergenExposures metric available |
| 12 | AddTargetScreen: period toggle (Daily/Weekly/Monthly) | Verify 3 segments |
| 13 | AddTargetScreen: save with validation | Leave value empty → tap Save → verify error snackbar |
| 14 | Bulk allergen targets | Navigate → verify checkboxes for all categories, "Select all"/"Clear", save count |

---

### 9. `ingredients_crud_test.dart` (~14 tests)

| # | Test | Description |
|---|------|-------------|
| 1 | List shows count in title | Verify "Ingredients (5)" |
| 2 | All seeded ingredients visible | Verify egg, milk, bread, butter, banana |
| 3 | Allergen chips on ingredient cards | Verify "egg" chip on egg ingredient |
| 4 | Search: type "egg" | Verify only egg visible |
| 5 | Search: type "xyz" | Verify "No matching ingredients" |
| 6 | Search: clear returns all | Clear search → verify all 5 visible |
| 7 | FAB → AddIngredientScreen | Tap + → verify "New Ingredient" title |
| 8 | Add form: allergen FilterChips | Verify all 5 family allergen categories as FilterChips |
| 9 | Add: fill name + select allergens + save | Enter "peanut butter", select "peanut" chip → save → verify new ingredient in list |
| 10 | Duplicate name: error snackbar | Try creating "egg" again → verify DuplicateNameException snackbar |
| 11 | Edit: tap card → prefilled | Tap "egg" → verify name field shows "egg", "egg" allergen selected |
| 12 | Edit: change allergen and save | Add "dairy" allergen to egg → save → verify updated |
| 13 | Delete: confirmation dialog | Tap delete_outline → verify dialog "Delete ingredient?" with ingredient name |
| 14 | Delete: confirm → ingredient removed | Confirm → verify ingredient gone from list, verify snackbar |

---

### 10. `recipes_crud_test.dart` (~14 tests)

| # | Test | Description |
|---|------|-------------|
| 1 | List shows count in title | Verify "Recipes (3)" |
| 2 | All seeded recipes visible | Verify scrambled eggs, toast with butter, banana mash |
| 3 | Ingredient chips on recipe cards | Verify "egg", "milk", "butter" chips on scrambled eggs |
| 4 | Allergen warning chips derived | Verify "egg", "dairy" allergen chips on scrambled eggs card |
| 5 | Search: type "toast" | Verify only toast visible |
| 6 | FAB → AddRecipeScreen | Tap + → verify "New Recipe" title |
| 7 | Add form: ingredient autocomplete | Type "egg" → verify autocomplete suggestion |
| 8 | Add form: ingredient chips with delete | Add ingredient → verify chip → tap delete → verify removed |
| 9 | Add form: derived allergen chips | Add "egg" ingredient → verify allergen warning chip appears |
| 10 | Add: save requires ingredients | Enter name only → tap Save → verify "Add at least one ingredient" snackbar |
| 11 | Add: fill + save + verify in list | Enter "omelette", add egg+milk → save → verify in recipe list |
| 12 | Duplicate name: error snackbar | Try creating "scrambled eggs" → verify error snackbar |
| 13 | Edit: tap card → prefilled | Tap "scrambled eggs" → verify name + ingredient chips |
| 14 | Delete: confirm → recipe removed | Tap delete → confirm → verify gone + snackbar |

---

### 11. `allergen_management_test.dart` (~10 tests)

| # | Test | Description |
|---|------|-------------|
| 1 | Shows all 5 seeded categories | Verify egg, dairy, peanut, wheat, soy chips |
| 2 | Usage count on chips | Verify "egg (1)" (1 ingredient uses it) |
| 3 | Add new category | Type "sesame", tap add → verify chip appears |
| 4 | Add duplicate: silently ignored | Type "egg", tap add → verify no duplicate chip |
| 5 | Rename: tap chip → dialog | Tap "egg" label → verify rename dialog with text field |
| 6 | Rename: fill new name → verify updated | Type "chicken egg" → tap Rename → verify chip updated |
| 7 | Rename: duplicate name → error snackbar | Try renaming to "dairy" → verify error |
| 8 | Delete: no usage → simple confirm | Delete "soy" (0 ingredients) → verify dialog "Remove "soy"?" |
| 9 | Delete: with usage → cascade warning | Delete "egg" (1 ingredient) → verify dialog mentions "1 ingredient" and "ingredients, targets, and activities" |
| 10 | Delete: confirm → verify cascade | Confirm → verify chip gone + ingredient's allergen list updated |

---

### 12. `settings_test.dart` (~10 tests)

| # | Test | Description |
|---|------|-------------|
| 1 | Account section: user info | Verify "Test User" display name and "test@example.com" email |
| 2 | Account section: Sign Out tile | Verify ListTile with logout icon |
| 3 | Data section: all tiles present | Verify Manage Allergens, Manage Ingredients, Manage Recipes, Goals, Import CSV, Export Backup, Restore Backup |
| 4 | Sync section: Sync Now tile | Verify "Sync Now" with status subtitle |
| 5 | Sync section: status shows "Synced" | With idle status → verify "Synced" in subtitle |
| 6 | Sync section: status shows pending count | With queue entries → verify "(N pending)" |
| 7 | Diagnostics tile | Verify "Diagnostics" + "Check local DB state" |
| 8 | Navigate to Manage Allergens | Tap → verify ManageAllergensScreen |
| 9 | Navigate to Goals | Tap → verify GoalsScreen |
| 10 | Sync dot reflects status | Verify green dot in shell with idle status |

---

### 13. `family_management_test.dart` (~14 tests)

| # | Test | Description |
|---|------|-------------|
| 1 | Members section: carer cards | seedMultiCarer → verify "Test User" and "Partner" cards |
| 2 | Role chips: parent/carer | Verify "parent" chip on first carer, "carer" on second |
| 3 | Parent sees manage menu on non-self carers | Verify PopupMenuButton on partner card (not on self) |
| 4 | Carer role user: no manage menu | Switch to carer user → verify no PopupMenuButton |
| 5 | Change role dialog | Tap "Change role" → verify DropdownButtonFormField |
| 6 | Remove member dialog | Tap "Remove" → verify confirmation with member name |
| 7 | Children section: child cards | Verify "Baby" card with DOB |
| 8 | Selected child: check icon | Verify check_circle on selected child |
| 9 | Tap another child: switches selection | Seed 2 children → tap second → verify selection changes |
| 10 | Add child FAB: dialog fields | Tap FAB → verify "Add Child" dialog with name field + date picker |
| 11 | Invite carer: dialog fields | Tap person_add icon → verify dialog with email field + role dropdown |
| 12 | Invite carer: send | Fill email + tap "Send Invite" → verify inviteRepository.createInvite called |
| 13 | No children: "No children added yet" | Seed family without children → verify message |
| 14 | Creator cannot be managed | Verify creator carer has no PopupMenuButton even for parent user |

---

### 14. `multi_user_test.dart` (~8 tests)

Simulates two-user family interactions by switching `currentUserProvider`.

| # | Test | Description |
|---|------|-------------|
| 1 | User A (parent) sees full management | Verify invite button, manage menus on other carers |
| 2 | User B (carer) sees restricted UI | Switch to user B → verify no invite button, no manage menus |
| 3 | Carer cannot remove parent | Switch to carer user → verify parent has no PopupMenuButton |
| 4 | Both users see same children | Verify identical child list for both users |
| 5 | Both users see same activities | Verify identical activity list |
| 6 | Data created by user A visible to user B | User A creates ingredient → switch to user B → verify visible |
| 7 | Pending invite prompt for new user | New user with no family but pending invites → verify InvitePendingPrompt |
| 8 | Accept invite → family loads | Tap Accept → verify invite repository called |

---

### 15. `multi_family_test.dart` (~6 tests)

| # | Test | Description |
|---|------|-------------|
| 1 | User belongs to two families | seedMultiFamily → verify both families accessible |
| 2 | Family switch: data changes | Switch selectedFamilyId → verify different allergen categories |
| 3 | Ingredients isolated per family | Family A has "egg", Family B doesn't → verify isolation |
| 4 | Activities isolated per family | Verify child activities don't leak across families |
| 5 | Auto-selection picks first family | On fresh load → verify selectedFamilyId == first family |
| 6 | Child selection persists within family | Select child, switch tabs, return → verify same child selected |

---

### 16. `sync_simulation_test.dart` (~16 tests)

Tests the UI's response to various sync states and transitions.

| # | Test | Description |
|---|------|-------------|
| 1 | Idle state: green dot + "Synced" | Verify UI elements |
| 2 | Syncing state: amber dot + "Syncing..." | Inject syncing status → verify |
| 3 | Error state: red dot + "Sync error" | Inject error → verify |
| 4 | Offline state: grey dot + "Offline" | Inject offline → verify |
| 5 | Online→Offline transition | Start online → goOffline() → verify grey dot |
| 6 | Offline→Online transition | Start offline → goOnline() → verify dot changes |
| 7 | Pending count display | Add 5 sync queue entries → verify "(5 pending)" on settings |
| 8 | Sync Now disabled while syncing | Set syncing status → verify onTap is null |
| 9 | Write creates sync queue entry | Create ingredient via UI → verify SyncQueue has entry |
| 10 | notifyWrite called after save | Save ingredient → verify engine.notifyWriteCount incremented |
| 11 | Atomic write: both DB record and queue entry | Insert activity → verify record in store AND entry in queue |
| 12 | Atomic write: transaction rollback on error | Simulate error in save → verify neither record nor queue entry exists |
| 13 | Sign out warning when offline with pending | Set offline + queue entries → tap Sign Out → verify dialog |
| 14 | Queue collapse: two writes to same doc → one entry | Update same ingredient twice → verify single queue entry |
| 15 | Queue preserves isNew on collapse | Create + update same doc → verify isNew still true |
| 16 | Initial sync loading shows spinner | `initialSyncComplete: false` → verify CircularProgressIndicator and "Syncing your data..." |

---

### 17. `backup_restore_test.dart` (~12 tests)

Tests BackupService directly through the harness (bypassing FilePicker/FileSaver).

| # | Test | Description |
|---|------|-------------|
| 1 | Export: produces valid JSON | Export family → parse JSON → verify version, familyId, stores |
| 2 | Export: contains all entity types | Verify activities, ingredients, recipes, targets, children, carers, families keys |
| 3 | Export: correct record count | Verify count matches seeded data |
| 4 | Restore: new records inserted | Export family A → clear DB → restore → verify all records present |
| 5 | Restore: merge semantics (newer wins) | Seed ingredient with old modifiedAt → restore with newer → verify overwritten |
| 6 | Restore: merge semantics (older skipped) | Seed ingredient with new modifiedAt → restore with older → verify kept |
| 7 | Restore: new + existing combined | Partially populated DB → restore → verify inserts + updates + skips counted correctly |
| 8 | Restore: duplicate ingredients deduped | Restore backup with duplicate ingredient names → verify only one survives via DedupHelper |
| 9 | Restore: duplicate recipes deduped | Same for recipes |
| 10 | Restore: sync queue entries created | Restore → verify sync queue has entries for all changed records |
| 11 | Restore: bad version throws | Restore JSON with version: 99 → verify FormatException |
| 12 | Restore: missing stores throws | Restore JSON without "stores" key → verify FormatException |

---

### 18. `csv_import_test.dart` (~10 tests)

Tests CsvImporter directly (not via FilePicker UI).

| # | Test | Description |
|---|------|-------------|
| 1 | Import valid CSV: activities created | Feed valid CSV string → verify activities in DB |
| 2 | Import with all activity types | CSV with 14 different types → verify all parsed and inserted |
| 3 | Dedup: skip existing activities | Import same CSV twice → verify second import skipped all |
| 4 | Dedup: fingerprint matching | Import CSV with same type+time+fields → verify skipped |
| 5 | Parse errors reported | CSV with invalid rows → verify parseErrors in result |
| 6 | Mixed valid + invalid rows | Verify valid rows imported, invalid rows counted |
| 7 | Empty CSV: no crash | Import empty string → verify imported: 0, skipped: 0 |
| 8 | Import enqueues sync | After import → verify sync queue entries for new activities |
| 9 | Re-import excludes soft-deleted | Soft-delete an activity → re-import same CSV → verify re-created |
| 10 | Import result counts correct | Verify imported, skipped, parseErrors counts |

---

### 19. `migration_dedup_test.dart` (~8 tests)

Tests IngredientDedupMigration and DedupHelper behavior visible through the data layer.

| # | Test | Description |
|---|------|-------------|
| 1 | No duplicates: migration returns empty | Run migration → verify empty changes |
| 2 | Duplicate ingredients: keeps oldest | Seed 2 "egg" ingredients with different createdAt → run → verify oldest kept |
| 3 | Duplicate ingredients: merges allergens | Seed "egg" with [egg] and "egg" with [egg, dairy] → run → verify keeper has [egg, dairy] |
| 4 | Duplicate recipes: keeps oldest | Same pattern for recipes |
| 5 | Duplicate recipes: merges ingredients | Recipe A has [egg], Recipe B has [egg, milk] → merge → verify [egg, milk] |
| 6 | Migration idempotent | Run twice → second returns empty (migration key set) |
| 7 | Migration returns correct change list | Verify (collection, documentId) tuples for soft-deleted docs |
| 8 | Cross-family isolation | Duplicate "egg" in family A and B → verify only same-family deduped |

---

### 20. `data_cascade_test.dart` (~12 tests)

Tests that data changes cascade correctly through the UI.

| # | Test | Description |
|---|------|-------------|
| 1 | Rename ingredient → recipes updated | Rename "egg" to "chicken egg" → verify recipe now shows "chicken egg" |
| 2 | Rename ingredient → targets updated | Rename → verify target's ingredientName updated |
| 3 | Rename ingredient → activities updated | Rename → verify activity's ingredientNames list updated |
| 4 | Rename ingredient → allergenNames recomputed | After rename, activity allergenNames still correct |
| 5 | Rename allergen category → family updated | Rename "egg" → "poultry" → verify family allergenCategories |
| 6 | Rename allergen category → ingredients updated | Verify ingredient allergens list changed |
| 7 | Rename allergen category → targets updated | Verify target allergenName changed |
| 8 | Remove allergen category → family updated | Remove "soy" → verify gone from allergenCategories |
| 9 | Remove allergen category → ingredients updated | Verify "soy" removed from ingredient allergens |
| 10 | Remove allergen category → targets deactivated | Verify targets with allergenName "soy" now isActive: false |
| 11 | Delete ingredient → soft deleted | Delete → verify isDeleted: true, still in DB |
| 12 | Delete ingredient → not shown in UI | After soft-delete → verify ingredient gone from list screen |

---

### 21. `error_resilience_test.dart` (~10 tests)

| # | Test | Description |
|---|------|-------------|
| 1 | No family selected: graceful degradation | Remove selectedFamilyId → verify screens show appropriate messages |
| 2 | No child selected: "Please add a child first" | On timeline/insights → verify message |
| 3 | Empty ingredient list: "No ingredients yet" | seedMinimal → verify empty state |
| 4 | Empty recipe list: "No recipes yet" | seedMinimal → verify empty state |
| 5 | Empty goals: "No goals set yet" | seedMinimal → verify empty state |
| 6 | Empty allergen categories: setup prompts | Verify "Manage Allergens" prompt on insights, "No allergen categories" on add ingredient |
| 7 | Initial sync error: snackbar shown | `initialSyncError: 'network error'` → verify snackbar |
| 8 | Form validation: empty name rejected | Leave ingredient name empty → tap Save → verify "Name is required" |
| 9 | Form validation: empty target value | Leave value empty → tap Save → verify "Please enter a valid target value" |
| 10 | Duplicate target prevention | Create same target twice → verify "A goal with these settings already exists" |

---

### 22. `user_journey_test.dart` (~10 tests)

Multi-step workflows simulating complete real user sessions.

| # | Test | Description |
|---|------|-------------|
| 1 | New user onboarding | Start empty → create family → add child → verify home screen with name |
| 2 | First allergen setup | Settings → Manage Allergens → add 3 categories → verify on ingredient add screen |
| 3 | Create ingredient → create recipe → log solids | Full pipeline: ingredient → recipe → activity with recipe → verify allergens tracked |
| 4 | Set goal → log activities → check progress | Create daily solids count target → log 2 solids → verify progress on insights |
| 5 | Add second child → switch → log activity | Family → add child → tap to switch → log activity → verify on new child |
| 6 | Edit activity: change volume | Home → tap activity tile → edit → save → verify updated on timeline |
| 7 | Delete activity from timeline | Timeline → delete → verify SnackBar → verify removed |
| 8 | Rename ingredient cascading | Create ingredient → use in recipe → use in activity → rename → verify cascade everywhere |
| 9 | Bulk allergen targets → check insights | Create 5 allergen targets → log solids with allergens → verify coverage on insights |
| 10 | Full backup/restore cycle | Seed data → export → clear DB → restore → verify all data present + UI renders correctly |

---

## Estimated Test Count

| File | Tests |
|------|-------|
| auth_flow_test.dart | 8 |
| navigation_test.dart | 16 |
| home_screen_test.dart | 14 |
| activity_crud_test.dart | 36 |
| activity_solids_deep_test.dart | 10 |
| timeline_test.dart | 12 |
| insights_test.dart | 14 |
| goals_test.dart | 14 |
| ingredients_crud_test.dart | 14 |
| recipes_crud_test.dart | 14 |
| allergen_management_test.dart | 10 |
| settings_test.dart | 10 |
| family_management_test.dart | 14 |
| multi_user_test.dart | 8 |
| multi_family_test.dart | 6 |
| sync_simulation_test.dart | 16 |
| backup_restore_test.dart | 12 |
| csv_import_test.dart | 10 |
| migration_dedup_test.dart | 8 |
| data_cascade_test.dart | 12 |
| error_resilience_test.dart | 10 |
| user_journey_test.dart | 10 |
| **Total** | **~278** |

---

## Implementation Order

### Phase 1: Infrastructure (must work before anything else)

1. **Refactor `currentUserProvider`** → return `AppUser?` instead of `User?`
2. **Extract `SyncEngineInterface`** → both real engine and fake implement it
3. **`test_harness.dart`** — All controllable fakes, seed data, build helpers

### Phase 2: Smoke + Navigation (validates the harness works)

4. **`auth_flow_test.dart`** — App boots, router redirects work
5. **`navigation_test.dart`** — All routes render without crashing

### Phase 3: Core Screen Tests

6. **`home_screen_test.dart`** — Main landing page + setup flow
7. **`settings_test.dart`** — Settings tiles + navigation
8. **`family_management_test.dart`** — Multi-carer, children

### Phase 4: Data CRUD (exercises real Sembast)

9. **`ingredients_crud_test.dart`**
10. **`recipes_crud_test.dart`**
11. **`allergen_management_test.dart`**
12. **`goals_test.dart`**

### Phase 5: Activity Forms (most complex UI)

13. **`activity_crud_test.dart`**
14. **`activity_solids_deep_test.dart`**
15. **`timeline_test.dart`**
16. **`insights_test.dart`**

### Phase 6: Sync + Data Integrity

17. **`sync_simulation_test.dart`**
18. **`data_cascade_test.dart`**
19. **`backup_restore_test.dart`**
20. **`csv_import_test.dart`**
21. **`migration_dedup_test.dart`**

### Phase 7: Multi-User + Journeys

22. **`multi_user_test.dart`**
23. **`multi_family_test.dart`**
24. **`error_resilience_test.dart`**
25. **`user_journey_test.dart`**

---

## Required Refactors (Pre-Implementation)

### Must-Have (blocking)

1. **`currentUserProvider` → `AppUser?`** — Decouple from `firebase_auth.User`. ~10 files to update (screens that read `.uid`, `.email`, `.displayName`). The `authStateProvider` still uses `User?` internally — only the downstream consumer type changes.

2. **`SyncEngineInterface`** — Extract abstract interface. `SyncEngine` implements it. Syncing repositories and providers reference the interface. `ControllableSyncEngine` implements it without requiring `FirebaseFirestore`.

3. **`ConnectivityMonitor`** — Verify constructor accepts dependency injection (it does per current code). Extract interface if not already abstractable.

### Nice-to-Have (improves test quality)

4. **`BackupService` testable constructor** — Currently takes `Database` only, which is fine for in-memory testing. No change needed.

5. **`CsvImporter` testable without platform plugins** — Already takes `ActivityRepository`, which works with real local repo in tests. No change needed.

---

## CI Integration

```yaml
- name: Run all tests
  run: flutter test --reporter=github

# E2E tests are in test/e2e/ and run as part of the standard flutter test suite.
# No separate job, no Xvfb, no emulator needed.
```

**Expected run time**: ~60-120 seconds for all ~278 tests.

---

## Success Criteria

1. All ~278 tests pass on CI via `flutter test`
2. **Every route** (all 19) visited by at least one test
3. **Every button** on every screen exercised (FABs, ActionChips, IconButtons, ListTiles, SegmentedButtons, DropdownButtons, etc.)
4. **Every form field** on every activity type verified (render + fill + save)
5. **Full CRUD** for ingredients, recipes, allergens, targets, children, activities
6. **Sync states** (idle/syncing/error/offline) tested with controllable fakes
7. **Multi-user** role-based UI differences verified
8. **Multi-family** data isolation verified
9. **Backup/restore** round-trip tested with merge semantics and dedup
10. **CSV import** with dedup and error handling tested
11. **Migration/dedup** behavior tested
12. **Data cascade** (ingredient rename, allergen rename/delete) verified through all affected stores
13. **Error states** and **empty states** for every screen verified
14. **User journeys** covering complete multi-step workflows
15. No flaky tests — deterministic seed data with fixed dates
16. Zero analysis warnings (`flutter analyze --fatal-warnings`)
