import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import 'package:datababe/local/store_refs.dart';
import 'package:datababe/sync/sync_metadata.dart';
import 'package:datababe/sync/timestamp_heal_migration.dart';

void main() {
  late Database db;

  setUp(() async {
    db = await newDatabaseFactoryMemory().openDatabase('test.db');
  });

  tearDown(() async {
    await db.close();
  });

  group('TimestampHealMigration', () {
    test('resets lastPull timestamps', () async {
      // Set up a lastPull entry
      final metadata = SyncMetadata(db);
      await metadata.setLastPull('fam-1', 'activities', DateTime(2026, 3, 17));
      expect(
          await metadata.getLastPull('fam-1', 'activities'), isNotNull);

      // Run migration
      await TimestampHealMigration(db).run();

      // lastPull should be cleared
      expect(
          await metadata.getLastPull('fam-1', 'activities'), isNull);
    });

    test('fills missing createdAt in activity records', () async {
      await StoreRefs.activities.record('act-1').put(db, {
        'childId': 'c1',
        'type': 'feedBottle',
        'startTime': '2026-03-16T10:00:00.000',
        'modifiedAt': '2026-03-16T10:00:00.000',
        'familyId': 'fam-1',
        // Missing: createdAt
      });

      final healed = await TimestampHealMigration(db).run();

      expect(healed, 1);
      final record = await StoreRefs.activities.record('act-1').get(db);
      expect(record!['createdAt'], isA<String>());
      expect(
          () => DateTime.parse(record['createdAt'] as String), returnsNormally);
    });

    test('fills missing modifiedAt with createdAt value', () async {
      await StoreRefs.activities.record('act-2').put(db, {
        'childId': 'c1',
        'type': 'feedBottle',
        'startTime': '2026-03-16T10:00:00.000',
        'createdAt': '2026-03-16T08:00:00.000',
        'familyId': 'fam-1',
        // Missing: modifiedAt
      });

      await TimestampHealMigration(db).run();

      final record = await StoreRefs.activities.record('act-2').get(db);
      expect(record!['modifiedAt'], '2026-03-16T08:00:00.000');
    });

    test('fills missing startTime for activity records', () async {
      await StoreRefs.activities.record('act-3').put(db, {
        'childId': 'c1',
        'type': 'feedBottle',
        'createdAt': '2026-03-16T10:00:00.000',
        'modifiedAt': '2026-03-16T10:00:00.000',
        'familyId': 'fam-1',
        // Missing: startTime
      });

      await TimestampHealMigration(db).run();

      final record = await StoreRefs.activities.record('act-3').get(db);
      expect(record!['startTime'], isA<String>());
      expect(
          () => DateTime.parse(record['startTime'] as String), returnsNormally);
    });

    test('does not add startTime to non-activity records', () async {
      // Ingredients don't have a startTime field — should not be added
      await StoreRefs.ingredients.record('ing-1').put(db, {
        'name': 'egg',
        'createdAt': '2026-03-16T10:00:00.000',
        'modifiedAt': '2026-03-16T10:00:00.000',
        'familyId': 'fam-1',
      });

      await TimestampHealMigration(db).run();

      final record = await StoreRefs.ingredients.record('ing-1').get(db);
      expect(record!.containsKey('startTime'), isFalse);
    });

    test('does not modify records with all fields present', () async {
      await StoreRefs.activities.record('act-ok').put(db, {
        'childId': 'c1',
        'type': 'feedBottle',
        'startTime': '2026-03-16T10:00:00.000',
        'createdAt': '2026-03-16T09:00:00.000',
        'modifiedAt': '2026-03-16T10:00:00.000',
        'familyId': 'fam-1',
      });

      final healed = await TimestampHealMigration(db).run();

      expect(healed, 0);
      final record = await StoreRefs.activities.record('act-ok').get(db);
      // Original values preserved
      expect(record!['startTime'], '2026-03-16T10:00:00.000');
      expect(record['createdAt'], '2026-03-16T09:00:00.000');
      expect(record['modifiedAt'], '2026-03-16T10:00:00.000');
    });

    test('only runs once (idempotent)', () async {
      await StoreRefs.activities.record('act-once').put(db, {
        'childId': 'c1',
        'type': 'feedBottle',
        'startTime': '2026-03-16T10:00:00.000',
        'familyId': 'fam-1',
        // Missing: createdAt, modifiedAt
      });

      final firstRun = await TimestampHealMigration(db).run();
      expect(firstRun, greaterThan(0));

      // Add another broken record
      await StoreRefs.activities.record('act-later').put(db, {
        'childId': 'c1',
        'type': 'diaper',
        'familyId': 'fam-1',
        // Missing everything
      });

      // Second run should be a no-op
      final secondRun = await TimestampHealMigration(db).run();
      expect(secondRun, 0);
    });

    test('heals records across multiple stores', () async {
      // Broken activity
      await StoreRefs.activities.record('act-x').put(db, {
        'type': 'feedBottle',
        'childId': 'c1',
        'familyId': 'fam-1',
      });
      // Broken ingredient
      await StoreRefs.ingredients.record('ing-x').put(db, {
        'name': 'milk',
        'familyId': 'fam-1',
      });
      // Broken target
      await StoreRefs.targets.record('tgt-x').put(db, {
        'metric': 'count',
        'familyId': 'fam-1',
      });

      final healed = await TimestampHealMigration(db).run();

      expect(healed, 3);

      // Verify all have timestamps now
      final act = await StoreRefs.activities.record('act-x').get(db);
      expect(act!['createdAt'], isA<String>());
      expect(act['modifiedAt'], isA<String>());
      expect(act['startTime'], isA<String>());

      final ing = await StoreRefs.ingredients.record('ing-x').get(db);
      expect(ing!['createdAt'], isA<String>());
      expect(ing['modifiedAt'], isA<String>());

      final tgt = await StoreRefs.targets.record('tgt-x').get(db);
      expect(tgt!['createdAt'], isA<String>());
      expect(tgt['modifiedAt'], isA<String>());
    });
  });
}
