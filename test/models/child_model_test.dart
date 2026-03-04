import 'package:flutter_test/flutter_test.dart';
import 'package:datababe/models/child_model.dart';

void main() {
  group('ChildModel', () {
    test('toMap/fromMap round-trip preserves all fields', () {
      final now = DateTime(2026, 3, 1, 10, 30);
      final dob = DateTime(2025, 6, 15);

      final model = ChildModel(
        id: 'child-rt',
        name: 'Test Baby',
        dateOfBirth: dob,
        notes: 'born at home',
        createdAt: now,
      );

      final map = model.toMap();
      final restored = ChildModel.fromMap('child-rt', map);

      expect(restored.id, model.id);
      expect(restored.name, model.name);
      expect(restored.dateOfBirth, model.dateOfBirth);
      expect(restored.notes, model.notes);
      expect(restored.createdAt, model.createdAt);
    });
  });
}
