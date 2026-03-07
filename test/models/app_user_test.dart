import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:datababe/models/app_user.dart';

void main() {
  group('AppUser.toFirestore', () {
    test('includes all fields with correct types', () {
      final now = DateTime(2026, 3, 6, 10, 0);
      final user = AppUser(
        uid: 'uid-1',
        email: 'user@example.com',
        displayName: 'Test User',
        familyIds: ['fam-1', 'fam-2'],
        createdAt: now,
      );

      final map = user.toFirestore();

      expect(map['email'], 'user@example.com');
      expect(map['displayName'], 'Test User');
      expect(map['familyIds'], ['fam-1', 'fam-2']);
      expect(map['createdAt'], isA<Timestamp>());
      expect((map['createdAt'] as Timestamp).toDate(), now);
    });

    test('does not include uid (stored as document ID)', () {
      final user = AppUser(
        uid: 'uid-1',
        email: 'user@example.com',
        displayName: 'Test User',
        familyIds: [],
        createdAt: DateTime(2026, 3, 6),
      );

      final map = user.toFirestore();
      expect(map.containsKey('uid'), isFalse);
    });

    test('handles empty familyIds', () {
      final user = AppUser(
        uid: 'uid-1',
        email: 'user@example.com',
        displayName: 'Test User',
        familyIds: [],
        createdAt: DateTime(2026, 3, 6),
      );

      final map = user.toFirestore();
      expect(map['familyIds'], isEmpty);
    });
  });
}
