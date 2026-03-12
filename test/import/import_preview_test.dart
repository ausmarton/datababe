import 'package:flutter_test/flutter_test.dart';
import 'package:datababe/import/import_preview.dart';
import 'package:datababe/import/csv_parser.dart';
import 'package:datababe/models/activity_model.dart';
import 'package:datababe/models/enums.dart';

void main() {
  final now = DateTime(2026, 3, 10, 10, 0);

  ActivityModel makeModel(ActivityType type, DateTime time) => ActivityModel(
        id: 'id-${time.millisecondsSinceEpoch}',
        childId: 'child1',
        type: type.name,
        startTime: time,
        createdAt: now,
        modifiedAt: now,
      );

  ImportCandidate newCandidate(ActivityType type, DateTime time,
          {int rowNumber = 1}) =>
      ImportCandidate(
        rowNumber: rowNumber,
        status: CandidateStatus.newActivity,
        model: makeModel(type, time),
        type: type,
        startTime: time,
      );

  ImportCandidate dupCandidate(ActivityType type, DateTime time,
          {int rowNumber = 1}) =>
      ImportCandidate(
        rowNumber: rowNumber,
        status: CandidateStatus.duplicate,
        model: makeModel(type, time),
        type: type,
        startTime: time,
      );

  ImportCandidate errorCandidate({int rowNumber = 1}) => ImportCandidate(
        rowNumber: rowNumber,
        status: CandidateStatus.parseError,
        error: ParseError(
          rowNumber: rowNumber,
          rawType: 'Bad',
          reason: 'unknown type',
        ),
      );

  group('ImportCandidate construction', () {
    test('creates newActivity candidate with all fields', () {
      final c = newCandidate(ActivityType.feedBottle, now);
      expect(c.status, CandidateStatus.newActivity);
      expect(c.type, ActivityType.feedBottle);
      expect(c.startTime, now);
      expect(c.model, isNotNull);
      expect(c.error, isNull);
    });

    test('creates duplicate candidate', () {
      final c = dupCandidate(ActivityType.diaper, now);
      expect(c.status, CandidateStatus.duplicate);
      expect(c.model, isNotNull);
    });

    test('creates parseError candidate', () {
      final c = errorCandidate(rowNumber: 5);
      expect(c.status, CandidateStatus.parseError);
      expect(c.type, isNull);
      expect(c.startTime, isNull);
      expect(c.model, isNull);
      expect(c.error, isNotNull);
      expect(c.error!.rowNumber, 5);
    });
  });

  group('ImportPreview', () {
    test('empty candidates list', () {
      final preview = ImportPreview(
        candidates: [],
        childId: 'c1',
        familyId: 'f1',
      );
      expect(preview.totalRows, 0);
      expect(preview.newCount, 0);
      expect(preview.duplicateCount, 0);
      expect(preview.errorCount, 0);
      expect(preview.minDate, isNull);
      expect(preview.maxDate, isNull);
      expect(preview.presentTypes, isEmpty);
    });

    test('summary getters with mixed statuses', () {
      final preview = ImportPreview(
        candidates: [
          newCandidate(ActivityType.feedBottle, now, rowNumber: 1),
          newCandidate(ActivityType.diaper, now, rowNumber: 2),
          dupCandidate(ActivityType.feedBottle, now, rowNumber: 3),
          errorCandidate(rowNumber: 4),
        ],
        childId: 'c1',
        familyId: 'f1',
      );
      expect(preview.totalRows, 4);
      expect(preview.newCount, 2);
      expect(preview.duplicateCount, 1);
      expect(preview.errorCount, 1);
    });

    test('presentTypes excludes error candidates', () {
      final preview = ImportPreview(
        candidates: [
          newCandidate(ActivityType.feedBottle, now, rowNumber: 1),
          dupCandidate(ActivityType.diaper, now, rowNumber: 2),
          errorCandidate(rowNumber: 3),
        ],
        childId: 'c1',
        familyId: 'f1',
      );
      expect(preview.presentTypes,
          {ActivityType.feedBottle, ActivityType.diaper});
    });

    test('minDate/maxDate with single candidate', () {
      final time = DateTime(2026, 1, 15, 8, 30);
      final preview = ImportPreview(
        candidates: [newCandidate(ActivityType.bath, time)],
        childId: 'c1',
        familyId: 'f1',
      );
      expect(preview.minDate, time);
      expect(preview.maxDate, time);
    });

    test('minDate/maxDate returns null for all-error preview', () {
      final preview = ImportPreview(
        candidates: [errorCandidate(rowNumber: 1), errorCandidate(rowNumber: 2)],
        childId: 'c1',
        familyId: 'f1',
      );
      expect(preview.minDate, isNull);
      expect(preview.maxDate, isNull);
    });

    test('minDate/maxDate spans multiple candidates', () {
      final early = DateTime(2026, 1, 1);
      final late = DateTime(2026, 3, 31);
      final preview = ImportPreview(
        candidates: [
          newCandidate(ActivityType.bath, early, rowNumber: 1),
          newCandidate(ActivityType.bath, late, rowNumber: 2),
          dupCandidate(ActivityType.meds, DateTime(2026, 2, 15), rowNumber: 3),
        ],
        childId: 'c1',
        familyId: 'f1',
      );
      expect(preview.minDate, early);
      expect(preview.maxDate, late);
    });
  });

  group('ImportFilter', () {
    test('default constructor has no restrictions', () {
      const filter = ImportFilter();
      expect(filter.dateFrom, isNull);
      expect(filter.dateTo, isNull);
      expect(filter.excludedTypes, isEmpty);
    });

    test('empty filter matches all candidates', () {
      const filter = ImportFilter();
      expect(
          filter.matches(newCandidate(ActivityType.feedBottle, now)), isTrue);
      expect(
          filter.matches(dupCandidate(ActivityType.diaper, now)), isTrue);
      expect(filter.matches(errorCandidate()), isTrue);
    });

    test('dateFrom excludes candidates before that date', () {
      final filter = ImportFilter(dateFrom: DateTime(2026, 3, 10));
      final before = newCandidate(
          ActivityType.bath, DateTime(2026, 3, 9, 23, 59));
      final on = newCandidate(
          ActivityType.bath, DateTime(2026, 3, 10, 0, 0));
      final after = newCandidate(
          ActivityType.bath, DateTime(2026, 3, 10, 0, 1));
      expect(filter.matches(before), isFalse);
      expect(filter.matches(on), isTrue);
      expect(filter.matches(after), isTrue);
    });

    test('dateTo excludes candidates after that date', () {
      final filter = ImportFilter(dateTo: DateTime(2026, 3, 10, 23, 59, 59));
      final before = newCandidate(
          ActivityType.bath, DateTime(2026, 3, 10, 12, 0));
      final after = newCandidate(
          ActivityType.bath, DateTime(2026, 3, 11, 0, 0));
      expect(filter.matches(before), isTrue);
      expect(filter.matches(after), isFalse);
    });

    test('date range includes candidates within range', () {
      final filter = ImportFilter(
        dateFrom: DateTime(2026, 3, 1),
        dateTo: DateTime(2026, 3, 31, 23, 59, 59),
      );
      final inside = newCandidate(
          ActivityType.bath, DateTime(2026, 3, 15));
      final before = newCandidate(
          ActivityType.bath, DateTime(2026, 2, 28));
      final after = newCandidate(
          ActivityType.bath, DateTime(2026, 4, 1));
      expect(filter.matches(inside), isTrue);
      expect(filter.matches(before), isFalse);
      expect(filter.matches(after), isFalse);
    });

    test('boundary dates: exact match on dateFrom/dateTo', () {
      final boundary = DateTime(2026, 3, 10, 12, 0);
      final filter = ImportFilter(dateFrom: boundary, dateTo: boundary);
      final exact = newCandidate(ActivityType.bath, boundary);
      expect(filter.matches(exact), isTrue);
    });

    test('single excluded type filters correctly', () {
      final filter = ImportFilter(
        excludedTypes: {ActivityType.diaper},
      );
      expect(filter.matches(
          newCandidate(ActivityType.diaper, now)), isFalse);
      expect(filter.matches(
          newCandidate(ActivityType.feedBottle, now)), isTrue);
    });

    test('multiple excluded types filter correctly', () {
      final filter = ImportFilter(
        excludedTypes: {ActivityType.diaper, ActivityType.feedBottle},
      );
      expect(filter.matches(
          newCandidate(ActivityType.diaper, now)), isFalse);
      expect(filter.matches(
          newCandidate(ActivityType.feedBottle, now)), isFalse);
      expect(filter.matches(
          newCandidate(ActivityType.bath, now)), isTrue);
    });

    test('excludedTypes with all types = nothing passes (except errors)', () {
      final filter = ImportFilter(
        excludedTypes: ActivityType.values.toSet(),
      );
      expect(filter.matches(
          newCandidate(ActivityType.feedBottle, now)), isFalse);
      // Errors always pass.
      expect(filter.matches(errorCandidate()), isTrue);
    });

    test('parse error candidates always pass regardless of date/type', () {
      final filter = ImportFilter(
        dateFrom: DateTime(2030, 1, 1),
        dateTo: DateTime(2030, 12, 31),
        excludedTypes: ActivityType.values.toSet(),
      );
      expect(filter.matches(errorCandidate()), isTrue);
    });

    test('combined date + type filter', () {
      final filter = ImportFilter(
        dateFrom: DateTime(2026, 3, 10),
        dateTo: DateTime(2026, 3, 10, 23, 59, 59),
        excludedTypes: {ActivityType.diaper},
      );
      // In range + allowed type → pass.
      expect(
          filter.matches(newCandidate(
              ActivityType.feedBottle, DateTime(2026, 3, 10, 12, 0))),
          isTrue);
      // In range + excluded type → fail.
      expect(
          filter.matches(newCandidate(
              ActivityType.diaper, DateTime(2026, 3, 10, 12, 0))),
          isFalse);
      // Out of range + allowed type → fail.
      expect(
          filter.matches(newCandidate(
              ActivityType.feedBottle, DateTime(2026, 3, 11, 12, 0))),
          isFalse);
    });
  });

  group('ImportFilter.copyWith', () {
    test('updates dateFrom only', () {
      const original = ImportFilter();
      final updated = original.copyWith(
          dateFrom: () => DateTime(2026, 1, 1));
      expect(updated.dateFrom, DateTime(2026, 1, 1));
      expect(updated.dateTo, isNull);
      expect(updated.excludedTypes, isEmpty);
    });

    test('updates excludedTypes only', () {
      const original = ImportFilter();
      final updated = original.copyWith(
          excludedTypes: {ActivityType.bath});
      expect(updated.dateFrom, isNull);
      expect(updated.excludedTypes, {ActivityType.bath});
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
