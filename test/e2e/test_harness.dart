import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import 'package:datababe/app.dart';
import 'package:datababe/local/database_provider.dart';
import 'package:datababe/local/store_refs.dart';
import 'package:datababe/models/activity_model.dart';
import 'package:datababe/models/app_user.dart';
import 'package:datababe/models/carer_model.dart';
import 'package:datababe/models/child_model.dart';
import 'package:datababe/models/family_model.dart';
import 'package:datababe/models/ingredient_model.dart';
import 'package:datababe/models/invite_model.dart';
import 'package:datababe/models/recipe_model.dart';
import 'package:datababe/models/target_model.dart';
import 'package:datababe/providers/activity_provider.dart';
import 'package:datababe/providers/auth_provider.dart';
import 'package:datababe/providers/child_provider.dart';
import 'package:datababe/providers/family_provider.dart';
import 'package:datababe/providers/ingredient_provider.dart';
import 'package:datababe/providers/initial_sync_provider.dart';
import 'package:datababe/providers/invite_provider.dart';
import 'package:datababe/providers/recipe_provider.dart';
import 'package:datababe/providers/repository_provider.dart';
import 'package:datababe/providers/settings_provider.dart';
import 'package:datababe/providers/sync_provider.dart';
import 'package:datababe/providers/target_provider.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:datababe/repositories/auth_repository.dart';
import 'package:datababe/repositories/invite_repository.dart';
import 'package:datababe/sync/connectivity_monitor.dart';
import 'package:datababe/sync/sync_engine_interface.dart';

// ---------------------------------------------------------------------------
// Test harness — shared infrastructure for all E2E tests
// ---------------------------------------------------------------------------

var _dbCounter = 0;

class TestHarness {
  late Database db;

  late StreamController<SyncStatus> _syncStatusController;
  late StreamController<bool> _onlineController;
  late StreamController<List<InviteModel>> _pendingInvitesController;
  late StreamController<List<InviteModel>> _familyInvitesController;

  late FakeAuthRepository authRepository;
  late ControllableSyncEngine syncEngine;
  late ControllableConnectivityMonitor connectivityMonitor;
  late ControllableInviteRepository inviteRepository;

  // --- Seed data (populated by seed helpers, used by buildApp overrides) ---

  List<FamilyModel> families = [];
  List<ChildModel> children = [];
  List<CarerModel> carers = [];
  List<ActivityModel> activities = [];
  List<TargetModel> targets = [];
  List<IngredientModel> ingredients = [];
  List<RecipeModel> recipes = [];

  // --- State injection ---

  void setSyncStatus(SyncStatus status) => _syncStatusController.add(status);
  void setOnline(bool online) => _onlineController.add(online);
  void setPendingInvites(List<InviteModel> invites) =>
      _pendingInvitesController.add(invites);
  void setFamilyInvites(List<InviteModel> invites) =>
      _familyInvitesController.add(invites);

  // --- Lifecycle ---

  Future<void> setUp() async {
    _dbCounter++;
    db = await databaseFactoryMemory.openDatabase('e2e_test_$_dbCounter');
    authRepository = FakeAuthRepository();
    syncEngine = ControllableSyncEngine(db);
    connectivityMonitor = ControllableConnectivityMonitor(true);
    inviteRepository = ControllableInviteRepository();
    _syncStatusController = StreamController<SyncStatus>.broadcast();
    _onlineController = StreamController<bool>.broadcast();
    _pendingInvitesController =
        StreamController<List<InviteModel>>.broadcast();
    _familyInvitesController =
        StreamController<List<InviteModel>>.broadcast();
    // Reset seed data
    families = [];
    children = [];
    carers = [];
    activities = [];
    targets = [];
    ingredients = [];
    recipes = [];
  }

  Future<void> tearDown() async {
    await db.close();
    await databaseFactoryMemory.deleteDatabase('e2e_test_$_dbCounter');
    _syncStatusController.close();
    _onlineController.close();
    _pendingInvitesController.close();
    _familyInvitesController.close();
  }

