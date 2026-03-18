// Reproduction test for the March 16 invisible activity bug.
//
// Tests the FULL pipeline: Firestore data → fromFirestore converter →
// Sembast storage → repository query → ActivityModel.
//
// The reported issue: activities logged on March 16 don't show up for
// some users. The database has records with inconsistent field population.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import 'package:datababe/local/store_refs.dart';
import 'package:datababe/repositories/local_activity_repository.dart';
import 'package:datababe/sync/firestore_converter.dart';

void main() {
  late Database db;
  late LocalActivityRepository repo;

  setUp(() async {
    db = await newDatabaseFactoryMemory().openDatabase('repro.db');
    repo = LocalActivityRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('March 16 invisible activity reproduction', () {
    // Scenario 1: Activity stored in Sembast with ONLY createdAt
    // (no startTime, no modifiedAt) — exactly what the user described.
    test('raw Sembast record with only createdAt is INVISIBLE in range query',
        () async {
      // This is what the user sees in the database
      await StoreRefs.activities.record('act-broken').put(db, {
        'childId': 'c1',
        'type': 'feedBottle',
        'createdAt': '2026-03-16T10:00:00.000',
        'familyId': 'fam-1',
        // No startTime, no modifiedAt — the actual bug
      });

      // Query for March 16 — same filter as watchActivitiesInRange
      final results = await repo.findByTimeRange(
        'fam-1',
        'c1',
        DateTime(2026, 3, 16),
        DateTime(2026, 3, 17),
      );

      // This WILL be empty because Sembast filter on 'startTime' skips nulls
      expect(results, isEmpty,
          reason: 'Confirms the bug: null startTime is invisible to queries');
    });

    // Scenario 2: Same record goes through fromFirestore converter first
    test(
        'activity with only createdAt in Firestore becomes VISIBLE after fromFirestore',
        () async {
      // Simulate what Firestore returns for a record with only createdAt
      final firestoreData = <String, dynamic>{
        'childId': 'c1',
        'type': 'feedBottle',
        'createdAt': Timestamp.fromDate(DateTime(2026, 3, 16, 10, 0)),
        // No startTime, no modifiedAt — this is the Firestore state
      };

      // Run through the converter (this is what _pullDelta does)
      final localData =
          FirestoreConverter.fromFirestore(firestoreData, 'fam-1');

      // Store in Sembast (this is what _pullDelta does)
      await StoreRefs.activities.record('act-healed').put(db, localData);

      // Verify startTime was filled
      final stored = await StoreRefs.activities.record('act-healed').get(db);
      expect(stored!['startTime'], isNotNull,
          reason: 'fromFirestore should fill missing startTime');
      expect(stored['startTime'], stored['createdAt'],
          reason: 'startTime should equal createdAt, not DateTime.now()');

      // Query for March 16 — this should now find the activity
      final results = await repo.findByTimeRange(
        'fam-1',
        'c1',
        DateTime(2026, 3, 16),
        DateTime(2026, 3, 17),
      );

      expect(results, hasLength(1));
      expect(results.first.id, 'act-healed');
      expect(results.first.startTime.day, 16);
      expect(results.first.startTime.month, 3);
    });

    // Scenario 3: Record with createdAt AND modifiedAt but no startTime
    test('activity with createdAt+modifiedAt but no startTime becomes visible',
        () async {
      final firestoreData = <String, dynamic>{
        'childId': 'c1',
        'type': 'diaper',
        'createdAt': Timestamp.fromDate(DateTime(2026, 3, 16, 14, 30)),
        'modifiedAt': Timestamp.fromDate(DateTime(2026, 3, 16, 14, 30)),
        // No startTime
      };

      final localData =
          FirestoreConverter.fromFirestore(firestoreData, 'fam-1');
      await StoreRefs.activities.record('act-no-start').put(db, localData);

      final results = await repo.findByTimeRange(
        'fam-1',
        'c1',
        DateTime(2026, 3, 16),
        DateTime(2026, 3, 17),
      );

      expect(results, hasLength(1));
      expect(results.first.startTime.day, 16);
    });

    // Scenario 4: Record with no timestamp fields at all
    test('activity with NO timestamps gets filled and is visible', () async {
      final firestoreData = <String, dynamic>{
        'childId': 'c1',
        'type': 'feedBottle',
        // No timestamps at all
      };

      final localData =
          FirestoreConverter.fromFirestore(firestoreData, 'fam-1');
      await StoreRefs.activities.record('act-empty').put(db, localData);

      // Should have all three timestamps filled
      final stored = await StoreRefs.activities.record('act-empty').get(db);
      expect(stored!['startTime'], isNotNull);
      expect(stored['createdAt'], isNotNull);
      expect(stored['modifiedAt'], isNotNull);
      // All should be the same (all derived from the same DateTime.now())
      expect(stored['startTime'], stored['createdAt']);
      expect(stored['modifiedAt'], stored['createdAt']);
    });

    // Scenario 5: Verify the complete normal activity is not broken
    test('activity with all fields intact is visible and unchanged', () async {
      final firestoreData = <String, dynamic>{
        'childId': 'c1',
        'type': 'feedBottle',
        'startTime': Timestamp.fromDate(DateTime(2026, 3, 16, 10, 0)),
        'createdAt': Timestamp.fromDate(DateTime(2026, 3, 16, 9, 55)),
        'modifiedAt': Timestamp.fromDate(DateTime(2026, 3, 16, 10, 0)),
        'volumeMl': 120.0,
      };

      final localData =
          FirestoreConverter.fromFirestore(firestoreData, 'fam-1');
      await StoreRefs.activities.record('act-complete').put(db, localData);

      final results = await repo.findByTimeRange(
        'fam-1',
        'c1',
        DateTime(2026, 3, 16),
        DateTime(2026, 3, 17),
      );

      expect(results, hasLength(1));
      final activity = results.first;
      expect(activity.startTime, DateTime(2026, 3, 16, 10, 0));
      expect(activity.volumeMl, 120.0);
    });

    // Scenario 6: Non-activity record should NOT get startTime
    test('non-activity record does not get startTime from fromFirestore',
        () async {
      final firestoreData = <String, dynamic>{
        'name': 'milk',
        'createdAt': Timestamp.fromDate(DateTime(2026, 3, 16, 10, 0)),
        'modifiedAt': Timestamp.fromDate(DateTime(2026, 3, 16, 10, 0)),
        // No 'type' field — this is an ingredient, not an activity
      };

      final localData =
          FirestoreConverter.fromFirestore(firestoreData, 'fam-1');

      expect(localData.containsKey('startTime'), isFalse,
          reason: 'Non-activity records should not get startTime');
    });

    // Scenario 7: fromFirestore produces LOCAL time strings (no Z suffix)
    test('fromFirestore converts Timestamps to local time (no Z suffix)',
        () async {
      final firestoreData = <String, dynamic>{
        'childId': 'c1',
        'type': 'feedBottle',
        'startTime': Timestamp.fromDate(DateTime(2026, 3, 16, 10, 0)),
        'createdAt': Timestamp.fromDate(DateTime(2026, 3, 16, 10, 0)),
        'modifiedAt': Timestamp.fromDate(DateTime(2026, 3, 16, 10, 0)),
      };

      final localData =
          FirestoreConverter.fromFirestore(firestoreData, 'fam-1');

      // ISO strings should NOT have 'Z' suffix (local time, not UTC)
      final startTime = localData['startTime'] as String;
      expect(startTime.endsWith('Z'), isFalse,
          reason:
              'Stored strings should be local time (no Z) to match query format');

      // Store and query — should work correctly
      await StoreRefs.activities.record('act-local').put(db, localData);

      final results = await repo.findByTimeRange(
        'fam-1',
        'c1',
        DateTime(2026, 3, 16),
        DateTime(2026, 3, 17),
      );

      expect(results, hasLength(1));
    });

    // Scenario 7b: Verify UTC strings with Z suffix DON'T cause issues
    test('UTC string with Z suffix is parseable back to correct DateTime',
        () async {
      // Even if old data has Z suffix, fromMap should still work
      await StoreRefs.activities.record('act-utc').put(db, {
        'childId': 'c1',
        'type': 'feedBottle',
        'startTime': '2026-03-16T10:00:00.000Z',
        'createdAt': '2026-03-16T10:00:00.000Z',
        'modifiedAt': '2026-03-16T10:00:00.000Z',
        'familyId': 'fam-1',
      });

      // Query for March 16 in local time
      final results = await repo.findByTimeRange(
        'fam-1',
        'c1',
        DateTime(2026, 3, 16),
        DateTime(2026, 3, 17),
      );

      // On UTC machines this works (Z sorts after digits).
      // On non-UTC machines near date boundaries, this could fail.
      // The fix ensures new pulls don't produce Z-suffixed strings.
      expect(results, hasLength(1),
          reason: 'UTC strings should still work on UTC test runners');
    });

    // Scenario 8: Multiple activities with mixed field states
    test('mix of complete and broken Firestore records all become visible',
        () async {
      // Complete record
      final complete = <String, dynamic>{
        'childId': 'c1',
        'type': 'feedBottle',
        'startTime': Timestamp.fromDate(DateTime(2026, 3, 16, 8, 0)),
        'createdAt': Timestamp.fromDate(DateTime(2026, 3, 16, 8, 0)),
        'modifiedAt': Timestamp.fromDate(DateTime(2026, 3, 16, 8, 0)),
      };
      // Only createdAt
      final onlyCreated = <String, dynamic>{
        'childId': 'c1',
        'type': 'diaper',
        'createdAt': Timestamp.fromDate(DateTime(2026, 3, 16, 10, 0)),
      };
      // createdAt + modifiedAt, no startTime
      final noStart = <String, dynamic>{
        'childId': 'c1',
        'type': 'feedBottle',
        'createdAt': Timestamp.fromDate(DateTime(2026, 3, 16, 14, 0)),
        'modifiedAt': Timestamp.fromDate(DateTime(2026, 3, 16, 14, 0)),
      };

      // Process all through fromFirestore and store
      for (final (id, data) in [
        ('act-1', complete),
        ('act-2', onlyCreated),
        ('act-3', noStart),
      ]) {
        final local = FirestoreConverter.fromFirestore(data, 'fam-1');
        await StoreRefs.activities.record(id).put(db, local);
      }

      final results = await repo.findByTimeRange(
        'fam-1',
        'c1',
        DateTime(2026, 3, 16),
        DateTime(2026, 3, 17),
      );

      expect(results, hasLength(3),
          reason: 'All 3 activities should be visible on March 16');

      // Verify each has correct date
      for (final a in results) {
        expect(a.startTime.year, 2026);
        expect(a.startTime.month, 3);
        expect(a.startTime.day, 16,
            reason: '${a.id} should appear on March 16');
      }
    });
  });
}
