import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import 'package:datababe/import/csv_importer.dart';
import 'package:datababe/repositories/local_activity_repository.dart';

void main() {
  late LocalActivityRepository repo;
  const familyId = 'fam-1';
  const childId = 'child-1';

  // Minimal CSV with header + one bottle feed row.
  const csvHeader =
      'Type,Start,End,Duration,Start Condition,Start Location,End Condition,Notes\n';

  String bottleFeedRow(String start, {String volume = '120ml'}) =>
      'Feed,$start,,,$volume,Bottle,$volume,\n';

  String breastFeedRow(String start) =>
      'Feed,$start,,0:15,0:10R,Breast,0:05L,\n';

  String solidRow(String start, {String food = 'banana'}) =>
      'Solids,$start,,,$food,,Loved,\n';

  setUp(() async {
    final db = await newDatabaseFactoryMemory().openDatabase('test.db');
    repo = LocalActivityRepository(db);
  });

  test('first import inserts all rows', () async {
    final csv = csvHeader +
        bottleFeedRow('2026-03-01 08:00') +
        breastFeedRow('2026-03-01 10:00');

    final importer = CsvImporter(repo);
    final result =
        await importer.importFromString(csv, childId, familyId);

    expect(result.imported, 2);
    expect(result.skipped, 0);
  });

  test('second identical import skips all', () async {
    final csv = csvHeader + bottleFeedRow('2026-03-01 08:00');

    final importer = CsvImporter(repo);
    await importer.importFromString(csv, childId, familyId);
    final result =
        await importer.importFromString(csv, childId, familyId);

    expect(result.imported, 0);
    expect(result.skipped, 1);
  });

  test('partial overlap: only new rows imported', () async {
    final csv1 = csvHeader + bottleFeedRow('2026-03-01 08:00');
    final csv2 = csvHeader +
        bottleFeedRow('2026-03-01 08:00') +
        breastFeedRow('2026-03-01 10:00');

    final importer = CsvImporter(repo);
    await importer.importFromString(csv1, childId, familyId);
    final result =
        await importer.importFromString(csv2, childId, familyId);

    expect(result.imported, 1);
    expect(result.skipped, 1);
  });

  test('soft-deleted records re-imported by default', () async {
    final csv = csvHeader + bottleFeedRow('2026-03-01 08:00');

    final importer = CsvImporter(repo);
    await importer.importFromString(csv, childId, familyId);

    // Soft-delete the activity.
    final activities = await repo.findByTimeRange(
      familyId,
      childId,
      DateTime(2026, 3, 1),
      DateTime(2026, 3, 2),
    );
    expect(activities, hasLength(1));
    await repo.softDeleteActivity(familyId, activities.first.id);

    // Re-import — default excludes soft-deleted from dedup, so re-import succeeds.
    final result =
        await importer.importFromString(csv, childId, familyId);
    expect(result.imported, 1);
    expect(result.skipped, 0);
  });

  test('different children not considered duplicates', () async {
    final csv = csvHeader + bottleFeedRow('2026-03-01 08:00');

    final importer = CsvImporter(repo);
    await importer.importFromString(csv, childId, familyId);
    final result =
        await importer.importFromString(csv, 'child-2', familyId);

    expect(result.imported, 1);
    expect(result.skipped, 0);
  });

  test('same time different type: not a duplicate', () async {
    final csv1 = csvHeader + bottleFeedRow('2026-03-01 08:00');
    final csv2 = csvHeader + solidRow('2026-03-01 08:00');

    final importer = CsvImporter(repo);
    await importer.importFromString(csv1, childId, familyId);
    final result =
        await importer.importFromString(csv2, childId, familyId);

    expect(result.imported, 1);
    expect(result.skipped, 0);
  });

  test('same type and time different values: not a duplicate', () async {
    final csv1 = csvHeader + bottleFeedRow('2026-03-01 08:00', volume: '120ml');
    final csv2 = csvHeader + bottleFeedRow('2026-03-01 08:00', volume: '150ml');

    final importer = CsvImporter(repo);
    await importer.importFromString(csv1, childId, familyId);
    final result =
        await importer.importFromString(csv2, childId, familyId);

    expect(result.imported, 1);
    expect(result.skipped, 0);
  });

  test('empty CSV returns zero counts', () async {
    final importer = CsvImporter(repo);
    final result =
        await importer.importFromString(csvHeader, childId, familyId);

    expect(result.imported, 0);
    expect(result.skipped, 0);
  });

  group('solids reaction fingerprint', () {
    test('same time, same food, different reaction → NOT deduped', () async {
      const row1 = 'Solids,2026-03-01 08:00,,,banana,,Loved,\n';
      const row2 = 'Solids,2026-03-01 08:00,,,banana,,Disliked,\n';

      final importer = CsvImporter(repo);
      await importer.importFromString(csvHeader + row1, childId, familyId);
      final result =
          await importer.importFromString(csvHeader + row2, childId, familyId);

      expect(result.imported, 1);
      expect(result.skipped, 0);
    });

    test('same time, no food, different reaction → NOT deduped', () async {
      const row1 = 'Solids,2026-03-01 08:00,,,,,Loved,\n';
      const row2 = 'Solids,2026-03-01 08:00,,,,,Meh,\n';

      final importer = CsvImporter(repo);
      await importer.importFromString(csvHeader + row1, childId, familyId);
      final result =
          await importer.importFromString(csvHeader + row2, childId, familyId);

      expect(result.imported, 1);
      expect(result.skipped, 0);
    });

    test('same time, same food, same reaction → deduped', () async {
      const row = 'Solids,2026-03-01 08:00,,,banana,,Loved,\n';

      final importer = CsvImporter(repo);
      await importer.importFromString(csvHeader + row, childId, familyId);
      final result =
          await importer.importFromString(csvHeader + row, childId, familyId);

      expect(result.imported, 0);
      expect(result.skipped, 1);
    });
  });

  group('fingerprint dedup per activity type', () {
    // Each type uses different distinguishing fields in its fingerprint.

    test('diaper: same contents deduped, different contents not', () async {
      const row1 =
          'Diaper,2026-03-01 08:00,,yellow,soft,,Poo:medium,\n';
      const row2 =
          'Diaper,2026-03-01 08:00,,yellow,soft,,Pee:large,\n';

      final importer = CsvImporter(repo);
      await importer.importFromString(csvHeader + row1, childId, familyId);

      // Same row again → skip
      var result =
          await importer.importFromString(csvHeader + row1, childId, familyId);
      expect(result.skipped, 1);

      // Different contents → import
      result =
          await importer.importFromString(csvHeader + row2, childId, familyId);
      expect(result.imported, 1);
    });

    test('meds: same med deduped, different dose not', () async {
      const row1 = 'Meds,2026-03-01 08:00,,,5ml,Paracetamol,,\n';
      const row2 = 'Meds,2026-03-01 08:00,,,10ml,Paracetamol,,\n';

      final importer = CsvImporter(repo);
      await importer.importFromString(csvHeader + row1, childId, familyId);

      var result =
          await importer.importFromString(csvHeader + row1, childId, familyId);
      expect(result.skipped, 1);

      result =
          await importer.importFromString(csvHeader + row2, childId, familyId);
      expect(result.imported, 1);
    });

    test('growth: same measurements deduped, different not', () async {
      const row1 = 'Growth,2026-03-01 08:00,,,4.5kg,55cm,37cm,\n';
      const row2 = 'Growth,2026-03-01 08:00,,,5.0kg,55cm,37cm,\n';

      final importer = CsvImporter(repo);
      await importer.importFromString(csvHeader + row1, childId, familyId);

      var result =
          await importer.importFromString(csvHeader + row1, childId, familyId);
      expect(result.skipped, 1);

      result =
          await importer.importFromString(csvHeader + row2, childId, familyId);
      expect(result.imported, 1);
    });

    test('pump: same volume deduped, different not', () async {
      const row1 = 'Pump,2026-03-01 08:00,2026-03-01 08:20,0:20,80ml,,,\n';
      const row2 = 'Pump,2026-03-01 08:00,2026-03-01 08:20,0:20,100ml,,,\n';

      final importer = CsvImporter(repo);
      await importer.importFromString(csvHeader + row1, childId, familyId);

      var result =
          await importer.importFromString(csvHeader + row1, childId, familyId);
      expect(result.skipped, 1);

      result =
          await importer.importFromString(csvHeader + row2, childId, familyId);
      expect(result.imported, 1);
    });

    test('temperature: same temp deduped, different not', () async {
      const row1 = 'Temp,2026-03-01 08:00,,,36.5°C,,,\n';
      const row2 = 'Temp,2026-03-01 08:00,,,37.2°C,,,\n';

      final importer = CsvImporter(repo);
      await importer.importFromString(csvHeader + row1, childId, familyId);

      var result =
          await importer.importFromString(csvHeader + row1, childId, familyId);
      expect(result.skipped, 1);

      result =
          await importer.importFromString(csvHeader + row2, childId, familyId);
      expect(result.imported, 1);
    });

    test('tummy time: same duration deduped', () async {
      const row =
          'Tummy time,2026-03-01 08:00,2026-03-01 08:15,0:15,,,,\n';

      final importer = CsvImporter(repo);
      await importer.importFromString(csvHeader + row, childId, familyId);

      final result =
          await importer.importFromString(csvHeader + row, childId, familyId);
      expect(result.skipped, 1);
    });

    test('potty: same contents deduped', () async {
      const row = 'Potty,2026-03-01 08:00,,,,,,\n';

      final importer = CsvImporter(repo);
      await importer.importFromString(csvHeader + row, childId, familyId);

      final result =
          await importer.importFromString(csvHeader + row, childId, familyId);
      expect(result.skipped, 1);
    });

    test('bath: same duration deduped', () async {
      const row =
          'Bath,2026-03-01 08:00,2026-03-01 08:10,0:10,,,,\n';

      final importer = CsvImporter(repo);
      await importer.importFromString(csvHeader + row, childId, familyId);

      final result =
          await importer.importFromString(csvHeader + row, childId, familyId);
      expect(result.skipped, 1);
    });

    test('breast feed: same side durations deduped', () async {
      final csv = csvHeader + breastFeedRow('2026-03-01 08:00');

      final importer = CsvImporter(repo);
      await importer.importFromString(csv, childId, familyId);

      final result =
          await importer.importFromString(csv, childId, familyId);
      expect(result.skipped, 1);
    });
  });

  group('ImportResult details', () {
    test('parseErrors passed through in ImportResult', () async {
      // Include an unknown type row alongside a valid row.
      final csv = '${csvHeader}Feed,2026-03-01 08:00,,,120ml,Bottle,120ml,\n'
          'UnknownType,2026-03-01 09:00,,,,,,,\n';

      final importer = CsvImporter(repo);
      final result =
          await importer.importFromString(csv, childId, familyId);

      expect(result.imported, 1);
      expect(result.parseErrors, hasLength(1));
      expect(result.parseErrors.first.reason, contains('unknown type'));
    });

    test('skippedRows contains CSV lines of duplicates', () async {
      final csv = csvHeader + bottleFeedRow('2026-03-01 08:00');

      final importer = CsvImporter(repo);
      await importer.importFromString(csv, childId, familyId);

      final result =
          await importer.importFromString(csv, childId, familyId);

      expect(result.skipped, 1);
      expect(result.skippedRows, hasLength(1));
      expect(result.skippedRows.first, contains('Feed'));
      expect(result.skippedRows.first, contains('2026-03-01 08:00'));
    });
  });

  group('soft-delete dedup toggle', () {
    test('soft-deleted records excluded from dedup by default', () async {
      final csv = csvHeader + bottleFeedRow('2026-03-01 08:00');

      final importer = CsvImporter(repo);
      await importer.importFromString(csv, childId, familyId);

      // Soft-delete the activity.
      final activities = await repo.findByTimeRange(
        familyId,
        childId,
        DateTime(2026, 3, 1),
        DateTime(2026, 3, 2),
      );
      await repo.softDeleteActivity(familyId, activities.first.id);

      // Re-import — default excludes soft-deleted from dedup, so re-import succeeds.
      final result =
          await importer.importFromString(csv, childId, familyId);
      expect(result.imported, 1);
      expect(result.skipped, 0);
    });

    test('soft-deleted records included in dedup when includeSoftDeleted=true',
        () async {
      final csv = csvHeader + bottleFeedRow('2026-03-01 08:00');

      final importer = CsvImporter(repo);
      await importer.importFromString(csv, childId, familyId);

      // Soft-delete the activity.
      final activities = await repo.findByTimeRange(
        familyId,
        childId,
        DateTime(2026, 3, 1),
        DateTime(2026, 3, 2),
      );
      await repo.softDeleteActivity(familyId, activities.first.id);

      // Re-import with includeSoftDeleted=true — should skip.
      final result = await importer.importFromString(
        csv,
        childId,
        familyId,
        includeSoftDeleted: true,
      );
      expect(result.imported, 0);
      expect(result.skipped, 1);
    });

    test('includeSoftDeleted=false is the default', () async {
      final csv = csvHeader + bottleFeedRow('2026-03-01 08:00');

      final importer = CsvImporter(repo);
      await importer.importFromString(csv, childId, familyId);

      // Soft-delete.
      final activities = await repo.findByTimeRange(
        familyId,
        childId,
        DateTime(2026, 3, 1),
        DateTime(2026, 3, 2),
      );
      await repo.softDeleteActivity(familyId, activities.first.id);

      // Default call (no parameter) should behave like includeSoftDeleted=false.
      final result =
          await importer.importFromString(csv, childId, familyId);
      expect(result.imported, 1, reason: 'default should allow re-import of soft-deleted');
    });
  });
}
