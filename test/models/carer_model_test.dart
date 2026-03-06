import 'package:flutter_test/flutter_test.dart';
import 'package:datababe/models/carer_model.dart';

void main() {
  group('CarerModel', () {
    final now = DateTime(2026, 3, 1, 10, 30);

    test('toMap/fromMap round-trip preserves all fields', () {
      final model = CarerModel(
        id: 'carer-rt',
        uid: 'uid-123',
        displayName: 'Jane Doe',
        role: 'parent',
        createdAt: now,
        modifiedAt: now,
      );

      final map = model.toMap();
      final restored = CarerModel.fromMap('carer-rt', map);

      expect(restored.id, model.id);
      expect(restored.uid, model.uid);
      expect(restored.displayName, model.displayName);
      expect(restored.role, model.role);
      expect(restored.createdAt, model.createdAt);
      expect(restored.modifiedAt, model.modifiedAt);
      expect(restored.isDeleted, false);
    });

    test('toMap/fromMap round-trip with isDeleted true', () {
      final model = CarerModel(
        id: 'carer-del',
        uid: 'uid-123',
        displayName: 'Jane Doe',
        role: 'parent',
        createdAt: now,
        modifiedAt: now,
        isDeleted: true,
      );

      final map = model.toMap();
      expect(map['isDeleted'], true);

      final restored = CarerModel.fromMap('carer-del', map);
      expect(restored.isDeleted, true);
    });

    test('fromMap with missing modifiedAt falls back to createdAt', () {
      final map = {
        'uid': 'uid-123',
        'displayName': 'Jane Doe',
        'role': 'parent',
        'createdAt': '2026-03-01T10:30:00.000',
      };

      final restored = CarerModel.fromMap('carer-1', map);
      expect(restored.modifiedAt, restored.createdAt);
      expect(restored.isDeleted, false);
    });

    test('fromMap with isDeleted true preserves it', () {
      final map = {
        'uid': 'uid-123',
        'displayName': 'Jane Doe',
        'role': 'parent',
        'createdAt': '2026-03-01T10:30:00.000',
        'modifiedAt': '2026-03-02T10:30:00.000',
        'isDeleted': true,
      };

      final restored = CarerModel.fromMap('carer-1', map);
      expect(restored.isDeleted, true);
    });

    test('fromMap with missing role defaults to carer', () {
      final map = {
        'uid': 'uid-123',
        'displayName': 'Jane Doe',
        'createdAt': '2026-03-01T10:30:00.000',
      };

      final restored = CarerModel.fromMap('carer-1', map);
      expect(restored.role, 'carer');
    });

    test('toMap includes modifiedAt and isDeleted', () {
      final model = CarerModel(
        id: 'carer-1',
        uid: 'uid-123',
        displayName: 'Jane Doe',
        role: 'parent',
        createdAt: now,
        modifiedAt: now,
      );

      final map = model.toMap();
      expect(map.containsKey('modifiedAt'), isTrue);
      expect(map.containsKey('isDeleted'), isTrue);
      expect(map['isDeleted'], false);
    });

    test('toFirestore includes modifiedAt and isDeleted', () {
      final model = CarerModel(
        id: 'carer-1',
        uid: 'uid-123',
        displayName: 'Jane Doe',
        role: 'parent',
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
