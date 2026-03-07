import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:datababe/sync/firestore_converter.dart';

void main() {
  group('FirestoreConverter.toFirestore', () {
    test('converts ISO 8601 date strings to Timestamps', () {
      final dt = DateTime(2026, 3, 6, 10, 30);
      final localMap = {
        'type': 'feedBottle',
        'startTime': dt.toIso8601String(),
        'createdAt': dt.toIso8601String(),
        'modifiedAt': dt.toIso8601String(),
      };

      final result = FirestoreConverter.toFirestore(localMap);

      expect(result['startTime'], isA<Timestamp>());
      expect((result['startTime'] as Timestamp).toDate(), dt);
      expect(result['createdAt'], isA<Timestamp>());
      expect(result['modifiedAt'], isA<Timestamp>());
    });

    test('removes familyId field', () {
      final localMap = {
        'familyId': 'fam-1',
        'type': 'feedBottle',
      };

      final result = FirestoreConverter.toFirestore(localMap);

      expect(result.containsKey('familyId'), isFalse);
      expect(result['type'], 'feedBottle');
    });

    test('preserves non-date fields', () {
      final localMap = {
        'type': 'diaper',
        'childId': 'child-1',
        'volumeMl': 120.0,
        'isDeleted': false,
        'ingredientNames': ['egg', 'milk'],
      };

      final result = FirestoreConverter.toFirestore(localMap);

      expect(result['type'], 'diaper');
      expect(result['childId'], 'child-1');
      expect(result['volumeMl'], 120.0);
      expect(result['isDeleted'], false);
      expect(result['ingredientNames'], ['egg', 'milk']);
    });

    test('handles null date fields gracefully', () {
      final localMap = {
        'type': 'feedBottle',
        'startTime': DateTime(2026, 3, 6).toIso8601String(),
        'endTime': null,
      };

      final result = FirestoreConverter.toFirestore(localMap);

      expect(result['startTime'], isA<Timestamp>());
      expect(result['endTime'], isNull);
    });

    test('converts all known date fields', () {
      final dt = DateTime(2026, 3, 6);
      final localMap = {
        'startTime': dt.toIso8601String(),
        'endTime': dt.toIso8601String(),
        'createdAt': dt.toIso8601String(),
        'modifiedAt': dt.toIso8601String(),
        'dateOfBirth': dt.toIso8601String(),
      };

      final result = FirestoreConverter.toFirestore(localMap);

      for (final field in [
        'startTime',
        'endTime',
        'createdAt',
        'modifiedAt',
        'dateOfBirth',
      ]) {
        expect(result[field], isA<Timestamp>(), reason: '$field should be Timestamp');
      }
    });

    test('does not mutate original map', () {
      final localMap = {
        'familyId': 'fam-1',
        'startTime': DateTime(2026, 3, 6).toIso8601String(),
      };

      FirestoreConverter.toFirestore(localMap);

      expect(localMap.containsKey('familyId'), isTrue);
      expect(localMap['startTime'], isA<String>());
    });
  });

  group('FirestoreConverter.fromFirestore', () {
    test('converts Timestamps to ISO 8601 strings', () {
      final dt = DateTime(2026, 3, 6, 10, 30);
      final firestoreMap = {
        'type': 'feedBottle',
        'startTime': Timestamp.fromDate(dt),
        'createdAt': Timestamp.fromDate(dt),
        'modifiedAt': Timestamp.fromDate(dt),
      };

      final result = FirestoreConverter.fromFirestore(firestoreMap, 'fam-1');

      expect(result['startTime'], isA<String>());
      expect(DateTime.parse(result['startTime'] as String), dt);
      expect(result['createdAt'], isA<String>());
      expect(result['modifiedAt'], isA<String>());
    });

    test('adds familyId field', () {
      final firestoreMap = {'type': 'feedBottle'};

      final result = FirestoreConverter.fromFirestore(firestoreMap, 'fam-1');

      expect(result['familyId'], 'fam-1');
    });

    test('preserves non-date fields', () {
      final firestoreMap = {
        'type': 'diaper',
        'childId': 'child-1',
        'volumeMl': 120.0,
        'isDeleted': false,
      };

      final result = FirestoreConverter.fromFirestore(firestoreMap, 'fam-1');

      expect(result['type'], 'diaper');
      expect(result['childId'], 'child-1');
      expect(result['volumeMl'], 120.0);
      expect(result['isDeleted'], false);
    });

    test('handles null Timestamp fields', () {
      final firestoreMap = {
        'startTime': Timestamp.fromDate(DateTime(2026, 3, 6)),
        'endTime': null,
      };

      final result = FirestoreConverter.fromFirestore(firestoreMap, 'fam-1');

      expect(result['startTime'], isA<String>());
      expect(result['endTime'], isNull);
    });

    test('round-trip: toFirestore then fromFirestore preserves data', () {
      final dt = DateTime(2026, 3, 6, 10, 30);
      final original = {
        'familyId': 'fam-1',
        'type': 'feedBottle',
        'childId': 'child-1',
        'startTime': dt.toIso8601String(),
        'createdAt': dt.toIso8601String(),
        'modifiedAt': dt.toIso8601String(),
        'volumeMl': 120.0,
      };

      final firestoreData = FirestoreConverter.toFirestore(
          Map<String, dynamic>.from(original));
      final roundTrip =
          FirestoreConverter.fromFirestore(firestoreData, 'fam-1');

      expect(roundTrip['familyId'], 'fam-1');
      expect(roundTrip['type'], 'feedBottle');
      expect(roundTrip['childId'], 'child-1');
      expect(roundTrip['volumeMl'], 120.0);
      expect(DateTime.parse(roundTrip['startTime'] as String), dt);
      expect(DateTime.parse(roundTrip['createdAt'] as String), dt);
      expect(DateTime.parse(roundTrip['modifiedAt'] as String), dt);
    });

    test('does not mutate original map', () {
      final firestoreMap = {
        'startTime': Timestamp.fromDate(DateTime(2026, 3, 6)),
      };

      FirestoreConverter.fromFirestore(firestoreMap, 'fam-1');

      expect(firestoreMap['startTime'], isA<Timestamp>());
      expect(firestoreMap.containsKey('familyId'), isFalse);
    });
  });
}
