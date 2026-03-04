import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import 'package:datababe/models/target_model.dart';
import 'package:datababe/repositories/local_target_repository.dart';

void main() {
  late LocalTargetRepository repo;
  const familyId = 'fam-1';
  const childId = 'child-1';

  setUp(() async {
    final db = await newDatabaseFactoryMemory().openDatabase('test.db');
    repo = LocalTargetRepository(db);
  });

  TargetModel make(String id) {
    final now = DateTime(2026, 3, 1);
    return TargetModel(
      id: id,
      childId: childId,
      activityType: 'feedBottle',
      metric: 'totalVolumeMl',
      period: 'daily',
      targetValue: 800,
      createdBy: 'uid-1',
      createdAt: now,
      modifiedAt: now,
    );
  }

  test('create and watch returns target', () async {
    await repo.createTarget(familyId, make('t-1'));
    final list = await repo.watchTargets(familyId, childId).first;
    expect(list.length, 1);
    expect(list.first.targetValue, 800);
  });

  test('deactivateTarget hides from watch', () async {
    await repo.createTarget(familyId, make('t-2'));
    await repo.deactivateTarget(familyId, 't-2');
    final list = await repo.watchTargets(familyId, childId).first;
    expect(list, isEmpty);
  });

  test('updateTarget modifies existing', () async {
    await repo.createTarget(familyId, make('t-3'));
    final now = DateTime(2026, 3, 1);
    await repo.updateTarget(
      familyId,
      TargetModel(
        id: 't-3',
        childId: childId,
        activityType: 'feedBottle',
        metric: 'totalVolumeMl',
        period: 'daily',
        targetValue: 900,
        createdBy: 'uid-1',
        createdAt: now,
        modifiedAt: now,
      ),
    );
    final list = await repo.watchTargets(familyId, childId).first;
    expect(list.first.targetValue, 900);
  });
}
