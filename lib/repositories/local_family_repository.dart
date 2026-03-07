import 'package:sembast/sembast.dart';

import '../local/store_refs.dart';
import '../models/family_model.dart';
import '../models/child_model.dart';
import '../models/carer_model.dart';
import 'cascaded_change.dart';
import 'family_repository.dart';

class LocalFamilyRepository implements FamilyRepository {
  final Database _db;

  LocalFamilyRepository(this._db);

  StoreRef<String, Map<String, dynamic>> get _familyStore => StoreRefs.families;
  StoreRef<String, Map<String, dynamic>> get _childStore => StoreRefs.children;
  StoreRef<String, Map<String, dynamic>> get _carerStore => StoreRefs.carers;

  @override
  Stream<List<FamilyModel>> watchFamilies(String uid) {
    // Sembast doesn't have arrayContains; use custom filter.
    final finder = Finder(
      filter: Filter.custom((record) {
        final memberUids = record['memberUids'] as List<dynamic>?;
        return memberUids != null && memberUids.contains(uid);
      }),
    );
    return _familyStore.query(finder: finder).onSnapshots(_db).map(
          (snapshots) => snapshots
              .map((s) => FamilyModel.fromMap(s.key, s.value))
              .toList(),
        );
  }

  @override
  Stream<List<ChildModel>> watchChildren(String familyId) {
    final finder = Finder(
      filter: Filter.equals('familyId', familyId),
      sortOrders: [SortOrder('createdAt')],
    );
    return _childStore.query(finder: finder).onSnapshots(_db).map(
          (snapshots) => snapshots
              .map((s) => ChildModel.fromMap(s.key, s.value))
              .toList(),
        );
  }

  @override
  Future<FamilyModel> createFamily(FamilyModel family) async {
    final map = family.toMap();
    await _familyStore.record(family.id).put(_db, map);
    return family;
  }

  @override
  Future<ChildModel> createChild(String familyId, ChildModel child) async {
    final map = child.toMap();
    map['familyId'] = familyId;
    await _childStore.record(child.id).put(_db, map);
    return child;
  }

  @override
  Future<CarerModel> createCarer(String familyId, CarerModel carer) async {
    final map = carer.toMap();
    map['familyId'] = familyId;
    await _carerStore.record(carer.id).put(_db, map);
    return carer;
  }

  @override
  Future<void> createFamilyWithChild({
    required FamilyModel family,
    required ChildModel child,
    required CarerModel carer,
  }) async {
    await _db.transaction((txn) async {
      await _familyStore.record(family.id).put(txn, family.toMap());

      final childMap = child.toMap();
      childMap['familyId'] = family.id;
      await _childStore.record(child.id).put(txn, childMap);

      final carerMap = carer.toMap();
      carerMap['familyId'] = family.id;
      await _carerStore.record(carer.id).put(txn, carerMap);
    });
  }

  @override
  Stream<List<CarerModel>> watchCarers(String familyId) {
    final finder = Finder(
      filter: Filter.equals('familyId', familyId),
      sortOrders: [SortOrder('createdAt')],
    );
    return _carerStore.query(finder: finder).onSnapshots(_db).map(
          (snapshots) => snapshots
              .map((s) => CarerModel.fromMap(s.key, s.value))
              .toList(),
        );
  }

  @override
  Future<void> updateCarerRole(
      String familyId, String carerId, String newRole) async {
    final record = await _carerStore.record(carerId).get(_db);
    if (record != null) {
      final updated = Map<String, dynamic>.from(record);
      updated['role'] = newRole;
      await _carerStore.record(carerId).put(_db, updated);
    }
  }

  @override
  Future<void> removeMember({
    required String familyId,
    required String memberUid,
    required String carerId,
  }) async {
    await _db.transaction((txn) async {
      // Remove uid from family memberUids
      final familyRecord = await _familyStore.record(familyId).get(txn);
      if (familyRecord != null) {
        final updated = Map<String, dynamic>.from(familyRecord);
        final memberUids =
            List<String>.from(updated['memberUids'] as List);
        memberUids.remove(memberUid);
        updated['memberUids'] = memberUids;
        updated['modifiedAt'] = DateTime.now().toIso8601String();
        await _familyStore.record(familyId).put(txn, updated);
      }

      // Delete carer record
      await _carerStore.record(carerId).delete(txn);
    });
  }

  @override
  Future<void> updateAllergenCategories(
      String familyId, List<String> categories) async {
    final record = await _familyStore.record(familyId).get(_db);
    if (record != null) {
      final updated = Map<String, dynamic>.from(record);
      updated['allergenCategories'] = categories;
      updated['modifiedAt'] = DateTime.now().toIso8601String();
      await _familyStore.record(familyId).put(_db, updated);
    }
  }