  // --- Seed helpers (write to DB + populate data fields) ---
  //
  // IMPORTANT: Must be called via tester.runAsync() to avoid FakeAsync
  // interference with Sembast timers. Example:
  //   await tester.runAsync(() => harness.seedMinimal());

  /// Minimal seed: family + child + carer (no activities/ingredients/recipes/targets).
  Future<void> seedMinimal() async {
    await TestData.seedMinimal(db);
    families = [TestData.familyA];
    children = [TestData.childA];
    carers = [TestData.carerParent];
  }

  /// Full seed: family + child + carer + ingredients + recipes + targets + activities.
  Future<void> seedFull() async {
    await TestData.seedFull(db);
    families = [TestData.familyA];
    children = [TestData.childA];
    carers = [TestData.carerParent];
    ingredients = TestData.ingredients();
    recipes = TestData.recipes();
    targets = TestData.targets();
    activities = TestData.todayActivities();
  }

  /// Multi-carer seed: family with two carers.
  Future<void> seedMultiCarer() async {
    await TestData.seedMultiCarer(db);
    families = [TestData.familyA];
    children = [TestData.childA];
    carers = [TestData.carerParent, TestData.carerOther];
  }

  /// Multi-family seed: two families, user is member of both.
  Future<void> seedMultiFamily() async {
    await TestData.seedMultiFamily(db);
    families = [TestData.familyA, TestData.familyB];
    children = [TestData.childA]; // Only family A children auto-selected
    carers = [TestData.carerParent];
    ingredients = TestData.ingredients();
    recipes = TestData.recipes();
    targets = TestData.targets();
    activities = TestData.todayActivities();
  }

  // --- Build full app with provider overrides ---

  Widget buildApp({
    bool authenticated = true,
    bool initialSyncComplete = true,
    String? initialSyncError,
    SyncStatus initialSyncStatus = SyncStatus.idle,
    bool initialOnline = true,
    String userId = 'test-uid-123',
    String userEmail = 'test@example.com',
    String userDisplayName = 'Test User',
  }) {
    connectivityMonitor = ControllableConnectivityMonitor(initialOnline);

    return ProviderScope(
      overrides: [
        // Auth — override all to avoid Firebase dependency
        authRepositoryProvider.overrideWithValue(authRepository),
        authStateProvider.overrideWith((_) => const Stream.empty()),
        currentUserProvider.overrideWithValue(
          authenticated
              ? AppUser(
                  uid: userId,
                  email: userEmail,
                  displayName: userDisplayName,
                  familyIds: const [],
                  createdAt: TestData.now,
                )
              : null,
        ),

        // Database
        localDatabaseProvider.overrideWithValue(db),

        // Sync — controllable
        syncEngineProvider.overrideWithValue(syncEngine),
        syncStatusProvider.overrideWith((_) =>
            _prependStream(initialSyncStatus, _syncStatusController.stream)),
        isOnlineProvider.overrideWith(
            (_) => _prependStream(initialOnline, _onlineController.stream)),
        lastSyncTimeProvider.overrideWith((_) async => DateTime.now()),
        pendingSyncCountProvider.overrideWith((_) async => 0),
        connectivityMonitorProvider.overrideWithValue(connectivityMonitor),

        // Initial sync
        initialSyncProvider.overrideWith((_) => initialSyncComplete
            ? Future.value(
                InitialSyncResult(complete: true, error: initialSyncError))
            : Completer<InitialSyncResult>().future),

        // Invites
        inviteRepositoryProvider.overrideWithValue(inviteRepository),
        pendingInvitesProvider.overrideWith((_) =>
            _prependStream(<InviteModel>[], _pendingInvitesController.stream)),
        familyInvitesProvider.overrideWith((_) =>
            _prependStream(<InviteModel>[], _familyInvitesController.stream)),

        // --- Data stream overrides (bypass Sembast onSnapshots) ---
        // Sembast streams cause infinite microtask loops in FakeAsync.
        // Override all Sembast-backed StreamProviders with direct data.
        startOfDayHourProvider.overrideWith((_) => Stream.value(0)),
        userFamiliesProvider.overrideWith((_) => Stream.value(families)),
        allChildrenProvider.overrideWith((_) => Stream.value(children)),
        activitiesProvider.overrideWith((_) => Stream.value(activities)),
        dailyActivitiesProvider.overrideWith((_) => Stream.value(activities)),
        timelineActivitiesProvider.overrideWith((_) => Stream.value(activities)),
        targetsProvider.overrideWith((_) => Stream.value(targets)),
        familyCarersProvider.overrideWith((_) => Stream.value(carers)),
        ingredientsProvider.overrideWith((_) => Stream.value(ingredients)),
        recipesProvider.overrideWith((_) => Stream.value(recipes)),
      ],
      child: const DataBabeApp(),
    );
  }
}

