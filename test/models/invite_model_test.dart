import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:datababe/models/enums.dart';
import 'package:datababe/models/invite_model.dart';

void main() {
  group('InviteModel.computeId', () {
    test('combines familyId and email', () {
      expect(
        InviteModel.computeId('fam-1', 'user@example.com'),
        'fam-1_user@example.com',
      );
    });

    test('lowercases email', () {
      expect(
        InviteModel.computeId('fam-1', 'User@Example.COM'),
        'fam-1_user@example.com',
      );
    });

    test('same inputs produce same ID', () {
      final id1 = InviteModel.computeId('fam-1', 'test@test.com');
      final id2 = InviteModel.computeId('fam-1', 'test@test.com');
      expect(id1, id2);
    });

    test('different family produces different ID', () {
      final id1 = InviteModel.computeId('fam-1', 'test@test.com');
      final id2 = InviteModel.computeId('fam-2', 'test@test.com');
      expect(id1, isNot(id2));
    });

    test('different email produces different ID', () {
      final id1 = InviteModel.computeId('fam-1', 'a@test.com');
      final id2 = InviteModel.computeId('fam-1', 'b@test.com');
      expect(id1, isNot(id2));
    });
  });

  group('InviteModel.toFirestore', () {
    test('includes all fields with correct types', () {
      final now = DateTime(2026, 3, 6, 10, 0);
      final model = InviteModel(
        id: 'fam-1_user@example.com',
        familyId: 'fam-1',
        familyName: 'Test Family',
        invitedByUid: 'uid-1',
        invitedByName: 'Parent',
        inviteeEmail: 'user@example.com',
        role: 'carer',
        status: InviteStatus.pending,
        createdAt: now,
      );

      final map = model.toFirestore();

      expect(map['familyId'], 'fam-1');
      expect(map['familyName'], 'Test Family');
      expect(map['invitedByUid'], 'uid-1');
      expect(map['invitedByName'], 'Parent');
      expect(map['inviteeEmail'], 'user@example.com');
      expect(map['role'], 'carer');
      expect(map['status'], 'pending');
      expect(map['createdAt'], isA<Timestamp>());
      expect((map['createdAt'] as Timestamp).toDate(), now);
    });

    test('excludes respondedAt when null', () {
      final model = InviteModel(
        id: 'id',
        familyId: 'fam-1',
        familyName: 'Family',
        invitedByUid: 'uid-1',
        invitedByName: 'Parent',
        inviteeEmail: 'test@test.com',
        role: 'carer',
        status: InviteStatus.pending,
        createdAt: DateTime(2026, 3, 6),
      );

      final map = model.toFirestore();
      expect(map.containsKey('respondedAt'), isFalse);
    });

    test('includes respondedAt when set', () {
      final now = DateTime(2026, 3, 6, 10, 0);
      final responded = DateTime(2026, 3, 6, 12, 0);
      final model = InviteModel(
        id: 'id',
        familyId: 'fam-1',
        familyName: 'Family',
        invitedByUid: 'uid-1',
        invitedByName: 'Parent',
        inviteeEmail: 'test@test.com',
        role: 'carer',
        status: InviteStatus.accepted,
        createdAt: now,
        respondedAt: responded,
      );

      final map = model.toFirestore();
      expect(map.containsKey('respondedAt'), isTrue);
      expect((map['respondedAt'] as Timestamp).toDate(), responded);
    });

    test('serializes all InviteStatus values', () {
      for (final status in InviteStatus.values) {
        final model = InviteModel(
          id: 'id',
          familyId: 'fam-1',
          familyName: 'Family',
          invitedByUid: 'uid-1',
          invitedByName: 'Parent',
          inviteeEmail: 'test@test.com',
          role: 'carer',
          status: status,
          createdAt: DateTime(2026, 3, 6),
        );

        final map = model.toFirestore();
        expect(map['status'], status.name);
      }
    });
  });
}
