import 'package:uuid/uuid.dart';

import '../models/activity_model.dart';
import '../repositories/activity_repository.dart';
import 'csv_importer.dart';
import 'csv_parser.dart';
import 'import_preview.dart';

/// Analyzes CSV content and classifies each row as new, duplicate, or error.
class CsvAnalyzer {
  final ActivityRepository _repo;
  static const _uuid = Uuid();

  CsvAnalyzer(this._repo);

  /// Analyze CSV content and return an [ImportPreview] with classified rows.
  Future<ImportPreview> analyze(
    String csvContent,
    String childId,
    String familyId, {
    bool includeSoftDeleted = false,
  }) async {
    final parser = CsvParser();
    final parseResult = parser.parse(csvContent);
    final activities = parseResult.activities;

    if (activities.isEmpty && parseResult.errors.isEmpty) {
      return ImportPreview(
        candidates: const [],
        childId: childId,
        familyId: familyId,
      );
    }

    final now = DateTime.now();

    // Build ActivityModels from parsed rows (same logic as CsvImporter).
    final entries = <(ActivityModel, ParsedActivity, int)>[];
    for (var i = 0; i < activities.length; i++) {
      final a = activities[i];
      entries.add((
        ActivityModel(
          id: _uuid.v4(),
          childId: childId,
          type: a.type.name,
          startTime: a.startTime,
          endTime: a.endTime,
          durationMinutes: a.durationMinutes,
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
        i + 1, // 1-based row number (matching parser convention)
      ));
    }

    // Build fingerprint set from existing DB records.
    final existingFingerprints = <String>{};
    if (entries.isNotEmpty) {
      var minTime = entries.first.$1.startTime;
      var maxTime = entries.first.$1.startTime;
      for (final (model, _, _) in entries) {
        if (model.startTime.isBefore(minTime)) minTime = model.startTime;
        if (model.startTime.isAfter(maxTime)) maxTime = model.startTime;
      }

      final existing = await _repo.findByTimeRange(
        familyId,
        childId,
        minTime,
        maxTime,
      );

      final candidates = includeSoftDeleted
          ? existing
          : existing.where((a) => !a.isDeleted).toList();

      for (final a in candidates) {
        existingFingerprints.add(CsvImporter.fingerprint(a));
      }
    }

    // Classify each row.
    final result = <ImportCandidate>[];

    // We need to interleave parsed activities and errors by row number.
    // Parse errors have their own row numbers from the parser.
    // Parsed activities have sequential indices.
    // Build a combined list sorted by row number.

    // Track which error row numbers we've seen.
    final errorByRow = <int, ParseError>{};
    for (final e in parseResult.errors) {
      errorByRow[e.rowNumber] = e;
    }

    // Add parsed activity candidates.
    for (final (model, parsed, rowNum) in entries) {
      final fp = CsvImporter.fingerprint(model);
      final isDuplicate = existingFingerprints.contains(fp);

      result.add(ImportCandidate(
        rowNumber: rowNum,
        status: isDuplicate ? CandidateStatus.duplicate : CandidateStatus.newActivity,
        model: model,
        parsed: parsed,
        type: parsed.type,
        startTime: model.startTime,
      ));
    }

    // Add error candidates.
    for (final e in parseResult.errors) {
      result.add(ImportCandidate(
        rowNumber: e.rowNumber,
        status: CandidateStatus.parseError,
        error: e,
      ));
    }

    // Sort by row number for consistent ordering.
    result.sort((a, b) => a.rowNumber.compareTo(b.rowNumber));

    return ImportPreview(
      candidates: result,
      childId: childId,
      familyId: familyId,
    );
  }
}
