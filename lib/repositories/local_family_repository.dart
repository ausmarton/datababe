import 'package:sembast/sembast.dart';

import '../local/store_refs.dart';
import '../models/family_model.dart';
import '../models/child_model.dart';
import '../models/carer_model.dart';
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
}