  @override
  Future<List<CascadedChange>> renameAllergenCategory(
      String familyId, String oldName, String newName) async {
    final changes = <CascadedChange>[];

    await _db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();

      // 1. Update family doc: replace oldName→newName in allergenCategories.
      final familyRecord = await _familyStore.record(familyId).get(txn);
      if (familyRecord != null) {
        final updated = Map<String, dynamic>.from(familyRecord);
        final categories = List<String>.from(
            (updated['allergenCategories'] as List<dynamic>?) ?? []);
        final idx = categories.indexOf(oldName);
        if (idx >= 0) categories[idx] = newName;
        updated['allergenCategories'] = categories;
        updated['modifiedAt'] = now;
        await _familyStore.record(familyId).put(txn, updated);
      }

      // 2. Ingredients: replace in allergens lists.
      final ingredients = await StoreRefs.ingredients.find(txn,
          finder: Finder(
            filter: Filter.equals('familyId', familyId),
          ));
      for (final ingredient in ingredients) {
        final allergens = List<String>.from(
            (ingredient.value['allergens'] as List<dynamic>?) ?? []);
        if (allergens.contains(oldName)) {
          final updated = Map<String, dynamic>.from(ingredient.value);
          updated['allergens'] =
              allergens.map((a) => a == oldName ? newName : a).toList();
          updated['modifiedAt'] = now;
          await StoreRefs.ingredients
              .record(ingredient.key)
              .put(txn, updated);
          changes
              .add((collection: 'ingredients', documentId: ingredient.key));
        }
      }

      // 3. Targets: update allergenName where matches.
      final targets = await StoreRefs.targets.find(txn,
          finder: Finder(
            filter: Filter.and([
              Filter.equals('familyId', familyId),
              Filter.equals('allergenName', oldName),
            ]),
          ));
      for (final target in targets) {
        final updated = Map<String, dynamic>.from(target.value);
        updated['allergenName'] = newName;
        updated['modifiedAt'] = now;
        await StoreRefs.targets.record(target.key).put(txn, updated);
        changes.add((collection: 'targets', documentId: target.key));
      }

      // 4. Activities: replace in allergenNames lists.
      final activities = await StoreRefs.activities.find(txn,
          finder: Finder(
            filter: Filter.equals('familyId', familyId),
          ));
      for (final activity in activities) {
        final allergenNames = (activity.value['allergenNames']
                as List<dynamic>?)
            ?.cast<String>();
        if (allergenNames != null && allergenNames.contains(oldName)) {
          final updated = Map<String, dynamic>.from(activity.value);
          updated['allergenNames'] =
              allergenNames.map((a) => a == oldName ? newName : a).toList();
          updated['modifiedAt'] = now;
          await StoreRefs.activities
              .record(activity.key)
              .put(txn, updated);
          changes
              .add((collection: 'activities', documentId: activity.key));
        }
      }
    });

    return changes;
  }

  @override
  Future<List<CascadedChange>> removeAllergenCategory(
      String familyId, String name) async {
    final changes = <CascadedChange>[];

    await _db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();

      // 1. Update family doc: remove from allergenCategories.
      final familyRecord = await _familyStore.record(familyId).get(txn);
      if (familyRecord != null) {
        final updated = Map<String, dynamic>.from(familyRecord);
        final categories = List<String>.from(
            (updated['allergenCategories'] as List<dynamic>?) ?? []);
        categories.remove(name);
        updated['allergenCategories'] = categories;
        updated['modifiedAt'] = now;
        await _familyStore.record(familyId).put(txn, updated);
      }

      // 2. Ingredients: remove from allergens lists.
      final ingredients = await StoreRefs.ingredients.find(txn,
          finder: Finder(
            filter: Filter.equals('familyId', familyId),
          ));
      for (final ingredient in ingredients) {
        final allergens = List<String>.from(
            (ingredient.value['allergens'] as List<dynamic>?) ?? []);
        if (allergens.contains(name)) {
          final updated = Map<String, dynamic>.from(ingredient.value);
          updated['allergens'] =
              allergens.where((a) => a != name).toList();
          updated['modifiedAt'] = now;
          await StoreRefs.ingredients
              .record(ingredient.key)
              .put(txn, updated);
          changes
              .add((collection: 'ingredients', documentId: ingredient.key));
        }
      }

      // 3. Targets: deactivate where allergenName matches.
      final targets = await StoreRefs.targets.find(txn,
          finder: Finder(
            filter: Filter.and([
              Filter.equals('familyId', familyId),
              Filter.equals('allergenName', name),
            ]),
          ));
      for (final target in targets) {
        final updated = Map<String, dynamic>.from(target.value);
        updated['isActive'] = false;
        updated['modifiedAt'] = now;
        await StoreRefs.targets.record(target.key).put(txn, updated);
        changes.add((collection: 'targets', documentId: target.key));
      }

      // 4. Activities: remove from allergenNames lists.
      final activities = await StoreRefs.activities.find(txn,
          finder: Finder(
            filter: Filter.equals('familyId', familyId),
          ));
      for (final activity in activities) {
        final allergenNames = (activity.value['allergenNames']
                as List<dynamic>?)
            ?.cast<String>();
        if (allergenNames != null && allergenNames.contains(name)) {
          final updated = Map<String, dynamic>.from(activity.value);
          updated['allergenNames'] =
              allergenNames.where((a) => a != name).toList();
          updated['modifiedAt'] = now;
          await StoreRefs.activities
              .record(activity.key)
              .put(txn, updated);
          changes
              .add((collection: 'activities', documentId: activity.key));
        }
      }
    });

    return changes;
  }
}
