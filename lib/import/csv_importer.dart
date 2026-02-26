import 'package:uuid/uuid.dart';

import '../models/activity_model.dart';
import '../repositories/activity_repository.dart';
import 'csv_parser.dart';

/// Imports CSV data into the repository.
class CsvImporter {
  final ActivityRepository _repo;
  static const _uuid = Uuid();

  CsvImporter(this._repo);

  /// Import from CSV string. Returns the number of entries imported.
  Future<int> importFromString(
      String csvContent, String childId, String familyId) async {
    final parser = CsvParser();
    final activities = parser.parse(csvContent);
    final now = DateTime.now();

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

    if (entries.isNotEmpty) {
      await _repo.insertActivities(familyId, entries);
    }

    return entries.length;
  }
}
