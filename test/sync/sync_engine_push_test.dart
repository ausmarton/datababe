import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:datababe/sync/sync_engine.dart';

void main() {
  group('SyncEngine.shouldPush', () {
    test('null remote data → should push', () {
      final local = {'modifiedAt': Timestamp.fromDate(DateTime(2026, 3, 6))};
      expect(SyncEngine.shouldPush(null, local), isTrue);
    });

    test('remote has no modifiedAt → should push', () {
      final remote = {'name': 'Test'};
      final local = {'modifiedAt': Timestamp.fromDate(DateTime(2026, 3, 6))};
      expect(SyncEngine.shouldPush(remote, local), isTrue);
    });

    test('remote modifiedAt is not Timestamp → should push', () {
      final remote = {'modifiedAt': '2026-03-06T00:00:00.000'};
      final local = {'modifiedAt': Timestamp.fromDate(DateTime(2026, 3, 6))};
      expect(SyncEngine.shouldPush(remote, local), isTrue);
    });

    test('local has no modifiedAt → should push (treat as must-push)', () {
      final remote = {'modifiedAt': Timestamp.fromDate(DateTime(2026, 3, 6))};
      final local = <String, dynamic>{'name': 'Test'};
      expect(SyncEngine.shouldPush(remote, local), isTrue);
    });

    test('local modifiedAt is not Timestamp → should push', () {
      final remote = {'modifiedAt': Timestamp.fromDate(DateTime(2026, 3, 6))};
      final local = {'modifiedAt': '2026-03-06T00:00:00.000'};
      expect(SyncEngine.shouldPush(remote, local), isTrue);
    });

    test('local newer than remote → should push', () {
      final remote = {
        'modifiedAt': Timestamp.fromDate(DateTime(2026, 3, 6, 10, 0)),
      };
      final local = {
        'modifiedAt': Timestamp.fromDate(DateTime(2026, 3, 6, 12, 0)),
      };
      expect(SyncEngine.shouldPush(remote, local), isTrue);
    });

    test('remote newer than local → should NOT push', () {
      final remote = {
        'modifiedAt': Timestamp.fromDate(DateTime(2026, 3, 6, 12, 0)),
      };
      final local = {
        'modifiedAt': Timestamp.fromDate(DateTime(2026, 3, 6, 10, 0)),
      };
      expect(SyncEngine.shouldPush(remote, local), isFalse);
    });

    test('equal timestamps → should NOT push', () {
      final ts = Timestamp.fromDate(DateTime(2026, 3, 6, 10, 0));
      final remote = {'modifiedAt': ts};
      final local = {'modifiedAt': ts};
      expect(SyncEngine.shouldPush(remote, local), isFalse);
    });

    test('sub-second precision: local 1ms newer → should push', () {
      final remote = {
        'modifiedAt':
            Timestamp.fromDate(DateTime(2026, 3, 6, 10, 0, 0, 0)),
      };
      final local = {
        'modifiedAt':
            Timestamp.fromDate(DateTime(2026, 3, 6, 10, 0, 0, 1)),
      };
      expect(SyncEngine.shouldPush(remote, local), isTrue);
    });

    test('sub-second precision: remote 1ms newer → should NOT push', () {
      final remote = {
        'modifiedAt':
            Timestamp.fromDate(DateTime(2026, 3, 6, 10, 0, 0, 1)),
      };
      final local = {
        'modifiedAt':
            Timestamp.fromDate(DateTime(2026, 3, 6, 10, 0, 0, 0)),
      };
      expect(SyncEngine.shouldPush(remote, local), isFalse);
    });
  });
}