// ---------------------------------------------------------------------------
// Controllable fakes
// ---------------------------------------------------------------------------

/// Sync engine that records calls and allows state injection.
class ControllableSyncEngine implements SyncEngineInterface {
  int notifyWriteCount = 0;
  int syncNowCount = 0;
  bool clearLocalDataCalled = false;
  SyncResult nextSyncResult = SyncResult.empty;

  ControllableSyncEngine(Database db);

  @override
  void start() {}

  @override
  void dispose() {}

  @override
  void notifyWrite() => notifyWriteCount++;

  @override
  Future<SyncResult> syncNow() async {
    syncNowCount++;
    return nextSyncResult;
  }

  @override
  Future<int> get pendingCount async => 0;

  @override
  Stream<SyncStatus> get statusStream => Stream.value(SyncStatus.idle);

  @override
  SyncStatus get currentStatus => SyncStatus.idle;

  @override
  Future<DateTime?> get lastSyncTime async => DateTime.now();

  @override
  Future<void> clearLocalData() async {
    clearLocalDataCalled = true;
  }

  @override
  Future<Map<String, dynamic>> getDiagnostics(String familyId) async => {};

  @override
  Future<void> initialSync(List<String> familyIds) async {}

  @override
  Future<void> forceFullResync(List<String> familyIds) async {}

  @override
  Future<List<String>> fetchFamilyIds() async => [];
}

/// Connectivity monitor with controllable state.
class ControllableConnectivityMonitor implements ConnectivityMonitor {
  bool _isOnline;
  final _onlineController = StreamController<bool>.broadcast();
  final _restoredController = StreamController<void>.broadcast();

  ControllableConnectivityMonitor(this._isOnline);

  void goOnline() {
    _isOnline = true;
    _onlineController.add(true);
    _restoredController.add(null);
  }

  void goOffline() {
    _isOnline = false;
    _onlineController.add(false);
  }

  @override
  bool get isOnline => _isOnline;

  @override
  Stream<bool> get onlineStream => _onlineController.stream;

  @override
  Stream<void> get onConnectivityRestored => _restoredController.stream;

  @override
  void dispose() {
    _onlineController.close();
    _restoredController.close();
  }
}

/// Auth repository that doesn't need Firebase.
class FakeAuthRepository implements AuthRepository {
  bool signOutCalled = false;

  @override
  Stream<User?> watchAuthState() => const Stream.empty();

  @override
  User? get currentUser => null;

  @override
  Future<User?> signInWithGoogle() async => null;

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }
}

/// Invite repository with controllable responses.
class ControllableInviteRepository implements InviteRepository {
  final createdInvites = <InviteModel>[];
  final acceptedInviteIds = <String>[];
  final declinedInviteIds = <String>[];
  final cancelledInviteIds = <String>[];
  Exception? nextError;

  @override
  Future<void> createInvite(InviteModel invite) async {
    if (nextError != null) throw nextError!;
    createdInvites.add(invite);
  }

