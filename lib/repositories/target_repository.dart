import '../models/target_model.dart';

abstract class TargetRepository {
  Stream<List<TargetModel>> watchTargets(String familyId, String childId);

  Future<void> createTarget(String familyId, TargetModel target);

  Future<void> updateTarget(String familyId, TargetModel target);

  Future<void> deactivateTarget(String familyId, String targetId);
}
