import 'package:flutter_test/flutter_test.dart';
import 'package:datababe/models/ingredient_model.dart';
import 'package:datababe/utils/allergen_helpers.dart';

IngredientModel _ingredient(String name, List<String> allergens) {
  final now = DateTime(2026, 2, 27);
  return IngredientModel(
    id: 'id-$name',
    name: name,
    allergens: allergens,
    createdBy: 'uid-1',
    createdAt: now,
    modifiedAt: now,
  );
}

void main() {
  group('computeAllergensByName', () {
    final allIngredients = [
      _ingredient('egg', ['egg']),
      _ingredient("cow's milk", ['lactose', 'dairy']),
      _ingredient('peanut butter', ['nuts']),
      _ingredient('banana', []),
      _ingredient('bread', ['gluten']),
    ];

    test('returns empty set for empty ingredient names', () {
      final result = computeAllergensByName([], allIngredients);
      expect(result, isEmpty);
    });

    test('returns empty set for unrecognized ingredients', () {
      final result = computeAllergensByName(['kale', 'spinach'], allIngredients);
      expect(result, isEmpty);
    });

    test('returns allergens for single known ingredient', () {
      final result = computeAllergensByName(['egg'], allIngredients);
      expect(result, {'egg'});
    });

    test('returns combined allergens for multiple ingredients', () {
      final result = computeAllergensByName(
          ['egg', "cow's milk", 'bread'], allIngredients);
      expect(result, {'egg', 'lactose', 'dairy', 'gluten'});
    });

    test('ingredients without allergens produce no entries', () {
      final result = computeAllergensByName(['banana'], allIngredients);
      expect(result, isEmpty);
    });

    test('matching is case-insensitive', () {
      final result = computeAllergensByName(['Egg', 'EGG'], allIngredients);
      expect(result, {'egg'});
    });

    test('returns empty set when allIngredients is empty', () {
      final result = computeAllergensByName(['egg'], []);
      expect(result, isEmpty);
    });
  });
}