  @override
  Future<void> acceptInvite({
    required InviteModel invite,
    required String uid,
    required String displayName,
  }) async {
    if (nextError != null) throw nextError!;
    acceptedInviteIds.add(invite.id);
  }

  @override
  Future<void> declineInvite(String inviteId) async {
    declinedInviteIds.add(inviteId);
  }

  @override
  Future<void> cancelInvite(String inviteId) async {
    cancelledInviteIds.add(inviteId);
  }

  @override
  Stream<List<InviteModel>> watchPendingInvites(String email) =>
      Stream.value([]);

  @override
  Stream<List<InviteModel>> watchFamilyInvites(String familyId) =>
      Stream.value([]);
}

// ---------------------------------------------------------------------------
// Seed data
// ---------------------------------------------------------------------------

class TestData {
  static final now = DateTime(2026, 3, 10, 10, 30);
  static final yesterday = now.subtract(const Duration(days: 1));
  static final lastWeek = now.subtract(const Duration(days: 7));

  // --- Family A (primary user) ---
  static final familyA = FamilyModel(
    id: 'f1',
    name: 'Test Family',
    createdBy: 'test-uid-123',
    memberUids: ['test-uid-123', 'user-b-uid'],
    createdAt: lastWeek,
    modifiedAt: lastWeek,
    allergenCategories: ['egg', 'dairy', 'peanut', 'wheat', 'soy'],
  );

  static final childA = ChildModel(
    id: 'c1',
    name: 'Baby',
    dateOfBirth: DateTime(2025, 9, 1),
    createdAt: lastWeek,
    modifiedAt: lastWeek,
  );

  static final childB = ChildModel(
    id: 'c2',
    name: 'Toddler',
    dateOfBirth: DateTime(2023, 6, 15),
    createdAt: lastWeek,
    modifiedAt: lastWeek,
  );

  static final carerParent = CarerModel(
    id: 'cr1',
    uid: 'test-uid-123',
    displayName: 'Test User',
    role: 'parent',
    createdAt: lastWeek,
    modifiedAt: lastWeek,
  );

  static final carerOther = CarerModel(
    id: 'cr2',
    uid: 'user-b-uid',
    displayName: 'Partner',
    role: 'carer',
    createdAt: lastWeek,
    modifiedAt: lastWeek,
  );

  // --- Family B (second family for multi-family tests) ---
  static final familyB = FamilyModel(
    id: 'f2',
    name: 'Extended Family',
    createdBy: 'user-b-uid',
    memberUids: ['test-uid-123', 'user-b-uid'],
    createdAt: lastWeek,
    modifiedAt: lastWeek,
    allergenCategories: ['sesame'],
  );

  // --- Ingredients ---
  static List<IngredientModel> ingredients() => [
        IngredientModel(
          id: 'i1',
          name: 'egg',
          allergens: ['egg'],
          createdBy: 'test-uid-123',
          createdAt: lastWeek,
          modifiedAt: lastWeek,
        ),
        IngredientModel(
          id: 'i2',
          name: 'milk',
          allergens: ['dairy'],
          createdBy: 'test-uid-123',
          createdAt: lastWeek,
          modifiedAt: lastWeek,
        ),
        IngredientModel(
          id: 'i3',
          name: 'bread',
          allergens: ['wheat'],
          createdBy: 'test-uid-123',
          createdAt: lastWeek,
          modifiedAt: lastWeek,
        ),
        IngredientModel(
          id: 'i4',
          name: 'butter',
          allergens: ['dairy'],
          createdBy: 'test-uid-123',
          createdAt: lastWeek,
          modifiedAt: lastWeek,
        ),
        IngredientModel(
          id: 'i5',
          name: 'banana',
          allergens: [],
          createdBy: 'test-uid-123',
          createdAt: lastWeek,
          modifiedAt: lastWeek,
        ),
      ];

