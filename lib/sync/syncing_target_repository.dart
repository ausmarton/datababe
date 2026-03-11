import 'package:sembast/sembast.dart';

import '../models/target_model.dart';
import '../repositories/local_target_repository.dart';
import '../repositories/target_repository.dart';
import 'sync_engine.dart';
import 'sync_queue.dart';

class SyncingTargetRepository implements TargetRepository {
  final LocalTargetRepository _local;
  final SyncQueue _queue;
  final SyncEngine _engine;
  final Database _db;

  SyncingTargetRepository(this._local, this._queue, this._engine, this._db);

  @override
  Stream<List<TargetModel>> watchTargets(String familyId, String childId) =>
      _local.watchTargets(familyId, childId);

  @override
  Future<void> createTarget(String familyId, TargetModel target) async {
    await _db.transaction((txn) async {
      await _local.createTarget(familyId, target, txn: txn);
      await _queue.enqueueTxn(txn,
        collection: 'targets',
        documentId: target.id,
        familyId: familyId,
        isNew: true,
      );
    });
    _engine.notifyWrite();
  }

  @override
  Future<void> updateTarget(String familyId, TargetModel target) async {
    await _db.transaction((txn) async {
      await _local.updateTarget(familyId, target, txn: txn);
      await _queue.enqueueTxn(txn,
        collection: 'targets',
        documentId: target.id,
        familyId: familyId,
      );
    });
    _engine.notifyWrite();
  }

  @override
  Future<void> deactivateTarget(String familyId, String targetId) async {
    await _db.transaction((txn) async {
      await _local.deactivateTarget(familyId, targetId, txn: txn);
      await _queue.enqueueTxn(txn,
        collection: 'targets',
        documentId: targetId,
        familyId: familyId,
      );
    });
    _engine.notifyWrite();
  }
}
