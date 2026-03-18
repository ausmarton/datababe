import 'package:csv/csv.dart';
import 'package:uuid/uuid.dart';

import '../models/activity_model.dart';
import '../repositories/activity_repository.dart';
import 'csv_parser.dart';
import 'import_preview.dart';

/// Result of a CSV import with dedup.
class ImportResult {
  final int imported;
  final int skipped;
  final List<ParseError> parseErrors;
  final List<String> skippedRows; // CSV lines of fingerprint dupes

  const ImportResult({
    required this.imported,
    required this.skipped,
    this.parseErrors = const [],
    this.skippedRows = const [],
  });
}

/// Imports CSV data into the repository, deduplicating against existing records.
class CsvImporter {
  final ActivityRepository _repo;
  static const _uuid = Uuid();

  CsvImporter(this._repo);

  /// Import from CSV string. Returns counts of imported and skipped entries.
  ///
  /// When [includeSoftDeleted] is false (the default), soft-deleted records
  /// are excluded from dedup, allowing re-import of previously deleted entries.
  Future<ImportResult> importFromString(
    String csvContent,
    String childId,
    String familyId, {
    bool includeSoftDeleted = false,
    String? createdBy,
  }) async {
    final parser = CsvParser();
    final parseResult = parser.parse(csvContent);
    final activities = parseResult.activities;
    if (activities.isEmpty) {
      return ImportResult(
        imported: 0,
        skipped: 0,
        parseErrors: parseResult.errors,
      );
    }

    final now = DateTime.now();

    // Build ActivityModels from parsed rows, keeping the index for CSV reconstruction.
    final entries = <(ActivityModel, ParsedActivity)>[];
    for (final a in activities) {
      entries.add((
        ActivityModel(
          id: _uuid.v4(),
          childId: childId,
          type: a.type.name,
          startTime: a.startTime,
          endTime: a.endTime,
          durationMinutes: a.durationMinutes,
          createdBy: createdBy,
          createdAt: now,
          modifiedAt: now,
          feedType: a.feedType,
          volumeMl: a.volumeMl,
          rightBreastMinutes: a.rightBreastMinutes,
          leftBreastMinutes: a.leftBreastMinutes,
          contents: a.contents,
          contentSize: a.contentSize,
          peeSize: a.peeSize,
          pooColour: a.pooColour,
          pooConsistency: a.pooConsistency,
          medicationName: a.medicationName,
          dose: a.dose,
          foodDescription: a.foodDescription,
          reaction: a.reaction,
          weightKg: a.weightKg,
          lengthCm: a.lengthCm,
          headCircumferenceCm: a.headCircumferenceCm,
          tempCelsius: a.tempCelsius,
          notes: a.notes,
        ),
        a,
      ));
    }

    // Find the time range of incoming entries for a targeted query.
    var minTime = entries.first.$1.startTime;
    var maxTime = entries.first.$1.startTime;
    for (final (model, _) in entries) {
      if (model.startTime.isBefore(minTime)) minTime = model.startTime;
      if (model.startTime.isAfter(maxTime)) maxTime = model.startTime;
    }

    // Query existing activities in that range (including soft-deleted).
    // Add 1 second to maxTime because findByTimeRange uses exclusive end (< not <=).
    final existing = await _repo.findByTimeRange(
      familyId,
      childId,
      minTime,
      maxTime.add(const Duration(seconds: 1)),
    );

    // Filter candidates based on soft-delete preference.
    final candidates = includeSoftDeleted
        ? existing
        : existing.where((a) => !a.isDeleted).toList();

    // Build fingerprint set from candidates.
    final existingFingerprints = <String>{};
    for (final a in candidates) {
      existingFingerprints.add(fingerprint(a));
    }

    // Filter out duplicates, capturing skipped CSV lines.
    final toInsert = <ActivityModel>[];
    final skippedRows = <String>[];
    for (final (model, parsed) in entries) {
      if (!existingFingerprints.contains(fingerprint(model))) {
        toInsert.add(model);
      } else {
        skippedRows.add(toCsvLine(parsed.rawCsvRow));
      }
    }

    if (toInsert.isNotEmpty) {
      await _repo.insertActivities(familyId, toInsert);
    }

    return ImportResult(
      imported: toInsert.length,
      skipped: entries.length - toInsert.length,
      parseErrors: parseResult.errors,
      skippedRows: skippedRows,
    );
  }

  /// Import only selected candidates (from preview screen).
  ///
  /// Only candidates with [CandidateStatus.newActivity] and non-null models
  /// are inserted. Returns an [ImportResult] with counts.
  Future<ImportResult> importSelected(
    String familyId,
    List<ImportCandidate> candidates,
  ) async {
    final toInsert = <ActivityModel>[];
    for (final c in candidates) {
      if (c.status == CandidateStatus.newActivity && c.model != null) {
        toInsert.add(c.model!);
      }
    }

    if (toInsert.isNotEmpty) {
      await _repo.insertActivities(familyId, toInsert);
    }

    return ImportResult(
      imported: toInsert.length,
      skipped: candidates.length - toInsert.length,
    );
  }

  /// Compute a fingerprint for dedup: type + childId + startTime + distinguishing fields.
  static String fingerprint(ActivityModel a) {
    final base = '${a.type}|${a.childId}|${a.startTime.toIso8601String()}';
    final extra = switch (a.type) {
      'feedBottle' => '|${a.volumeMl}|${a.feedType}',
      'feedBreast' => '|${a.rightBreastMinutes}|${a.leftBreastMinutes}',
      'diaper' || 'potty' => '|${a.contents}|${a.contentSize}',
      'meds' => '|${a.medicationName}|${a.dose}',
      'solids' => '|${a.foodDescription}|${a.reaction}',
      'growth' => '|${a.weightKg}|${a.lengthCm}|${a.headCircumferenceCm}',
      'pump' => '|${a.volumeMl}',
      'temperature' => '|${a.tempCelsius}',
      _ => '|${a.durationMinutes}',
    };
    return '$base$extra';
  }

  /// Convert a raw CSV row back to a CSV line string.
  static String toCsvLine(List<dynamic> row) {
    return const ListToCsvConverter().convert([row]);
  }
}
