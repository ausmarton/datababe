import 'package:flutter_test/flutter_test.dart';
import 'package:datababe/models/activity_model.dart';

void main() {
  group('ActivityModel', () {
    test('toFirestore includes all fields', () {
      final now = DateTime(2026, 2, 26, 10, 30);
      final end = DateTime(2026, 2, 26, 10, 45);

      final model = ActivityModel(
        id: 'act-1',
        childId: 'child-1',
        type: 'feedBottle',
        startTime: now,
        endTime: end,
        durationMinutes: 15,
        createdAt: now,
        modifiedAt: now,
        feedType: 'formula',
        volumeMl: 120.0,
        notes: 'test note',
      );

      final map = model.toFirestore();

      expect(map['childId'], 'child-1');
      expect(map['type'], 'feedBottle');
      expect(map['durationMinutes'], 15);
      expect(map['feedType'], 'formula');
      expect(map['volumeMl'], 120.0);
      expect(map['notes'], 'test note');
      expect(map['isDeleted'], false);
    });

    test('nullable fields default to null in toFirestore', () {
      final now = DateTime(2026, 2, 26);
      final model = ActivityModel(
        id: 'act-2',
        childId: 'child-1',
        type: 'diaper',
        startTime: now,
        createdAt: now,
        modifiedAt: now,
      );

      final map = model.toFirestore();

      expect(map['endTime'], isNull);
      expect(map['feedType'], isNull);
      expect(map['volumeMl'], isNull);
      expect(map['medicationName'], isNull);
      expect(map['weightKg'], isNull);
    });

    test('all activity fields round-trip through toFirestore', () {
      final now = DateTime(2026, 2, 26, 12, 0);
      final model = ActivityModel(
        id: 'act-3',
        childId: 'child-1',
        type: 'growth',
        startTime: now,
        createdAt: now,
        modifiedAt: now,
        weightKg: 6.5,
        lengthCm: 62.0,
        headCircumferenceCm: 40.5,
      );

      final map = model.toFirestore();

      expect(map['weightKg'], 6.5);
      expect(map['lengthCm'], 62.0);
      expect(map['headCircumferenceCm'], 40.5);
    });

    test('allergenNames serializes when set', () {
      final now = DateTime(2026, 2, 27);
      final model = ActivityModel(
        id: 'act-4',
        childId: 'child-1',
        type: 'solids',
        startTime: now,
        createdAt: now,
        modifiedAt: now,
        allergenNames: ['lactose', 'gluten'],
      );

      final map = model.toFirestore();
      expect(map['allergenNames'], ['lactose', 'gluten']);
    });

    test('allergenNames defaults to null', () {
      final now = DateTime(2026, 2, 27);
      final model = ActivityModel(
        id: 'act-5',
        childId: 'child-1',
        type: 'solids',
        startTime: now,
        createdAt: now,
        modifiedAt: now,
      );

      expect(model.allergenNames, isNull);
      expect(model.toFirestore()['allergenNames'], isNull);
    });
  });
}
