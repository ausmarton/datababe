import '../models/family_model.dart';
import '../models/child_model.dart';
import '../models/carer_model.dart';
import '../repositories/family_repository.dart';
import 'sync_engine.dart';
import 'sync_queue.dart';

class SyncingFamilyRepository implements FamilyRepository {
  final FamilyRepository _local;
  final SyncQueue _queue;
  final SyncEngine _engine;

  SyncingFamilyRepository(this._local, this._queue, this._engine);

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
    final result = await _local.createFamily(family);
    await _queue.enqueue(
      collection: 'families',
      documentId: family.id,
      familyId: family.id,
      isNew: true,
    );
    _engine.notifyWrite();
    return result;
  }

  @override
  Future<ChildModel> createChild(String familyId, ChildModel child) async {
    final result = await _local.createChild(familyId, child);
    await _queue.enqueue(
      collection: 'children',
      documentId: child.id,
      familyId: familyId,
      isNew: true,
    );
    _engine.notifyWrite();
    return result;
  }

  @override
  Future<CarerModel> createCarer(String familyId, CarerModel carer) async {
    final result = await _local.createCarer(familyId, carer);
    await _queue.enqueue(
      collection: 'carers',
      documentId: carer.id,
      familyId: familyId,
      isNew: true,
    );
    _engine.notifyWrite();
    return result;
  }

  @override
  Future<void> createFamilyWithChild({
    required FamilyModel family,
    required ChildModel child,
    required CarerModel carer,
  }) async {
    await _local.createFamilyWithChild(
      family: family,
      child: child,
      carer: carer,
    );
    await _queue.enqueue(
      collection: 'families',
      documentId: family.id,
      familyId: family.id,
      isNew: true,
    );
    await _queue.enqueue(
      collection: 'children',
      documentId: child.id,
      familyId: family.id,
      isNew: true,
    );
    await _queue.enqueue(
      collection: 'carers',
      documentId: carer.id,
      familyId: family.id,
      isNew: true,
    );
    _engine.notifyWrite();
  }

  @override
  Future<void> updateCarerRole(
      String familyId, String carerId, String newRole) async {
    await _local.updateCarerRole(familyId, carerId, newRole);
    await _queue.enqueue(
      collection: 'carers',
      documentId: carerId,
      familyId: familyId,
    );
    _engine.notifyWrite();
  }

  @override
  Future<void> removeMember({
    required String familyId,
    required String memberUid,
    required String carerId,
  }) async {
    await _local.removeMember(
      familyId: familyId,
      memberUid: memberUid,
      carerId: carerId,
    );
    await _queue.enqueue(
      collection: 'families',
      documentId: familyId,
      familyId: familyId,
    );
    _engine.notifyWrite();
  }

  @override
  Future<void> updateAllergenCategories(
      String familyId, List<String> categories) async {
    await _local.updateAllergenCategories(familyId, categories);
    await _queue.enqueue(
      collection: 'families',
      documentId: familyId,
      familyId: familyId,
    );
    _engine.notifyWrite();
  }
}