  // --- Recipes ---
  static List<RecipeModel> recipes() => [
        RecipeModel(
          id: 'r1',
          name: 'scrambled eggs',
          ingredients: ['egg', 'milk', 'butter'],
          createdBy: 'test-uid-123',
          createdAt: lastWeek,
          modifiedAt: lastWeek,
        ),
        RecipeModel(
          id: 'r2',
          name: 'toast with butter',
          ingredients: ['bread', 'butter'],
          createdBy: 'test-uid-123',
          createdAt: lastWeek,
          modifiedAt: lastWeek,
        ),
        RecipeModel(
          id: 'r3',
          name: 'banana mash',
          ingredients: ['banana'],
          createdBy: 'test-uid-123',
          createdAt: lastWeek,
          modifiedAt: lastWeek,
        ),
      ];

  // --- Targets ---
  static List<TargetModel> targets() => [
        TargetModel(
          id: 't1',
          childId: 'c1',
          activityType: 'solids',
          metric: 'count',
          period: 'daily',
          targetValue: 3,
          createdBy: 'test-uid-123',
          createdAt: lastWeek,
          modifiedAt: lastWeek,
        ),
        TargetModel(
          id: 't2',
          childId: 'c1',
          activityType: 'solids',
          metric: 'allergenExposures',
          period: 'weekly',
          targetValue: 2,
          allergenName: 'egg',
          createdBy: 'test-uid-123',
          createdAt: lastWeek,
          modifiedAt: lastWeek,
        ),
        TargetModel(
          id: 't3',
          childId: 'c1',
          activityType: 'solids',
          metric: 'allergenExposures',
          period: 'weekly',
          targetValue: 2,
          allergenName: 'dairy',
          createdBy: 'test-uid-123',
          createdAt: lastWeek,
          modifiedAt: lastWeek,
        ),
        TargetModel(
          id: 't4',
          childId: 'c1',
          activityType: 'feedBottle',
          metric: 'totalVolumeMl',
          period: 'daily',
          targetValue: 600,
          createdBy: 'test-uid-123',
          createdAt: lastWeek,
          modifiedAt: lastWeek,
        ),
        TargetModel(
          id: 't5',
          childId: 'c1',
          activityType: 'tummyTime',
          metric: 'totalDurationMinutes',
          period: 'daily',
          targetValue: 30,
          createdBy: 'test-uid-123',
          createdAt: lastWeek,
          modifiedAt: lastWeek,
        ),
      ];

