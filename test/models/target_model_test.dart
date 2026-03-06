import 'package:flutter_test/flutter_test.dart';
import 'package:datababe/models/target_model.dart';

void main() {
  group('TargetModel', () {
    test('toFirestore includes all fields', () {
      final now = DateTime(2026, 2, 26);
      final target = TargetModel(
        id: 'target-1',
        childId: 'child-1',
        activityType: 'feedBottle',
        metric: 'totalVolumeMl',
        period: 'daily',
        targetValue: 800,
        isActive: true,
        createdBy: 'uid-1',
        createdAt: now,
        modifiedAt: now,
      );

      final map = target.toFirestore();

      expect(map['childId'], 'child-1');
      expect(map['activityType'], 'feedBottle');
      expect(map['metric'], 'totalVolumeMl');
      expect(map['period'], 'daily');
      expect(map['targetValue'], 800);
      expect(map['isActive'], true);
      expect(map['createdBy'], 'uid-1');
    });

    test('toFirestore does not include id', () {
      final now = DateTime(2026, 2, 26);
      final target = TargetModel(
        id: 'target-1',
        childId: 'child-1',
        activityType: 'feedBottle',
        metric: 'count',
        period: 'weekly',
        targetValue: 42,
        createdBy: 'uid-1',
        createdAt: now,
        modifiedAt: now,
      );

      final map = target.toFirestore();
      expect(map.containsKey('id'), isFalse);
    });

    test('inactive target serializes isActive=false', () {
      final now = DateTime(2026, 2, 26);
      final target = TargetModel(
        id: 'target-2',
        childId: 'child-1',
        activityType: 'diaper',
        metric: 'count',
        period: 'daily',
        targetValue: 8,
        isActive: false,
        createdBy: 'uid-1',
        createdAt: now,
        modifiedAt: now,
      );

      final map = target.toFirestore();
      expect(map['isActive'], false);
    });

    test('ingredientName serializes when set', () {
      final now = DateTime(2026, 2, 27);
      final target = TargetModel(
        id: 'target-3',
        childId: 'child-1',
        activityType: 'solids',
        metric: 'ingredientExposures',
        period: 'weekly',
        targetValue: 3,
        createdBy: 'uid-1',
        createdAt: now,
        modifiedAt: now,
        ingredientName: 'egg',
      );

      final map = target.toFirestore();
      expect(map['ingredientName'], 'egg');
      expect(map['metric'], 'ingredientExposures');
    });

    test('ingredientName defaults to null', () {
      final now = DateTime(2026, 2, 27);
      final target = TargetModel(
        id: 'target-4',
        childId: 'child-1',
        activityType: 'feedBottle',
        metric: 'count',
        period: 'daily',
        targetValue: 6,
        createdBy: 'uid-1',
        createdAt: now,
        modifiedAt: now,
      );

      expect(target.ingredientName, isNull);
      expect(target.toFirestore()['ingredientName'], isNull);
    });

    test('allergenName serializes when set', () {
      final now = DateTime(2026, 2, 27);
      final target = TargetModel(
        id: 'target-5',
        childId: 'child-1',
        activityType: 'solids',
        metric: 'allergenExposures',
        period: 'weekly',
        targetValue: 3,
        createdBy: 'uid-1',
        createdAt: now,
        modifiedAt: now,
        allergenName: 'lactose',
      );

      final map = target.toFirestore();
      expect(map['allergenName'], 'lactose');
      expect(map['metric'], 'allergenExposures');
    });

    test('allergenName defaults to null', () {
      final now = DateTime(2026, 2, 27);
      final target = TargetModel(
        id: 'target-6',
        childId: 'child-1',
        activityType: 'feedBottle',
        metric: 'count',
        period: 'daily',
        targetValue: 6,
        createdBy: 'uid-1',
        createdAt: now,
        modifiedAt: now,
      );

      expect(target.allergenName, isNull);
      expect(target.toFirestore()['allergenName'], isNull);
    });

    test('toMap/fromMap round-trip preserves all fields', () {
      final now = DateTime(2026, 2, 27, 10, 30);
      final target = TargetModel(
        id: 'target-rt',
        childId: 'child-1',
        activityType: 'solids',
        metric: 'ingredientExposures',
        period: 'weekly',
        targetValue: 5,
        isActive: true,
        createdBy: 'uid-1',
        createdAt: now,
        modifiedAt: now,
        ingredientName: 'egg',
        allergenName: 'lactose',
      );

      final map = target.toMap();
      final restored = TargetModel.fromMap('target-rt', map);

      expect(restored.id, target.id);
      expect(restored.childId, target.childId);
      expect(restored.activityType, target.activityType);
      expect(restored.metric, target.metric);
      expect(restored.period, target.period);
      expect(restored.targetValue, target.targetValue);
      expect(restored.isActive, target.isActive);
      expect(restored.createdBy, target.createdBy);
      expect(restored.createdAt, target.createdAt);
      expect(restored.modifiedAt, target.modifiedAt);
      expect(restored.ingredientName, target.ingredientName);
      expect(restored.allergenName, target.allergenName);
      expect(restored.isDeleted, false);
    });

    test('isDeleted defaults to false', () {
      final now = DateTime(2026, 2, 27);
      final target = TargetModel(
        id: 'target-def',
        childId: 'child-1',
        activityType: 'feedBottle',
        metric: 'count',
        period: 'daily',
        targetValue: 6,
        createdBy: 'uid-1',
        createdAt: now,
        modifiedAt: now,
      );
      expect(target.isDeleted, false);
    });

    test('toFirestore includes isDeleted', () {
      final now = DateTime(2026, 2, 27);
      final target = TargetModel(
        id: 'target-del',
        childId: 'child-1',
        activityType: 'feedBottle',
        metric: 'count',
        period: 'daily',
        targetValue: 6,
        isDeleted: true,
        createdBy: 'uid-1',
        createdAt: now,
        modifiedAt: now,
      );

      final map = target.toFirestore();
      expect(map['isDeleted'], true);
    });

    test('toMap includes isDeleted', () {
      final now = DateTime(2026, 2, 27);
      final target = TargetModel(
        id: 'target-del',
        childId: 'child-1',
        activityType: 'feedBottle',
        metric: 'count',
        period: 'daily',
        targetValue: 6,
        isDeleted: true,
        createdBy: 'uid-1',
        createdAt: now,
        modifiedAt: now,
      );

      final map = target.toMap();
      expect(map['isDeleted'], true);
    });

    test('fromMap with missing isDeleted defaults to false', () {
      final map = {
        'childId': 'child-1',
        'activityType': 'feedBottle',
        'metric': 'count',
        'period': 'daily',
        'targetValue': 6,
        'createdBy': 'uid-1',
        'createdAt': '2026-02-27T00:00:00.000',
        'modifiedAt': '2026-02-27T00:00:00.000',
      };

      final restored = TargetModel.fromMap('target-1', map);
      expect(restored.isDeleted, false);
    });

    test('toMap/fromMap round-trip with isDeleted true', () {
      final now = DateTime(2026, 2, 27);
      final target = TargetModel(
        id: 'target-del-rt',
        childId: 'child-1',
        activityType: 'feedBottle',
        metric: 'count',
        period: 'daily',
        targetValue: 6,
        isDeleted: true,
        createdBy: 'uid-1',
        createdAt: now,
        modifiedAt: now,
      );

      final map = target.toMap();
      final restored = TargetModel.fromMap('target-del-rt', map);
      expect(restored.isDeleted, true);
    });

    test('fromMap with missing modifiedAt falls back to createdAt', () {
      final map = {
        'childId': 'child-1',
        'activityType': 'feedBottle',
        'metric': 'count',
        'period': 'daily',
        'targetValue': 6,
        'createdBy': 'uid-1',
        'createdAt': '2026-02-27T00:00:00.000',
      };

      final restored = TargetModel.fromMap('target-1', map);
      expect(restored.modifiedAt, restored.createdAt);
    });
  });
}
