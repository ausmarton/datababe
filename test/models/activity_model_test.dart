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

    test('toMap/fromMap round-trip preserves all fields', () {
      final now = DateTime(2026, 2, 27, 10, 30);
      final end = DateTime(2026, 2, 27, 10, 45);

      final model = ActivityModel(
        id: 'act-rt',
        childId: 'child-1',
        type: 'solids',
        startTime: now,
        endTime: end,
        durationMinutes: 15,
        createdBy: 'uid-1',
        createdAt: now,
        modifiedAt: now,
        isDeleted: false,
        notes: 'test',
        feedType: 'formula',
        volumeMl: 120.0,
        rightBreastMinutes: 10,
        leftBreastMinutes: 8,
        contents: 'poo',
        contentSize: 'medium',
        pooColour: 'yellow',
        pooConsistency: 'soft',
        peeSize: 'large',
        medicationName: 'vitamin D',
        dose: '400',
        doseUnit: 'IU',
        foodDescription: 'banana',
        reaction: 'loved',
        recipeId: 'recipe-1',
        ingredientNames: ['banana', 'oats'],
        allergenNames: ['gluten'],
        weightKg: 6.5,
        lengthCm: 62.0,
        headCircumferenceCm: 40.5,
        tempCelsius: 36.8,
      );

      final map = model.toMap();
      final restored = ActivityModel.fromMap('act-rt', map);

      expect(restored.id, model.id);
      expect(restored.childId, model.childId);
      expect(restored.type, model.type);
      expect(restored.startTime, model.startTime);
      expect(restored.endTime, model.endTime);
      expect(restored.durationMinutes, model.durationMinutes);
      expect(restored.createdBy, model.createdBy);
      expect(restored.createdAt, model.createdAt);
      expect(restored.modifiedAt, model.modifiedAt);
      expect(restored.isDeleted, model.isDeleted);
      expect(restored.notes, model.notes);
      expect(restored.feedType, model.feedType);
      expect(restored.volumeMl, model.volumeMl);
      expect(restored.rightBreastMinutes, model.rightBreastMinutes);
      expect(restored.leftBreastMinutes, model.leftBreastMinutes);
      expect(restored.contents, model.contents);
      expect(restored.contentSize, model.contentSize);
      expect(restored.pooColour, model.pooColour);
      expect(restored.pooConsistency, model.pooConsistency);
      expect(restored.peeSize, model.peeSize);
      expect(restored.medicationName, model.medicationName);
      expect(restored.dose, model.dose);
      expect(restored.doseUnit, model.doseUnit);
      expect(restored.foodDescription, model.foodDescription);
      expect(restored.reaction, model.reaction);
      expect(restored.recipeId, model.recipeId);
      expect(restored.ingredientNames, model.ingredientNames);
      expect(restored.allergenNames, model.allergenNames);
      expect(restored.weightKg, model.weightKg);
      expect(restored.lengthCm, model.lengthCm);
      expect(restored.headCircumferenceCm, model.headCircumferenceCm);
      expect(restored.tempCelsius, model.tempCelsius);
    });

    test('fromMap with missing createdAt uses fallback', () {
      final map = {
        'childId': 'c1',
        'type': 'feedBottle',
        'startTime': DateTime(2026, 3, 6).toIso8601String(),
        'modifiedAt': DateTime(2026, 3, 6).toIso8601String(),
      };

      final before = DateTime.now();
      final model = ActivityModel.fromMap('act-missing-created', map);
      final after = DateTime.now();

      expect(model.createdAt, isNotNull);
      // Should be approximately now (fallback)
      expect(
          model.createdAt.isAfter(before.subtract(const Duration(seconds: 1))),
          isTrue);
      expect(
          model.createdAt.isBefore(after.add(const Duration(seconds: 1))),
          isTrue);
    });

    test('fromMap with missing modifiedAt falls back to createdAt', () {
      final createdAt = DateTime(2026, 3, 6, 10, 0);
      final map = {
        'childId': 'c1',
        'type': 'feedBottle',
        'startTime': DateTime(2026, 3, 6).toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

      final model = ActivityModel.fromMap('act-missing-modified', map);

      expect(model.modifiedAt, createdAt);
    });

    test('fromMap with missing startTime falls back to createdAt', () {
      final createdAt = DateTime(2026, 3, 6, 10, 0);
      final map = {
        'childId': 'c1',
        'type': 'feedBottle',
        'createdAt': createdAt.toIso8601String(),
        'modifiedAt': DateTime(2026, 3, 6).toIso8601String(),
      };

      final model = ActivityModel.fromMap('act-missing-start', map);

      // startTime should fall back to createdAt, NOT DateTime.now()
      expect(model.startTime, createdAt);
    });

    test('fromMap with ALL timestamps missing fills all with fallbacks', () {
      final map = <String, dynamic>{
        'childId': 'c1',
        'type': 'feedBottle',
      };

      final model = ActivityModel.fromMap('act-all-missing', map);

      expect(model.startTime, isNotNull);
      expect(model.createdAt, isNotNull);
      expect(model.modifiedAt, isNotNull);
      // All should fall back to the same DateTime.now() value
      expect(model.modifiedAt, model.createdAt);
      expect(model.startTime, model.createdAt);
    });

    test('toMap/fromMap handles nullable fields as null', () {
      final now = DateTime(2026, 2, 27);
      final model = ActivityModel(
        id: 'act-null',
        childId: 'child-1',
        type: 'diaper',
        startTime: now,
        createdAt: now,
        modifiedAt: now,
      );

      final map = model.toMap();
      final restored = ActivityModel.fromMap('act-null', map);

      expect(restored.endTime, isNull);
      expect(restored.feedType, isNull);
      expect(restored.volumeMl, isNull);
      expect(restored.ingredientNames, isNull);
      expect(restored.allergenNames, isNull);
      expect(restored.weightKg, isNull);
    });
  });
}
