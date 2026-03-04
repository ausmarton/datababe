import 'package:sembast/sembast.dart';

import '../local/store_refs.dart';
import '../models/target_model.dart';
import 'target_repository.dart';

class LocalTargetRepository implements TargetRepository {
  final Database _db;

  LocalTargetRepository(this._db);

  StoreRef<String, Map<String, dynamic>> get _store => StoreRefs.targets;

  @override
  Stream<List<TargetModel>> watchTargets(String familyId, String childId) {
    final finder = Finder(
      filter: Filter.and([
        Filter.equals('familyId', familyId),
        Filter.equals('childId', childId),
        Filter.equals('isActive', true),
      ]),
      sortOrders: [SortOrder('createdAt', false)],
    );
    return _store.query(finder: finder).onSnapshots(_db).map(
          (snapshots) => snapshots
              .map((s) => TargetModel.fromMap(s.key, s.value))
              .toList(),
        );
  }

  @override
  Future<void> createTarget(String familyId, TargetModel target) async {
    final map = target.toMap();
    map['familyId'] = familyId;
    await _store.record(target.id).put(_db, map);
  }

  @override
  Future<void> updateTarget(String familyId, TargetModel target) async {
    final map = target.toMap();
    map['familyId'] = familyId;
    await _store.record(target.id).put(_db, map);
  }

  @override
  Future<void> deactivateTarget(String familyId, String targetId) async {
    final record = await _store.record(targetId).get(_db);
    if (record != null) {
      final updated = Map<String, dynamic>.from(record);
      updated['isActive'] = false;
      updated['modifiedAt'] = DateTime.now().toIso8601String();
      await _store.record(targetId).put(_db, updated);
    }
  }
}