  // --- Today's activities (one per type) ---
  static List<ActivityModel> todayActivities() => [
        ActivityModel(
          id: 'a1',
          childId: 'c1',
          type: 'feedBottle',
          startTime: now.subtract(const Duration(hours: 2)),
          feedType: 'formula',
          volumeMl: 120.0,
          createdAt: now.subtract(const Duration(hours: 2)),
          modifiedAt: now.subtract(const Duration(hours: 2)),
        ),
        ActivityModel(
          id: 'a2',
          childId: 'c1',
          type: 'feedBreast',
          startTime: now.subtract(const Duration(hours: 4)),
          rightBreastMinutes: 10,
          leftBreastMinutes: 8,
          createdAt: now.subtract(const Duration(hours: 4)),
          modifiedAt: now.subtract(const Duration(hours: 4)),
        ),
        ActivityModel(
          id: 'a3',
          childId: 'c1',
          type: 'diaper',
          startTime: now.subtract(const Duration(hours: 3)),
          contents: 'both',
          contentSize: 'medium',
          pooColour: 'yellow',
          pooConsistency: 'soft',
          createdAt: now.subtract(const Duration(hours: 3)),
          modifiedAt: now.subtract(const Duration(hours: 3)),
        ),
        ActivityModel(
          id: 'a4',
          childId: 'c1',
          type: 'solids',
          startTime: now.subtract(const Duration(hours: 1)),
          foodDescription: 'scrambled eggs',
          reaction: 'loved',
          recipeId: 'r1',
          ingredientNames: ['egg', 'milk'],
          allergenNames: ['egg', 'dairy'],
          createdAt: now.subtract(const Duration(hours: 1)),
          modifiedAt: now.subtract(const Duration(hours: 1)),
        ),
        ActivityModel(
          id: 'a5',
          childId: 'c1',
          type: 'meds',
          startTime: now.subtract(const Duration(hours: 5)),
          medicationName: 'Vitamin D',
          dose: '5',
          doseUnit: 'drops',
          createdAt: now.subtract(const Duration(hours: 5)),
          modifiedAt: now.subtract(const Duration(hours: 5)),
        ),
        ActivityModel(
          id: 'a6',
          childId: 'c1',
          type: 'growth',
          startTime: now,
          weightKg: 8.5,
          lengthCm: 72.0,
          headCircumferenceCm: 45.0,
          createdAt: now,
          modifiedAt: now,
        ),
        ActivityModel(
          id: 'a7',
          childId: 'c1',
          type: 'tummyTime',
          startTime: now.subtract(const Duration(hours: 6)),
          durationMinutes: 15,
          createdAt: now.subtract(const Duration(hours: 6)),
          modifiedAt: now.subtract(const Duration(hours: 6)),
        ),
        ActivityModel(
          id: 'a8',
          childId: 'c1',
          type: 'pump',
          startTime: now.subtract(const Duration(hours: 7)),
          volumeMl: 60.0,
          durationMinutes: 20,
          createdAt: now.subtract(const Duration(hours: 7)),
          modifiedAt: now.subtract(const Duration(hours: 7)),
        ),
        ActivityModel(
          id: 'a9',
          childId: 'c1',
          type: 'temperature',
          startTime: now,
          tempCelsius: 36.8,
          createdAt: now,
          modifiedAt: now,
        ),
        ActivityModel(
          id: 'a10',
          childId: 'c1',
          type: 'bath',
          startTime: yesterday,
          durationMinutes: 10,
          createdAt: yesterday,
          modifiedAt: yesterday,
        ),
        ActivityModel(
          id: 'a11',
          childId: 'c1',
          type: 'indoorPlay',
          startTime: yesterday,
          durationMinutes: 30,
          createdAt: yesterday,
          modifiedAt: yesterday,
        ),
        ActivityModel(
          id: 'a12',
          childId: 'c1',
          type: 'outdoorPlay',
          startTime: yesterday,
          durationMinutes: 45,
          createdAt: yesterday,
          modifiedAt: yesterday,
        ),
        ActivityModel(
          id: 'a13',
          childId: 'c1',
          type: 'skinToSkin',
          startTime: yesterday,
          durationMinutes: 20,
          createdAt: yesterday,
          modifiedAt: yesterday,
        ),
        ActivityModel(
          id: 'a14',
          childId: 'c1',
          type: 'potty',
          startTime: now,
          contents: 'pee',
          contentSize: 'small',
          createdAt: now,
          modifiedAt: now,
        ),
      ];

  // --- Seed methods (write to DB only — used by instance methods above) ---

