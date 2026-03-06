import 'package:uuid/uuid.dart';

import '../models/activity_model.dart';
import '../repositories/activity_repository.dart';
import 'csv_parser.dart';

/// Result of a CSV import with dedup.
class ImportResult {
  final int imported;
  final int skipped;

  const ImportResult({required this.imported, required this.skipped});
}

/// Imports CSV data into the repository, deduplicating against existing records.
class CsvImporter {
  final ActivityRepository _repo;
  static const _uuid = Uuid();

  CsvImporter(this._repo);

  /// Import from CSV string. Returns counts of imported and skipped entries.
  Future<ImportResult> importFromString(
      String csvContent, String childId, String familyId) async {
    final parser = CsvParser();
    final activities = parser.parse(csvContent);
    if (activities.isEmpty) {
      return const ImportResult(imported: 0, skipped: 0);
    }

    final now = DateTime.now();

    // Build ActivityModels from parsed rows.
    final entries = activities
        .map((a) => ActivityModel(
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
            ))
        .toList();

    // Find the time range of incoming entries for a targeted query.
    var minTime = entries.first.startTime;
    var maxTime = entries.first.startTime;
    for (final e in entries) {
      if (e.startTime.isBefore(minTime)) minTime = e.startTime;
      if (e.startTime.isAfter(maxTime)) maxTime = e.startTime;
    }

    // Query existing activities in that range (including soft-deleted).
    final existing = await _repo.findByTimeRange(
      familyId,
      childId,
      minTime,
      maxTime,
    );

    // Build fingerprint set from existing records.
    final existingFingerprints = <String>{};
    for (final a in existing) {
      existingFingerprints.add(_fingerprint(a));
    }

    // Filter out duplicates.
    final toInsert = <ActivityModel>[];
    for (final entry in entries) {
      if (!existingFingerprints.contains(_fingerprint(entry))) {
        toInsert.add(entry);
      }
    }

    if (toInsert.isNotEmpty) {
      await _repo.insertActivities(familyId, toInsert);
    }

    return ImportResult(
      imported: toInsert.length,
      skipped: entries.length - toInsert.length,
    );
  }

  /// Compute a fingerprint for dedup: type + childId + startTime + distinguishing fields.
  static String _fingerprint(ActivityModel a) {
    final base = '${a.type}|${a.childId}|${a.startTime.toIso8601String()}';
    final extra = switch (a.type) {
      'feedBottle' => '|${a.volumeMl}|${a.feedType}',
      'feedBreast' => '|${a.rightBreastMinutes}|${a.leftBreastMinutes}',
      'diaper' || 'potty' => '|${a.contents}|${a.contentSize}',
      'meds' => '|${a.medicationName}|${a.dose}',
      'solids' => '|${a.foodDescription}',
      'growth' => '|${a.weightKg}|${a.lengthCm}|${a.headCircumferenceCm}',
      'pump' => '|${a.volumeMl}',
      'temperature' => '|${a.tempCelsius}',
      _ => '|${a.durationMinutes}',
    };
    return '$base$extra';
  }
}
