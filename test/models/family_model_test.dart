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
        modifiedAt: now,
      );

      final map = model.toFirestore();

      expect(map['name'], 'Test Family');
      expect(map['createdBy'], 'uid-123');
      expect(map['memberUids'], ['uid-123', 'uid-456']);
    });

    test('toFirestore does not include id', () {
      final now = DateTime(2026, 1, 1);
      final model = FamilyModel(
        id: 'fam-2',
        name: 'Another Family',
        createdBy: 'uid-789',
        memberUids: ['uid-789'],
        createdAt: now,
        modifiedAt: now,
      );

      final map = model.toFirestore();

      // Firestore doc ID is separate from the data
      expect(map.containsKey('id'), false);
    });

    test('allergenCategories defaults to empty list', () {
      final now = DateTime(2026, 2, 27);
      final model = FamilyModel(
        id: 'fam-3',
        name: 'Family',
        createdBy: 'uid-1',
        memberUids: ['uid-1'],
        createdAt: now,
        modifiedAt: now,
      );

      expect(model.allergenCategories, isEmpty);
      expect(model.toFirestore()['allergenCategories'], isEmpty);
    });

    test('allergenCategories serializes when set', () {
      final now = DateTime(2026, 2, 27);
      final model = FamilyModel(
        id: 'fam-4',
        name: 'Family',
        createdBy: 'uid-1',
        memberUids: ['uid-1'],
        createdAt: now,
        modifiedAt: now,
        allergenCategories: ['lactose', 'nuts', 'gluten'],
      );

      final map = model.toFirestore();
      expect(map['allergenCategories'], ['lactose', 'nuts', 'gluten']);
    });

    test('toMap/fromMap round-trip preserves all fields', () {
      final now = DateTime(2026, 2, 27, 10, 30);
      final model = FamilyModel(
        id: 'fam-rt',
        name: 'Round Trip Family',
        createdBy: 'uid-1',
        memberUids: ['uid-1', 'uid-2'],
        createdAt: now,
        modifiedAt: now,
        allergenCategories: ['lactose', 'nuts'],
      );

      final map = model.toMap();
      final restored = FamilyModel.fromMap('fam-rt', map);

      expect(restored.id, model.id);
      expect(restored.name, model.name);
      expect(restored.createdBy, model.createdBy);
      expect(restored.memberUids, model.memberUids);
      expect(restored.createdAt, model.createdAt);
      expect(restored.modifiedAt, model.modifiedAt);
      expect(restored.allergenCategories, model.allergenCategories);
    });
  });
}