  /// Full seed: family + children + carers + ingredients + recipes + targets + activities.
  static Future<void> seedFull(Database db) async {
    await db.transaction((txn) async {
      // Family
      await StoreRefs.families
          .record(familyA.id)
          .put(txn, familyA.toMap()..['familyId'] = familyA.id);

      // Children
      for (final child in [childA]) {
        await StoreRefs.children.record(child.id).put(txn, {
          'name': child.name,
          'dateOfBirth': child.dateOfBirth.toIso8601String(),
          'notes': child.notes,
          'createdAt': child.createdAt.toIso8601String(),
          'modifiedAt': child.modifiedAt.toIso8601String(),
          'isDeleted': child.isDeleted,
          'familyId': familyA.id,
        });
      }

      // Carers
      for (final carer in [carerParent]) {
        await StoreRefs.carers.record(carer.id).put(txn, {
          'uid': carer.uid,
          'displayName': carer.displayName,
          'role': carer.role,
          'createdAt': carer.createdAt.toIso8601String(),
          'modifiedAt': carer.modifiedAt.toIso8601String(),
          'isDeleted': carer.isDeleted,
          'familyId': familyA.id,
        });
      }

      // Ingredients
      for (final ing in ingredients()) {
        await StoreRefs.ingredients.record(ing.id).put(txn, {
          'name': ing.name,
          'allergens': ing.allergens,
          'isDeleted': ing.isDeleted,
          'createdBy': ing.createdBy,
          'createdAt': ing.createdAt.toIso8601String(),
          'modifiedAt': ing.modifiedAt.toIso8601String(),
          'familyId': familyA.id,
        });
      }

      // Recipes
      for (final recipe in recipes()) {
        await StoreRefs.recipes.record(recipe.id).put(txn, {
          'name': recipe.name,
          'ingredients': recipe.ingredients,
          'isDeleted': recipe.isDeleted,
          'createdBy': recipe.createdBy,
          'createdAt': recipe.createdAt.toIso8601String(),
          'modifiedAt': recipe.modifiedAt.toIso8601String(),
          'familyId': familyA.id,
        });
      }

      // Targets
      for (final target in targets()) {
        await StoreRefs.targets.record(target.id).put(txn, {
          'childId': target.childId,
          'activityType': target.activityType,
          'metric': target.metric,
          'period': target.period,
          'targetValue': target.targetValue,
          'isActive': target.isActive,
          'createdBy': target.createdBy,
          'createdAt': target.createdAt.toIso8601String(),
          'modifiedAt': target.modifiedAt.toIso8601String(),
          'isDeleted': target.isDeleted,
          'familyId': familyA.id,
          if (target.ingredientName != null)
            'ingredientName': target.ingredientName,
          if (target.allergenName != null) 'allergenName': target.allergenName,
        });
      }

      // Activities
      for (final activity in todayActivities()) {
        await StoreRefs.activities.record(activity.id).put(txn, {
          'childId': activity.childId,
          'type': activity.type,
          'startTime': activity.startTime.toIso8601String(),
          if (activity.endTime != null)
            'endTime': activity.endTime!.toIso8601String(),
          if (activity.durationMinutes != null)
            'durationMinutes': activity.durationMinutes,
          'createdAt': activity.createdAt.toIso8601String(),
          'modifiedAt': activity.modifiedAt.toIso8601String(),
          'isDeleted': activity.isDeleted,
          if (activity.notes != null) 'notes': activity.notes,
          if (activity.feedType != null) 'feedType': activity.feedType,
          if (activity.volumeMl != null) 'volumeMl': activity.volumeMl,
          if (activity.rightBreastMinutes != null)
            'rightBreastMinutes': activity.rightBreastMinutes,
          if (activity.leftBreastMinutes != null)
            'leftBreastMinutes': activity.leftBreastMinutes,
          if (activity.contents != null) 'contents': activity.contents,
          if (activity.contentSize != null) 'contentSize': activity.contentSize,
          if (activity.pooColour != null) 'pooColour': activity.pooColour,
          if (activity.pooConsistency != null)
            'pooConsistency': activity.pooConsistency,
          if (activity.peeSize != null) 'peeSize': activity.peeSize,
          if (activity.medicationName != null)
            'medicationName': activity.medicationName,
          if (activity.dose != null) 'dose': activity.dose,
          if (activity.doseUnit != null) 'doseUnit': activity.doseUnit,
          if (activity.foodDescription != null)
            'foodDescription': activity.foodDescription,
          if (activity.reaction != null) 'reaction': activity.reaction,
          if (activity.recipeId != null) 'recipeId': activity.recipeId,
          if (activity.ingredientNames != null)
            'ingredientNames': activity.ingredientNames,
          if (activity.allergenNames != null)
            'allergenNames': activity.allergenNames,
          if (activity.weightKg != null) 'weightKg': activity.weightKg,
          if (activity.lengthCm != null) 'lengthCm': activity.lengthCm,
          if (activity.headCircumferenceCm != null)
            'headCircumferenceCm': activity.headCircumferenceCm,
          if (activity.tempCelsius != null) 'tempCelsius': activity.tempCelsius,
          'familyId': familyA.id,
        });
      }
    });
  }

