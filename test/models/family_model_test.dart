import 'package:flutter_test/flutter_test.dart';
import 'package:datababe/models/family_model.dart';

void main() {
  group('FamilyModel', () {
    test('toFirestore includes all fields', () {
      final now = DateTime(2026, 2, 26, 10, 0);

      final model = FamilyModel(
        id: 'fam-1',
        name: 'Test Family',
        createdBy: 'uid-123',
        memberUids: ['uid-123', 'uid-456'],
        createdAt: now,
      );

      final map = model.toFirestore();

      expect(map['name'], 'Test Family');
      expect(map['createdBy'], 'uid-123');
      expect(map['memberUids'], ['uid-123', 'uid-456']);
    });

    test('toFirestore does not include id', () {
      final model = FamilyModel(
        id: 'fam-2',
        name: 'Another Family',
        createdBy: 'uid-789',
        memberUids: ['uid-789'],
        createdAt: DateTime(2026, 1, 1),
      );

      final map = model.toFirestore();

      // Firestore doc ID is separate from the data
      expect(map.containsKey('id'), false);
    });

    test('allergenCategories defaults to empty list', () {
      final model = FamilyModel(
        id: 'fam-3',
        name: 'Family',
        createdBy: 'uid-1',
        memberUids: ['uid-1'],
        createdAt: DateTime(2026, 2, 27),
      );

      expect(model.allergenCategories, isEmpty);
      expect(model.toFirestore()['allergenCategories'], isEmpty);
    });

    test('allergenCategories serializes when set', () {
      final model = FamilyModel(
        id: 'fam-4',
        name: 'Family',
        createdBy: 'uid-1',
        memberUids: ['uid-1'],
        createdAt: DateTime(2026, 2, 27),
        allergenCategories: ['lactose', 'nuts', 'gluten'],
      );

      final map = model.toFirestore();
      expect(map['allergenCategories'], ['lactose', 'nuts', 'gluten']);
    });
  });
}
