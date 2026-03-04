import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import 'package:datababe/models/activity_model.dart';
import 'package:datababe/repositories/local_activity_repository.dart';

void main() {
  late LocalActivityRepository repo;
  const familyId = 'fam-1';
  const childId = 'child-1';

  setUp(() async {
    final db = await newDatabaseFactoryMemory().openDatabase('test.db');
    repo = LocalActivityRepository(db);
  });

  ActivityModel makeActivity(String id, {String type = 'feedBottle', bool isDeleted = false}) {
    final now = DateTime(2026, 3, 1, 10, 0);
    return ActivityModel(
      id: id,
      childId: childId,
      type: type,
      startTime: now,
      createdAt: now,
      modifiedAt: now,
      isDeleted: isDeleted,
    );
  }

  test('insert and watch returns activity', () async {
    await repo.insertActivity(familyId, makeActivity('act-1'));
    final list = await repo.watchActivities(familyId, childId).first;
    expect(list.length, 1);
    expect(list.first.id, 'act-1');
  });

  test('getActivity returns inserted activity', () async {
    await repo.insertActivity(familyId, makeActivity('act-2'));
    final result = await repo.getActivity(familyId, 'act-2');
    expect(result, isNotNull);
    expect(result!.id, 'act-2');
  });

  test('getActivity returns null for missing id', () async {
    final result = await repo.getActivity(familyId, 'nonexistent');
    expect(result, isNull);
  });

  test('softDeleteActivity marks as deleted and hides from watch', () async {
    await repo.insertActivity(familyId, makeActivity('act-3'));
    await repo.softDeleteActivity(familyId, 'act-3');
    final list = await repo.watchActivities(familyId, childId).first;
    expect(list, isEmpty);
  });

  test('watchActivitiesByType filters on type', () async {
    await repo.insertActivity(familyId, makeActivity('act-4', type: 'feedBottle'));
    await repo.insertActivity(familyId, makeActivity('act-5', type: 'diaper'));
    final list = await repo.watchActivitiesByType(familyId, childId, 'diaper').first;
    expect(list.length, 1);
    expect(list.first.type, 'diaper');
  });

  test('watchActivitiesInRange filters by date', () async {
    final now = DateTime(2026, 3, 1, 10, 0);
    final a1 = ActivityModel(
      id: 'act-6',
      childId: childId,
      type: 'feedBottle',
      startTime: DateTime(2026, 3, 1, 8, 0),
      createdAt: now,
      modifiedAt: now,
    );
    final a2 = ActivityModel(
      id: 'act-7',
      childId: childId,
      type: 'feedBottle',
      startTime: DateTime(2026, 3, 2, 8, 0),
      createdAt: now,
      modifiedAt: now,
    );
    await repo.insertActivity(familyId, a1);
    await repo.insertActivity(familyId, a2);

    final list = await repo.watchActivitiesInRange(
      familyId,
      childId,
      DateTime(2026, 3, 1),
      DateTime(2026, 3, 2),
    ).first;
    expect(list.length, 1);
    expect(list.first.id, 'act-6');
  });

  test('insertActivities batch inserts multiple', () async {
    await repo.insertActivities(familyId, [
      makeActivity('act-8'),
      makeActivity('act-9'),
      makeActivity('act-10'),
    ]);
    final list = await repo.watchActivities(familyId, childId).first;
    expect(list.length, 3);
  });

  test('updateActivity overwrites existing', () async {
    await repo.insertActivity(familyId, makeActivity('act-11'));
    final now = DateTime(2026, 3, 1, 10, 0);
    final updated = ActivityModel(
      id: 'act-11',
      childId: childId,
      type: 'feedBottle',
      startTime: now,
      createdAt: now,
      modifiedAt: now,
      notes: 'updated note',
    );
    await repo.updateActivity(familyId, updated);
    final result = await repo.getActivity(familyId, 'act-11');
    expect(result!.notes, 'updated note');
  });
}
