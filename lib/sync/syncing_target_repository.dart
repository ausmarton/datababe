import '../models/target_model.dart';
import '../repositories/target_repository.dart';
import 'sync_engine.dart';
import 'sync_queue.dart';

class SyncingTargetRepository implements TargetRepository {
  final TargetRepository _local;
  final SyncQueue _queue;
  final SyncEngine _engine;

  SyncingTargetRepository(this._local, this._queue, this._engine);

  @override
  Stream<List<TargetModel>> watchTargets(String familyId, String childId) =>
      _local.watchTargets(familyId, childId);

  @override
  Future<void> createTarget(String familyId, TargetModel target) async {
    await _local.createTarget(familyId, target);
    await _queue.enqueue(
      collection: 'targets',
      documentId: target.id,
      familyId: familyId,
    );
    _engine.notifyWrite();
  }

  @override
  Future<void> updateTarget(String familyId, TargetModel target) async {
    await _local.updateTarget(familyId, target);
    await _queue.enqueue(
      collection: 'targets',
      documentId: target.id,
      familyId: familyId,
    );
    _engine.notifyWrite();
  }

  @override
  Future<void> deactivateTarget(String familyId, String targetId) async {
    await _local.deactivateTarget(familyId, targetId);
    await _queue.enqueue(
      collection: 'targets',
      documentId: targetId,
      familyId: familyId,
    );
    _engine.notifyWrite();
  }
}
