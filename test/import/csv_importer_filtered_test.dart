import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import 'package:datababe/import/csv_analyzer.dart';
import 'package:datababe/import/csv_importer.dart';
import 'package:datababe/import/import_preview.dart';
import 'package:datababe/models/enums.dart';
import 'package:datababe/repositories/local_activity_repository.dart';

void main() {
  late LocalActivityRepository repo;
  const familyId = 'fam-1';
  const childId = 'child-1';

  const csvHeader =
      'Type,Start,End,Duration,Start Condition,Start Location,End Condition,Notes\n';

  String bottleFeedRow(String start, {String volume = '120ml'}) =>
      'Feed,$start,,,$volume,Bottle,$volume,\n';

  String breastFeedRow(String start) =>
      'Feed,$start,,0:15,0:10R,Breast,0:05L,\n';

  String solidRow(String start, {String food = 'banana'}) =>
      'Solids,$start,,,$food,,Loved,\n';

  String diaperRow(String start) =>
      'Diaper,$start,,yellow,soft,,Poo:medium,\n';

  setUp(() async {
    final db = await newDatabaseFactoryMemory().openDatabase('test.db');
    repo = LocalActivityRepository(db);
  });

  group('CsvImporter.importSelected', () {
    test('all new candidates inserts all, correct count', () async {
      final csv = csvHeader +
          bottleFeedRow('2026-03-01 08:00') +
          solidRow('2026-03-01 10:00');

      final analyzer = CsvAnalyzer(repo);
      final preview = await analyzer.analyze(csv, childId, familyId);
      final newCandidates =
          preview.candidates.where((c) => c.status == CandidateStatus.newActivity).toList();

      final importer = CsvImporter(repo);
      final result = await importer.importSelected(familyId, newCandidates);

      expect(result.imported, 2);
    });

    test('empty list inserts nothing', () async {
      final importer = CsvImporter(repo);
      final result = await importer.importSelected(familyId, []);

      expect(result.imported, 0);
      expect(result.skipped, 0);
    });

    test('subset of candidates inserts only those', () async {
      final csv = csvHeader +
          bottleFeedRow('2026-03-01 08:00') +
          solidRow('2026-03-01 10:00') +
          diaperRow('2026-03-01 12:00');

      final analyzer = CsvAnalyzer(repo);
      final preview = await analyzer.analyze(csv, childId, familyId);
      // Pick only the first candidate.
      final subset = [preview.candidates.first];

      final importer = CsvImporter(repo);
      final result = await importer.importSelected(familyId, subset);

      expect(result.imported, 1);
    });

    test('candidates with duplicate status are ignored', () async {
      final csv = csvHeader + bottleFeedRow('2026-03-01 08:00');

      // Import first.
      final importer = CsvImporter(repo);
      await importer.importFromString(csv, childId, familyId);

      // Analyze — should be all duplicates.
      final analyzer = CsvAnalyzer(repo);
      final preview = await analyzer.analyze(csv, childId, familyId);

      final result =
          await importer.importSelected(familyId, preview.candidates);

      expect(result.imported, 0);
    });

    test('returns correct ImportResult counts', () async {
      final csv = csvHeader +
          bottleFeedRow('2026-03-01 08:00') +
          solidRow('2026-03-01 10:00');

      // Import one first.
      final importer = CsvImporter(repo);
      await importer.importFromString(
          csvHeader + bottleFeedRow('2026-03-01 08:00'), childId, familyId);

      // Analyze the full CSV (1 dup + 1 new).
      final analyzer = CsvAnalyzer(repo);
      final preview = await analyzer.analyze(csv, childId, familyId);

      // Import all candidates (dup should be skipped).
      final result =
          await importer.importSelected(familyId, preview.candidates);

      expect(result.imported, 1);
      expect(result.skipped, 1);
    });

    test('parse error candidates excluded from insert', () async {
      final csv =
          '$csvHeader${bottleFeedRow('2026-03-01 08:00')}'
          'BadType,2026-03-01 09:00,,,,,,,\n';

      final analyzer = CsvAnalyzer(repo);
      final preview = await analyzer.analyze(csv, childId, familyId);

      final importer = CsvImporter(repo);
      final result =
          await importer.importSelected(familyId, preview.candidates);

      expect(result.imported, 1);
    });

    test('inserted activities appear in DB with correct fields', () async {
      final csv = csvHeader + bottleFeedRow('2026-03-01 08:00', volume: '150ml');

      final analyzer = CsvAnalyzer(repo);
      final preview = await analyzer.analyze(csv, childId, familyId);

      final importer = CsvImporter(repo);
      await importer.importSelected(familyId,
          preview.candidates.where((c) => c.status == CandidateStatus.newActivity).toList());

      final activities = await repo.findByTimeRange(
        familyId, childId, DateTime(2026, 3, 1), DateTime(2026, 3, 2));
      expect(activities, hasLength(1));
      expect(activities.first.type, 'feedBottle');
      expect(activities.first.volumeMl, 150.0);
    });
  });

  group('Round-trip: analyze → filter → importSelected', () {
    test('full round-trip: analyze then import all new', () async {
      final csv = csvHeader +
          bottleFeedRow('2026-03-01 08:00') +
          solidRow('2026-03-01 10:00');

      final analyzer = CsvAnalyzer(repo);
      final preview = await analyzer.analyze(csv, childId, familyId);
      expect(preview.newCount, 2);

      final importer = CsvImporter(repo);
      final newCandidates = preview.candidates
          .where((c) => c.status == CandidateStatus.newActivity)
          .toList();
      final result = await importer.importSelected(familyId, newCandidates);
      expect(result.imported, 2);

      // Verify in DB.
      final activities = await repo.findByTimeRange(
        familyId, childId, DateTime(2026, 3, 1), DateTime(2026, 3, 2));
      expect(activities, hasLength(2));
    });

    test('analyze, filter by date range, import subset', () async {
      final csv = csvHeader +
          bottleFeedRow('2026-03-01 08:00') +
          solidRow('2026-03-10 10:00') +
          diaperRow('2026-03-20 12:00');

      final analyzer = CsvAnalyzer(repo);
      final preview = await analyzer.analyze(csv, childId, familyId);

      // Filter to March 5-15.
      final filter = ImportFilter(
        dateFrom: DateTime(2026, 3, 5),
        dateTo: DateTime(2026, 3, 15, 23, 59, 59),
      );

      final filtered = preview.candidates
          .where((c) =>
              c.status == CandidateStatus.newActivity && filter.matches(c))
          .toList();
      expect(filtered, hasLength(1));

      final importer = CsvImporter(repo);
      final result = await importer.importSelected(familyId, filtered);
      expect(result.imported, 1);

      // Only the solids from March 10 should be in DB.
      final activities = await repo.findByTimeRange(
        familyId, childId, DateTime(2026, 1, 1), DateTime(2026, 12, 31));
      expect(activities, hasLength(1));
      expect(activities.first.type, 'solids');
    });

    test('analyze, exclude one type, import', () async {
      final csv = csvHeader +
          bottleFeedRow('2026-03-01 08:00') +
          solidRow('2026-03-01 10:00') +
          diaperRow('2026-03-01 12:00');

      final analyzer = CsvAnalyzer(repo);
      final preview = await analyzer.analyze(csv, childId, familyId);

      final filter = ImportFilter(excludedTypes: {ActivityType.diaper});
      final filtered = preview.candidates
          .where((c) =>
              c.status == CandidateStatus.newActivity && filter.matches(c))
          .toList();

      final importer = CsvImporter(repo);
      final result = await importer.importSelected(familyId, filtered);
      expect(result.imported, 2);

      final activities = await repo.findByTimeRange(
        familyId, childId, DateTime(2026, 3, 1), DateTime(2026, 3, 2));
      expect(activities.any((a) => a.type == 'diaper'), isFalse);
    });

    test('analyze, deselect some rows, import', () async {
      final csv = csvHeader +
          bottleFeedRow('2026-03-01 08:00') +
          solidRow('2026-03-01 10:00') +
          diaperRow('2026-03-01 12:00');

      final analyzer = CsvAnalyzer(repo);
      final preview = await analyzer.analyze(csv, childId, familyId);

      // Simulate deselecting the second candidate (row 2).
      final deselectedRow = preview.candidates[1].rowNumber;
      final selected = preview.candidates
          .where((c) =>
              c.status == CandidateStatus.newActivity &&
              c.rowNumber != deselectedRow)
          .toList();

      final importer = CsvImporter(repo);
      final result = await importer.importSelected(familyId, selected);
      expect(result.imported, 2);

      final activities = await repo.findByTimeRange(
        familyId, childId, DateTime(2026, 3, 1), DateTime(2026, 3, 2));
      expect(activities, hasLength(2));
    });

    test('import half now, re-analyze: previously imported now duplicate',
        () async {
      final csv = csvHeader +
          bottleFeedRow('2026-03-01 08:00') +
          solidRow('2026-03-01 10:00');

      final analyzer = CsvAnalyzer(repo);
      final preview1 = await analyzer.analyze(csv, childId, familyId);
      expect(preview1.newCount, 2);

      // Import only the first.
      final first = [preview1.candidates.first];
      final importer = CsvImporter(repo);
      await importer.importSelected(familyId, first);

      // Re-analyze.
      final preview2 = await analyzer.analyze(csv, childId, familyId);
      expect(preview2.duplicateCount, 1);
      expect(preview2.newCount, 1);
    });

    test('preserves backwards compat: importFromString still works', () async {
      final csv = csvHeader +
          bottleFeedRow('2026-03-01 08:00') +
          solidRow('2026-03-01 10:00');

      final importer = CsvImporter(repo);
      final result =
          await importer.importFromString(csv, childId, familyId);

      expect(result.imported, 2);
      expect(result.skipped, 0);
    });

    test('combined date + type filter round-trip', () async {
      final csv = csvHeader +
          bottleFeedRow('2026-03-01 08:00') +
          solidRow('2026-03-10 10:00') +
          diaperRow('2026-03-10 12:00') +
          breastFeedRow('2026-03-20 10:00');

      final analyzer = CsvAnalyzer(repo);
      final preview = await analyzer.analyze(csv, childId, familyId);

      final filter = ImportFilter(
        dateFrom: DateTime(2026, 3, 5),
        dateTo: DateTime(2026, 3, 15, 23, 59, 59),
        excludedTypes: {ActivityType.diaper},
      );

      final filtered = preview.candidates
          .where((c) =>
              c.status == CandidateStatus.newActivity && filter.matches(c))
          .toList();
      expect(filtered, hasLength(1));
      expect(filtered.first.type, ActivityType.solids);

      final importer = CsvImporter(repo);
      final result = await importer.importSelected(familyId, filtered);
      expect(result.imported, 1);
    });

    test('import with all rows deselected: nothing written', () async {
      final csv = csvHeader +
          bottleFeedRow('2026-03-01 08:00') +
          solidRow('2026-03-01 10:00');

      final analyzer = CsvAnalyzer(repo);
      await analyzer.analyze(csv, childId, familyId);

      // Import empty list (all deselected).
      final importer = CsvImporter(repo);
      final result = await importer.importSelected(familyId, []);
      expect(result.imported, 0);

      final activities = await repo.findByTimeRange(
        familyId, childId, DateTime(2026, 3, 1), DateTime(2026, 3, 2));
      expect(activities, isEmpty);
    });
  });
}
