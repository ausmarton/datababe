import 'package:flutter_test/flutter_test.dart';
import 'package:datababe/models/ingredient_model.dart';

void main() {
  group('IngredientModel', () {
    test('toFirestore includes all fields', () {
      final now = DateTime(2026, 2, 27, 10, 0);
      final model = IngredientModel(
        id: 'ing-1',
        name: 'egg',
        allergens: ['egg'],
        createdBy: 'uid-1',
        createdAt: now,
        modifiedAt: now,
      );

      final map = model.toFirestore();

      expect(map['name'], 'egg');
      expect(map['allergens'], ['egg']);
      expect(map['isDeleted'], false);
      expect(map['createdBy'], 'uid-1');
    });

    test('toFirestore does not include id', () {
      final now = DateTime(2026, 2, 27);
      final model = IngredientModel(
        id: 'ing-2',
        name: "cow's milk",
        allergens: ['lactose'],
        createdBy: 'uid-1',
        createdAt: now,
        modifiedAt: now,
      );

      expect(model.toFirestore().containsKey('id'), false);
    });

    test('allergens defaults to empty list', () {
      final now = DateTime(2026, 2, 27);
      final model = IngredientModel(
        id: 'ing-3',
        name: 'banana',
        createdBy: 'uid-1',
        createdAt: now,
        modifiedAt: now,
      );

      expect(model.allergens, isEmpty);
      expect(model.toFirestore()['allergens'], isEmpty);
    });

    test('multiple allergens serialized correctly', () {
      final now = DateTime(2026, 2, 27);
      final model = IngredientModel(
        id: 'ing-4',
        name: 'cheese',
        allergens: ['lactose', 'dairy'],
        createdBy: 'uid-1',
        createdAt: now,
        modifiedAt: now,
      );

      final map = model.toFirestore();
      expect(map['allergens'], ['lactose', 'dairy']);
    });

    test('isDeleted serializes when true', () {
      final now = DateTime(2026, 2, 27);
      final model = IngredientModel(
        id: 'ing-5',
        name: 'peanut',
        allergens: ['nuts'],
        isDeleted: true,
        createdBy: 'uid-1',
        createdAt: now,
        modifiedAt: now,
      );

      expect(model.toFirestore()['isDeleted'], true);
    });

    test('toMap/fromMap round-trip preserves all fields', () {
      final now = DateTime(2026, 2, 27, 10, 30);
      final model = IngredientModel(
        id: 'ing-rt',
        name: 'cheese',
        allergens: ['lactose', 'dairy'],
        isDeleted: false,
        createdBy: 'uid-1',
        createdAt: now,
        modifiedAt: now,
      );

      final map = model.toMap();
      final restored = IngredientModel.fromMap('ing-rt', map);

      expect(restored.id, model.id);
      expect(restored.name, model.name);
      expect(restored.allergens, model.allergens);
      expect(restored.isDeleted, model.isDeleted);
      expect(restored.createdBy, model.createdBy);
      expect(restored.createdAt, model.createdAt);
      expect(restored.modifiedAt, model.modifiedAt);
    });
  });
}
