import 'package:flutter_test/flutter_test.dart';
import 'package:datababe/models/child_model.dart';

void main() {
  group('ChildModel', () {
    final now = DateTime(2026, 3, 1, 10, 30);
    final dob = DateTime(2025, 6, 15);

    test('toMap/fromMap round-trip preserves all fields', () {
      final model = ChildModel(
        id: 'child-rt',
        name: 'Test Baby',
        dateOfBirth: dob,
        notes: 'born at home',
        createdAt: now,
        modifiedAt: now,
      );

      final map = model.toMap();
      final restored = ChildModel.fromMap('child-rt', map);

      expect(restored.id, model.id);
      expect(restored.name, model.name);
      expect(restored.dateOfBirth, model.dateOfBirth);
      expect(restored.notes, model.notes);
      expect(restored.createdAt, model.createdAt);
      expect(restored.modifiedAt, model.modifiedAt);
      expect(restored.isDeleted, false);
    });

    test('toMap/fromMap round-trip with isDeleted true', () {
      final model = ChildModel(
        id: 'child-del',
        name: 'Deleted Baby',
        dateOfBirth: dob,
        createdAt: now,
        modifiedAt: now,
        isDeleted: true,
      );

      final map = model.toMap();
      expect(map['isDeleted'], true);

      final restored = ChildModel.fromMap('child-del', map);
      expect(restored.isDeleted, true);
      expect(restored.modifiedAt, now);
    });

    test('fromMap with missing modifiedAt falls back to createdAt', () {
      final map = {
        'name': 'Baby',
        'dateOfBirth': '2025-06-15T00:00:00.000',
        'notes': '',
        'createdAt': '2026-03-01T10:30:00.000',
      };

      final restored = ChildModel.fromMap('child-1', map);
      expect(restored.modifiedAt, restored.createdAt);
      expect(restored.isDeleted, false);
    });

    test('fromMap with isDeleted true preserves it', () {
      final map = {
        'name': 'Baby',
        'dateOfBirth': '2025-06-15T00:00:00.000',
        'notes': '',
        'createdAt': '2026-03-01T10:30:00.000',
        'modifiedAt': '2026-03-02T10:30:00.000',
        'isDeleted': true,
      };

      final restored = ChildModel.fromMap('child-1', map);
      expect(restored.isDeleted, true);
    });

    test('toMap includes modifiedAt and isDeleted', () {
      final model = ChildModel(
        id: 'child-1',
        name: 'Baby',
        dateOfBirth: dob,
        createdAt: now,
        modifiedAt: now,
      );

      final map = model.toMap();
      expect(map.containsKey('modifiedAt'), isTrue);
      expect(map.containsKey('isDeleted'), isTrue);
      expect(map['isDeleted'], false);
    });

    test('toFirestore includes modifiedAt and isDeleted', () {
      final model = ChildModel(
        id: 'child-1',
        name: 'Baby',
        dateOfBirth: dob,
        createdAt: now,
        modifiedAt: now,
        isDeleted: true,
      );

      final map = model.toFirestore();
      expect(map.containsKey('modifiedAt'), isTrue);
      expect(map['isDeleted'], true);
      expect(map.containsKey('id'), isFalse);
    });
  });
}
