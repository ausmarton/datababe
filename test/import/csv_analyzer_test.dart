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

  String bathRow(String start) =>
      'Bath,$start,$start,0:10,,,,\n';

  setUp(() async {
    final db = await newDatabaseFactoryMemory().openDatabase('test.db');
    repo = LocalActivityRepository(db);
  });

  group('CsvAnalyzer.analyze() — classification', () {
    test('returns ImportPreview with correct total candidate count', () async {
      final csv = csvHeader +
          bottleFeedRow('2026-03-01 08:00') +
          breastFeedRow('2026-03-01 10:00') +
          solidRow('2026-03-01 12:00');

      final analyzer = CsvAnalyzer(repo);
      final preview = await analyzer.analyze(csv, childId, familyId);

      expect(preview.totalRows, 3);
      expect(preview.childId, childId);
      expect(preview.familyId, familyId);
    });

    test('classifies rows with no fingerprint match as newActivity', () async {
      final csv = csvHeader + bottleFeedRow('2026-03-01 08:00');

      final analyzer = CsvAnalyzer(repo);
      final preview = await analyzer.analyze(csv, childId, familyId);

      expect(preview.newCount, 1);
      expect(preview.candidates.first.status, CandidateStatus.newActivity);
    });

    test('classifies rows matching existing fingerprints as duplicate',
        () async {
      final csv = csvHeader + bottleFeedRow('2026-03-01 08:00');

      // Import first.
      final importer = CsvImporter(repo);
      await importer.importFromString(csv, childId, familyId);

      // Analyze same CSV.
      final analyzer = CsvAnalyzer(repo);
      final preview = await analyzer.analyze(csv, childId, familyId);

      expect(preview.duplicateCount, 1);
      expect(preview.newCount, 0);
      expect(preview.candidates.first.status, CandidateStatus.duplicate);
    });

    test('wraps parse errors as parseError candidates', () async {
      final csv = '${csvHeader}UnknownType,2026-03-01 08:00,,,,,,,\n';

      final analyzer = CsvAnalyzer(repo);
      final preview = await analyzer.analyze(csv, childId, familyId);

      expect(preview.errorCount, 1);
      expect(preview.candidates.first.status, CandidateStatus.parseError);
      expect(preview.candidates.first.error, isNotNull);
      expect(preview.candidates.first.error!.reason, contains('unknown type'));
    });

    test('empty CSV returns zero candidates, no crash', () async {
      final analyzer = CsvAnalyzer(repo);
      final preview = await analyzer.analyze(csvHeader, childId, familyId);

      expect(preview.totalRows, 0);
      expect(preview.candidates, isEmpty);
    });

    test('all duplicates: all classified as duplicate, zero newActivity',
        () async {
      final csv = csvHeader +
          bottleFeedRow('2026-03-01 08:00') +
          breastFeedRow('2026-03-01 10:00');

      final importer = CsvImporter(repo);
      await importer.importFromString(csv, childId, familyId);

      final analyzer = CsvAnalyzer(repo);
      final preview = await analyzer.analyze(csv, childId, familyId);

      expect(preview.duplicateCount, 2);
      expect(preview.newCount, 0);
    });

    test('mixed CSV: correct counts of new/duplicate/error', () async {
      // Import one row first.
      final csv1 = csvHeader + bottleFeedRow('2026-03-01 08:00');
      final importer = CsvImporter(repo);
      await importer.importFromString(csv1, childId, familyId);

      // Analyze CSV with: 1 duplicate + 1 new + 1 error.
      final csv2 =
          '$csvHeader${bottleFeedRow('2026-03-01 08:00')}' // duplicate
          '${solidRow('2026-03-01 12:00')}' // new
          'BadType,2026-03-01 09:00,,,,,,,\n'; // error

      final analyzer = CsvAnalyzer(repo);
      final preview = await analyzer.analyze(csv2, childId, familyId);

      expect(preview.duplicateCount, 1);
      expect(preview.newCount, 1);
      expect(preview.errorCount, 1);
    });

    test('preserves ActivityModel on new and duplicate candidates', () async {
      final csv = csvHeader + bottleFeedRow('2026-03-01 08:00');

      final analyzer = CsvAnalyzer(repo);
      final preview = await analyzer.analyze(csv, childId, familyId);

      final c = preview.candidates.first;
      expect(c.model, isNotNull);
      expect(c.model!.type, 'feedBottle');
      expect(c.model!.childId, childId);
    });

    test('preserves ParsedActivity on candidates', () async {
      final csv = csvHeader + bottleFeedRow('2026-03-01 08:00');

      final analyzer = CsvAnalyzer(repo);
      final preview = await analyzer.analyze(csv, childId, familyId);

      final c = preview.candidates.first;
      expect(c.parsed, isNotNull);
      expect(c.parsed!.type, ActivityType.feedBottle);
    });

    test(
        'respects includeSoftDeleted=false: soft-deleted excluded from dedup',
        () async {
      final csv = csvHeader + bottleFeedRow('2026-03-01 08:00');

      final importer = CsvImporter(repo);
      await importer.importFromString(csv, childId, familyId);

      // Soft-delete.
      final activities = await repo.findByTimeRange(
        familyId, childId, DateTime(2026, 3, 1), DateTime(2026, 3, 2));
      await repo.softDeleteActivity(familyId, activities.first.id);

      // Analyze with includeSoftDeleted=false (default).
      final analyzer = CsvAnalyzer(repo);
      final preview = await analyzer.analyze(csv, childId, familyId);

      expect(preview.newCount, 1, reason: 'soft-deleted should not be dedup match');
    });

    test(
        'respects includeSoftDeleted=true: soft-deleted included in dedup',
        () async {
      final csv = csvHeader + bottleFeedRow('2026-03-01 08:00');

      final importer = CsvImporter(repo);
      await importer.importFromString(csv, childId, familyId);

      // Soft-delete.
      final activities = await repo.findByTimeRange(
        familyId, childId, DateTime(2026, 3, 1), DateTime(2026, 3, 2));
      await repo.softDeleteActivity(familyId, activities.first.id);

      final analyzer = CsvAnalyzer(repo);
      final preview = await analyzer.analyze(
        csv, childId, familyId, includeSoftDeleted: true);

      expect(preview.duplicateCount, 1);
      expect(preview.newCount, 0);
    });

    test('different children not considered duplicates', () async {
      final csv = csvHeader + bottleFeedRow('2026-03-01 08:00');

      final importer = CsvImporter(repo);
      await importer.importFromString(csv, childId, familyId);

      final analyzer = CsvAnalyzer(repo);
      final preview = await analyzer.analyze(csv, 'child-2', familyId);

      expect(preview.newCount, 1);
      expect(preview.duplicateCount, 0);
    });
  });

  group('ImportPreview computed properties', () {
    test('newCount correct', () async {
      final csv = csvHeader +
          bottleFeedRow('2026-03-01 08:00') +
          solidRow('2026-03-01 10:00');

      final analyzer = CsvAnalyzer(repo);
      final preview = await analyzer.analyze(csv, childId, familyId);

      expect(preview.newCount, 2);
    });

    test('duplicateCount correct', () async {
      final csv = csvHeader + bottleFeedRow('2026-03-01 08:00');

      final importer = CsvImporter(repo);
      await importer.importFromString(csv, childId, familyId);

      final analyzer = CsvAnalyzer(repo);
      final preview = await analyzer.analyze(csv, childId, familyId);

      expect(preview.duplicateCount, 1);
    });

    test('errorCount correct', () async {
      final csv = '${csvHeader}BadType1,2026-03-01 08:00,,,,,,,\n'
          'BadType2,2026-03-01 09:00,,,,,,,\n';

      final analyzer = CsvAnalyzer(repo);
      final preview = await analyzer.analyze(csv, childId, familyId);

      expect(preview.errorCount, 2);
    });

    test('minDate/maxDate computed from all parseable candidates', () async {
      final csv = csvHeader +
          bottleFeedRow('2026-01-15 08:00') +
          solidRow('2026-03-20 12:00') +
          diaperRow('2026-02-10 10:00');

      final analyzer = CsvAnalyzer(repo);
      final preview = await analyzer.analyze(csv, childId, familyId);

      expect(preview.minDate, DateTime(2026, 1, 15, 8, 0));
      expect(preview.maxDate, DateTime(2026, 3, 20, 12, 0));
    });

    test('presentTypes includes all unique types', () async {
      final csv = csvHeader +
          bottleFeedRow('2026-03-01 08:00') +
          solidRow('2026-03-01 10:00') +
          diaperRow('2026-03-01 12:00') +
          bathRow('2026-03-01 14:00');

      final analyzer = CsvAnalyzer(repo);
      final preview = await analyzer.analyze(csv, childId, familyId);

      expect(preview.presentTypes, containsAll([
        ActivityType.feedBottle,
        ActivityType.solids,
        ActivityType.diaper,
        ActivityType.bath,
      ]));
    });
  });

  group('ImportFilter.matches()', () {
    // These tests use analyze to produce real ImportCandidates.
    test('empty filter matches all candidates', () async {
      final csv = csvHeader +
          bottleFeedRow('2026-03-01 08:00') +
          solidRow('2026-03-01 10:00');

      final analyzer = CsvAnalyzer(repo);
      final preview = await analyzer.analyze(csv, childId, familyId);
      const filter = ImportFilter();

      for (final c in preview.candidates) {
        expect(filter.matches(c), isTrue);
      }
    });

    test('dateFrom excludes candidates before that date', () async {
      final csv = csvHeader +
          bottleFeedRow('2026-03-01 08:00') +
          solidRow('2026-03-10 10:00');

      final analyzer = CsvAnalyzer(repo);
      final preview = await analyzer.analyze(csv, childId, familyId);
      final filter = ImportFilter(dateFrom: DateTime(2026, 3, 5));

      final passing =
          preview.candidates.where((c) => filter.matches(c)).toList();
      expect(passing, hasLength(1));
      expect(passing.first.type, ActivityType.solids);
    });

    test('dateTo excludes candidates after that date', () async {
      final csv = csvHeader +
          bottleFeedRow('2026-03-01 08:00') +
          solidRow('2026-03-10 10:00');

      final analyzer = CsvAnalyzer(repo);
      final preview = await analyzer.analyze(csv, childId, familyId);
      final filter =
          ImportFilter(dateTo: DateTime(2026, 3, 5, 23, 59, 59));

      final passing =
          preview.candidates.where((c) => filter.matches(c)).toList();
      expect(passing, hasLength(1));
      expect(passing.first.type, ActivityType.feedBottle);
    });

    test('date range includes candidates within range', () async {
      final csv = csvHeader +
          bottleFeedRow('2026-03-01 08:00') +
          solidRow('2026-03-10 10:00') +
          diaperRow('2026-03-20 12:00');

      final analyzer = CsvAnalyzer(repo);
      final preview = await analyzer.analyze(csv, childId, familyId);
      final filter = ImportFilter(
        dateFrom: DateTime(2026, 3, 5),
        dateTo: DateTime(2026, 3, 15, 23, 59, 59),
      );

      final passing =
          preview.candidates.where((c) => filter.matches(c)).toList();
      expect(passing, hasLength(1));
      expect(passing.first.type, ActivityType.solids);
    });

    test('single excluded type filters correctly', () async {
      final csv = csvHeader +
          bottleFeedRow('2026-03-01 08:00') +
          solidRow('2026-03-01 10:00') +
          diaperRow('2026-03-01 12:00');

      final analyzer = CsvAnalyzer(repo);
      final preview = await analyzer.analyze(csv, childId, familyId);
      final filter = ImportFilter(excludedTypes: {ActivityType.diaper});

      final passing =
          preview.candidates.where((c) => filter.matches(c)).toList();
      expect(passing, hasLength(2));
      expect(passing.map((c) => c.type),
          isNot(contains(ActivityType.diaper)));
    });

    test('multiple excluded types filter correctly', () async {
      final csv = csvHeader +
          bottleFeedRow('2026-03-01 08:00') +
          solidRow('2026-03-01 10:00') +
          diaperRow('2026-03-01 12:00');

      final analyzer = CsvAnalyzer(repo);
      final preview = await analyzer.analyze(csv, childId, familyId);
      final filter = ImportFilter(
          excludedTypes: {ActivityType.diaper, ActivityType.solids});

      final passing =
          preview.candidates.where((c) => filter.matches(c)).toList();
      expect(passing, hasLength(1));
      expect(passing.first.type, ActivityType.feedBottle);
    });

    test('parse error candidates always pass regardless of date/type',
        () async {
      final csv =
          '${csvHeader}BadType,2026-01-01 08:00,,,,,,,\n'
          '${bottleFeedRow('2026-03-01 08:00')}';

      final analyzer = CsvAnalyzer(repo);
      final preview = await analyzer.analyze(csv, childId, familyId);
      final filter = ImportFilter(
        dateFrom: DateTime(2026, 6, 1),
        excludedTypes: ActivityType.values.toSet(),
      );

      final passing =
          preview.candidates.where((c) => filter.matches(c)).toList();
      // Only the error should pass (bottle excluded by type + date).
      expect(passing, hasLength(1));
      expect(passing.first.status, CandidateStatus.parseError);
    });

    test('combined date + type filter', () async {
      final csv = csvHeader +
          bottleFeedRow('2026-03-01 08:00') +
          solidRow('2026-03-10 10:00') +
          diaperRow('2026-03-10 12:00');

      final analyzer = CsvAnalyzer(repo);
      final preview = await analyzer.analyze(csv, childId, familyId);
      final filter = ImportFilter(
        dateFrom: DateTime(2026, 3, 5),
        excludedTypes: {ActivityType.diaper},
      );

      final passing =
          preview.candidates.where((c) => filter.matches(c)).toList();
      expect(passing, hasLength(1));
      expect(passing.first.type, ActivityType.solids);
    });
  });

  group('ImportFilter.copyWith', () {
    test('updates dateFrom only', () {
      const original = ImportFilter();
      final updated =
          original.copyWith(dateFrom: () => DateTime(2026, 1, 1));
      expect(updated.dateFrom, DateTime(2026, 1, 1));
      expect(updated.dateTo, isNull);
      expect(updated.excludedTypes, isEmpty);
    });

    test('updates excludedTypes only', () {
      const original = ImportFilter();
      final updated =
          original.copyWith(excludedTypes: {ActivityType.bath});
      expect(updated.excludedTypes, {ActivityType.bath});
      expect(updated.dateFrom, isNull);
    });

    test('no changes returns equivalent filter', () {
      final original = ImportFilter(
        dateFrom: DateTime(2026, 1, 1),
        dateTo: DateTime(2026, 12, 31),
        excludedTypes: {ActivityType.bath},
      );
      final copied = original.copyWith();
      expect(copied.dateFrom, original.dateFrom);
      expect(copied.dateTo, original.dateTo);
      expect(copied.excludedTypes, original.excludedTypes);
    });
  });
}
