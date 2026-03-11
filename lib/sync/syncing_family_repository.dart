import 'package:sembast/sembast.dart';

import '../models/family_model.dart';
import '../models/child_model.dart';
import '../models/carer_model.dart';
import '../repositories/cascaded_change.dart';
import '../repositories/family_repository.dart';
import '../repositories/local_family_repository.dart';
import 'sync_engine_interface.dart';
import 'sync_queue.dart';

class SyncingFamilyRepository implements FamilyRepository {
  final LocalFamilyRepository _local;
  final SyncQueue _queue;
  final SyncEngineInterface _engine;
  final Database _db;

  SyncingFamilyRepository(this._local, this._queue, this._engine, this._db);

  @override
  Stream<List<FamilyModel>> watchFamilies(String uid) =>
      _local.watchFamilies(uid);

  @override
  Stream<List<ChildModel>> watchChildren(String familyId) =>
      _local.watchChildren(familyId);

  @override
  Stream<List<CarerModel>> watchCarers(String familyId) =>
      _local.watchCarers(familyId);

  @override
  Future<FamilyModel> createFamily(FamilyModel family) async {
    late FamilyModel result;
    await _db.transaction((txn) async {
      result = await _local.createFamily(family, txn: txn);
      await _queue.enqueueTxn(txn,
        collection: 'families',
        documentId: family.id,
        familyId: family.id,
        isNew: true,
      );
    });
    _engine.notifyWrite();
    return result;
  }

  @override
  Future<ChildModel> createChild(String familyId, ChildModel child) async {
    late ChildModel result;
    await _db.transaction((txn) async {
      result = await _local.createChild(familyId, child, txn: txn);
      await _queue.enqueueTxn(txn,
        collection: 'children',
        documentId: child.id,
        familyId: familyId,
        isNew: true,
      );
    });
    _engine.notifyWrite();
    return result;
  }

  @override
  Future<CarerModel> createCarer(String familyId, CarerModel carer) async {
    late CarerModel result;
    await _db.transaction((txn) async {
      result = await _local.createCarer(familyId, carer, txn: txn);
      await _queue.enqueueTxn(txn,
        collection: 'carers',
        documentId: carer.id,
        familyId: familyId,
        isNew: true,
      );
    });
    _engine.notifyWrite();
    return result;
  }

  @override
  Future<void> createFamilyWithChild({
    required FamilyModel family,
    required ChildModel child,
    required CarerModel carer,
  }) async {
    await _db.transaction((txn) async {
      await _local.createFamilyWithChild(
        family: family,
        child: child,
        carer: carer,
        txn: txn,
      );
      await _queue.enqueueTxn(txn,
        collection: 'families',
        documentId: family.id,
        familyId: family.id,
        isNew: true,
      );
      await _queue.enqueueTxn(txn,
        collection: 'children',
        documentId: child.id,
        familyId: family.id,
        isNew: true,
      );
      await _queue.enqueueTxn(txn,
        collection: 'carers',
        documentId: carer.id,
        familyId: family.id,
        isNew: true,
      );
    });
    _engine.notifyWrite();
  }

  @override
  Future<void> updateCarerRole(
      String familyId, String carerId, String newRole) async {
    await _db.transaction((txn) async {
      await _local.updateCarerRole(familyId, carerId, newRole, txn: txn);
      await _queue.enqueueTxn(txn,
        collection: 'carers',
        documentId: carerId,
        familyId: familyId,
      );
    });
    _engine.notifyWrite();
  }

  @override
  Future<void> removeMember({
    required String familyId,
    required String memberUid,
    required String carerId,
  }) async {
    await _db.transaction((txn) async {
      await _local.removeMember(
        familyId: familyId,
        memberUid: memberUid,
        carerId: carerId,
        txn: txn,
      );
      await _queue.enqueueTxn(txn,
        collection: 'families',
        documentId: familyId,
        familyId: familyId,
      );
    });
    _engine.notifyWrite();
  }

  @override
  Future<void> updateAllergenCategories(
      String familyId, List<String> categories) async {
    await _db.transaction((txn) async {
      await _local.updateAllergenCategories(familyId, categories, txn: txn);
      await _queue.enqueueTxn(txn,
        collection: 'families',
        documentId: familyId,
        familyId: familyId,
      );
    });
    _engine.notifyWrite();
  }

  @override
  Future<List<CascadedChange>> renameAllergenCategory(
      String familyId, String oldName, String newName) async {
    late List<CascadedChange> changes;
    await _db.transaction((txn) async {
      changes =
          await _local.renameAllergenCategory(familyId, oldName, newName,
              txn: txn);
      await _queue.enqueueTxn(txn,
        collection: 'families',
        documentId: familyId,
        familyId: familyId,
      );
      for (final change in changes) {
        await _queue.enqueueTxn(txn,
          collection: change.collection,
          documentId: change.documentId,
          familyId: familyId,
        );
      }
    });
    _engine.notifyWrite();
    return changes;
  }

  @override
  Future<List<CascadedChange>> removeAllergenCategory(
      String familyId, String name) async {
    late List<CascadedChange> changes;
    await _db.transaction((txn) async {
      changes =
          await _local.removeAllergenCategory(familyId, name, txn: txn);
      await _queue.enqueueTxn(txn,
        collection: 'families',
        documentId: familyId,
        familyId: familyId,
      );
      for (final change in changes) {
        await _queue.enqueueTxn(txn,
          collection: change.collection,
          documentId: change.documentId,
          familyId: familyId,
        );
      }
    });
    _engine.notifyWrite();
    return changes;
  }
}
