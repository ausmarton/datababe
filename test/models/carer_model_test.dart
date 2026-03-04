import 'package:flutter_test/flutter_test.dart';
import 'package:datababe/models/carer_model.dart';

void main() {
  group('CarerModel', () {
    test('toMap/fromMap round-trip preserves all fields', () {
      final now = DateTime(2026, 3, 1, 10, 30);

      final model = CarerModel(
        id: 'carer-rt',
        uid: 'uid-123',
        displayName: 'Jane Doe',
        role: 'parent',
        createdAt: now,
      );

      final map = model.toMap();
      final restored = CarerModel.fromMap('carer-rt', map);

      expect(restored.id, model.id);
      expect(restored.uid, model.uid);
      expect(restored.displayName, model.displayName);
      expect(restored.role, model.role);
      expect(restored.createdAt, model.createdAt);
    });
  });
}
