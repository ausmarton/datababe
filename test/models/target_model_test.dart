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
      );

      final map = target.toFirestore();
      expect(map['isActive'], false);
    });
  });
}