  /// Minimal seed: just family + child + carer.
  static Future<void> seedMinimal(Database db) async {
    await db.transaction((txn) async {
      await StoreRefs.families
          .record(familyA.id)
          .put(txn, familyA.toMap()..['familyId'] = familyA.id);

      await StoreRefs.children.record(childA.id).put(txn, {
        'name': childA.name,
        'dateOfBirth': childA.dateOfBirth.toIso8601String(),
        'notes': childA.notes,
        'createdAt': childA.createdAt.toIso8601String(),
        'modifiedAt': childA.modifiedAt.toIso8601String(),
        'isDeleted': childA.isDeleted,
        'familyId': familyA.id,
      });

      await StoreRefs.carers.record(carerParent.id).put(txn, {
        'uid': carerParent.uid,
        'displayName': carerParent.displayName,
        'role': carerParent.role,
        'createdAt': carerParent.createdAt.toIso8601String(),
        'modifiedAt': carerParent.modifiedAt.toIso8601String(),
        'isDeleted': carerParent.isDeleted,
        'familyId': familyA.id,
      });
    });
  }

  /// Multi-carer seed: family with two carers (parent + carer roles).
  static Future<void> seedMultiCarer(Database db) async {
    await seedMinimal(db);
    await StoreRefs.carers.record(carerOther.id).put(db, {
      'uid': carerOther.uid,
      'displayName': carerOther.displayName,
      'role': carerOther.role,
      'createdAt': carerOther.createdAt.toIso8601String(),
      'modifiedAt': carerOther.modifiedAt.toIso8601String(),
      'isDeleted': carerOther.isDeleted,
      'familyId': familyA.id,
    });
  }

  /// Multi-family seed: two families, user is member of both.
  static Future<void> seedMultiFamily(Database db) async {
    await seedFull(db);
    await db.transaction((txn) async {
      await StoreRefs.families
          .record(familyB.id)
          .put(txn, familyB.toMap()..['familyId'] = familyB.id);

      await StoreRefs.children.record('c3').put(txn, {
        'name': 'Other Child',
        'dateOfBirth': DateTime(2024, 1, 1).toIso8601String(),
        'notes': '',
        'createdAt': lastWeek.toIso8601String(),
        'modifiedAt': lastWeek.toIso8601String(),
        'isDeleted': false,
        'familyId': familyB.id,
      });

      await StoreRefs.carers.record('cr3').put(txn, {
        'uid': 'test-uid-123',
        'displayName': 'Test User',
        'role': 'carer',
        'createdAt': lastWeek.toIso8601String(),
        'modifiedAt': lastWeek.toIso8601String(),
        'isDeleted': false,
        'familyId': familyB.id,
      });
    });
  }
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Pump app and wait for async providers to emit initial values.
///
/// Uses bounded pumping instead of [pumpAndSettle] to avoid hanging on
/// infinite animations (e.g. [CircularProgressIndicator] in loading states).
///
/// With direct stream provider overrides (bypassing Sembast), only a few
/// pump cycles are needed for Future.microtask auto-selection to resolve.
Future<void> pumpApp(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  // FutureProvider (initialSync) + StreamProvider emissions need microtask flushes.
  // Auto-selection via Future.microtask needs additional pump cycles.
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

/// Creates a stream that emits [initial] then all events from [source].
Stream<T> _prependStream<T>(T initial, Stream<T> source) async* {
  yield initial;
  yield* source;
}
