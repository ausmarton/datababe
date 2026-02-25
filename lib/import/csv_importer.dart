import 'dart:io';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import '../database/daos/activity_dao.dart';
import 'csv_parser.dart';

/// Imports CSV data into the database.
class CsvImporter {
  final ActivityDao _dao;
  static const _uuid = Uuid();

  CsvImporter(this._dao);

  /// Import from a file path. Returns the number of entries imported.
  Future<int> importFromFile(String path, String childId) async {
    final content = await File(path).readAsString();
    return importFromString(content, childId);
  }

  /// Import from CSV string. Returns the number of entries imported.
  Future<int> importFromString(String csvContent, String childId) async {
    final parser = CsvParser();
    final activities = parser.parse(csvContent);
    final now = DateTime.now();

    final entries = activities.map((a) => ActivitiesCompanion(
          id: Value(_uuid.v4()),
          childId: Value(childId),
          type: Value(a.type.name),
          startTime: Value(a.startTime),
          endTime: Value(a.endTime),
          durationMinutes: Value(a.durationMinutes),
          createdAt: Value(now),
          modifiedAt: Value(now),
          feedType: Value(a.feedType),
          volumeMl: Value(a.volumeMl),
          rightBreastMinutes: Value(a.rightBreastMinutes),
          leftBreastMinutes: Value(a.leftBreastMinutes),
          contents: Value(a.contents),
          contentSize: Value(a.contentSize),
          peeSize: Value(a.peeSize),
          pooColour: Value(a.pooColour),
          pooConsistency: Value(a.pooConsistency),
          medicationName: Value(a.medicationName),
          dose: Value(a.dose),
          foodDescription: Value(a.foodDescription),
          reaction: Value(a.reaction),
          weightKg: Value(a.weightKg),
          lengthCm: Value(a.lengthCm),
          headCircumferenceCm: Value(a.headCircumferenceCm),
          tempCelsius: Value(a.tempCelsius),
          notes: Value(a.notes),
        )).toList();

    if (entries.isNotEmpty) {
      await _dao.insertActivities(entries);
    }

    return entries.length;
  }
}
