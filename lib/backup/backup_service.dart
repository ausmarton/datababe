import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/database.dart';

const _currentVersion = 1;

class BackupResult {
  final int families;
  final int children;
  final int carers;
  final int familyCarers;
  final int activities;

  const BackupResult({
    required this.families,
    required this.children,
    required this.carers,
    required this.familyCarers,
    required this.activities,
  });

  int get total => families + children + carers + familyCarers + activities;

  @override
  String toString() =>
      'Restored $families families, $children children, '
      '$carers carers, $familyCarers family-carer links, '
      '$activities activities';
}

/// Export all data from the database to a JSON string.
Future<String> exportToJson(AppDatabase db) async {
  final families = await db.select(db.families).get();
  final children = await db.select(db.children).get();
  final carers = await db.select(db.carers).get();
  final familyCarers = await db.select(db.familyCarers).get();
  final activities = await db.select(db.activities).get();

  final backup = {
    'version': _currentVersion,
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'schemaVersion': db.schemaVersion,
    'families': families.map(_familyToJson).toList(),
    'children': children.map(_childToJson).toList(),
    'carers': carers.map(_carerToJson).toList(),
    'familyCarers': familyCarers.map(_familyCarerToJson).toList(),
    'activities': activities.map(_activityToJson).toList(),
  };

  return jsonEncode(backup);
}

/// Import data from a JSON string, replacing all existing data.
Future<BackupResult> importFromJson(AppDatabase db, String jsonString) async {
  final Map<String, dynamic> backup;
  try {
    backup = jsonDecode(jsonString) as Map<String, dynamic>;
  } catch (_) {
    throw const FormatException('Invalid JSON');
  }

  final version = backup['version'];
  if (version == null || version is! int) {
    throw const FormatException('Missing or invalid "version" field');
  }
  if (version > _currentVersion) {
    throw FormatException(
      'Backup version $version is newer than supported version $_currentVersion',
    );
  }

  final familiesList = _asList(backup, 'families');
  final childrenList = _asList(backup, 'children');
  final carersList = _asList(backup, 'carers');
  final familyCarersList = _asList(backup, 'familyCarers');
  final activitiesList = _asList(backup, 'activities');

  await db.transaction(() async {
    // Delete in reverse FK order.
    await db.delete(db.activities).go();
    await db.delete(db.familyCarers).go();
    await db.delete(db.children).go();
    await db.delete(db.carers).go();
    await db.delete(db.families).go();

    // Insert in FK order.
    for (final f in familiesList) {
      await db.into(db.families).insert(_familyFromJson(f));
    }
    for (final c in childrenList) {
      await db.into(db.children).insert(_childFromJson(c));
    }
    for (final c in carersList) {
      await db.into(db.carers).insert(_carerFromJson(c));
    }
    for (final fc in familyCarersList) {
      await db.into(db.familyCarers).insert(_familyCarerFromJson(fc));
    }
    for (final a in activitiesList) {
      await db.into(db.activities).insert(_activityFromJson(a));
    }
  });

  return BackupResult(
    families: familiesList.length,
    children: childrenList.length,
    carers: carersList.length,
    familyCarers: familyCarersList.length,
    activities: activitiesList.length,
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

List<Map<String, dynamic>> _asList(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value == null) return [];
  if (value is! List) {
    throw FormatException('"$key" must be a list');
  }
  return value.cast<Map<String, dynamic>>();
}

DateTime _parseDateTime(dynamic value) {
  if (value is String) return DateTime.parse(value);
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  throw FormatException('Cannot parse DateTime from $value');
}

DateTime? _parseDateTimeOrNull(dynamic value) {
  if (value == null) return null;
  return _parseDateTime(value);
}

// -- Family -----------------------------------------------------------------

Map<String, dynamic> _familyToJson(Family f) => {
      'id': f.id,
      'name': f.name,
      'createdAt': f.createdAt.toUtc().toIso8601String(),
    };

FamiliesCompanion _familyFromJson(Map<String, dynamic> j) => FamiliesCompanion(
      id: Value(j['id'] as String),
      name: Value(j['name'] as String),
      createdAt: Value(_parseDateTime(j['createdAt'])),
    );

// -- Child ------------------------------------------------------------------

Map<String, dynamic> _childToJson(ChildrenData c) => {
      'id': c.id,
      'familyId': c.familyId,
      'name': c.name,
      'dateOfBirth': c.dateOfBirth.toUtc().toIso8601String(),
      'notes': c.notes,
      'createdAt': c.createdAt.toUtc().toIso8601String(),
    };

ChildrenCompanion _childFromJson(Map<String, dynamic> j) => ChildrenCompanion(
      id: Value(j['id'] as String),
      familyId: Value(j['familyId'] as String?),
      name: Value(j['name'] as String),
      dateOfBirth: Value(_parseDateTime(j['dateOfBirth'])),
      notes: Value(j['notes'] as String? ?? ''),
      createdAt: Value(_parseDateTime(j['createdAt'])),
    );

// -- Carer ------------------------------------------------------------------

Map<String, dynamic> _carerToJson(Carer c) => {
      'id': c.id,
      'displayName': c.displayName,
      'role': c.role,
      'createdAt': c.createdAt.toUtc().toIso8601String(),
    };

CarersCompanion _carerFromJson(Map<String, dynamic> j) => CarersCompanion(
      id: Value(j['id'] as String),
      displayName: Value(j['displayName'] as String),
      role: Value(j['role'] as String),
      createdAt: Value(_parseDateTime(j['createdAt'])),
    );

// -- FamilyCarer ------------------------------------------------------------

Map<String, dynamic> _familyCarerToJson(FamilyCarer fc) => {
      'familyId': fc.familyId,
      'carerId': fc.carerId,
      'inviteCode': fc.inviteCode,
      'joinedAt': fc.joinedAt.toUtc().toIso8601String(),
    };

FamilyCarersCompanion _familyCarerFromJson(Map<String, dynamic> j) =>
    FamilyCarersCompanion(
      familyId: Value(j['familyId'] as String),
      carerId: Value(j['carerId'] as String),
      inviteCode: Value(j['inviteCode'] as String?),
      joinedAt: Value(_parseDateTime(j['joinedAt'])),
    );

// -- Activity ---------------------------------------------------------------

Map<String, dynamic> _activityToJson(Activity a) => {
      'id': a.id,
      'childId': a.childId,
      'type': a.type,
      'startTime': a.startTime.toUtc().toIso8601String(),
      'endTime': a.endTime?.toUtc().toIso8601String(),
      'durationMinutes': a.durationMinutes,
      'createdBy': a.createdBy,
      'createdAt': a.createdAt.toUtc().toIso8601String(),
      'modifiedAt': a.modifiedAt.toUtc().toIso8601String(),
      'lockedBy': a.lockedBy,
      'isDeleted': a.isDeleted,
      'notes': a.notes,
      // Feed (bottle)
      'feedType': a.feedType,
      'volumeMl': a.volumeMl,
      // Feed (breast)
      'rightBreastMinutes': a.rightBreastMinutes,
      'leftBreastMinutes': a.leftBreastMinutes,
      // Diaper / potty
      'contents': a.contents,
      'contentSize': a.contentSize,
      'pooColour': a.pooColour,
      'pooConsistency': a.pooConsistency,
      'peeSize': a.peeSize,
      // Meds
      'medicationName': a.medicationName,
      'dose': a.dose,
      'doseUnit': a.doseUnit,
      // Solids
      'foodDescription': a.foodDescription,
      'reaction': a.reaction,
      // Growth
      'weightKg': a.weightKg,
      'lengthCm': a.lengthCm,
      'headCircumferenceCm': a.headCircumferenceCm,
      // Temperature
      'tempCelsius': a.tempCelsius,
    };

ActivitiesCompanion _activityFromJson(Map<String, dynamic> j) =>
    ActivitiesCompanion(
      id: Value(j['id'] as String),
      childId: Value(j['childId'] as String),
      type: Value(j['type'] as String),
      startTime: Value(_parseDateTime(j['startTime'])),
      endTime: Value(_parseDateTimeOrNull(j['endTime'])),
      durationMinutes: Value(j['durationMinutes'] as int?),
      createdBy: Value(j['createdBy'] as String?),
      createdAt: Value(_parseDateTime(j['createdAt'])),
      modifiedAt: Value(_parseDateTime(j['modifiedAt'])),
      lockedBy: Value(j['lockedBy'] as String?),
      isDeleted: Value(j['isDeleted'] as bool? ?? false),
      notes: Value(j['notes'] as String?),
      // Feed (bottle)
      feedType: Value(j['feedType'] as String?),
      volumeMl: Value((j['volumeMl'] as num?)?.toDouble()),
      // Feed (breast)
      rightBreastMinutes: Value(j['rightBreastMinutes'] as int?),
      leftBreastMinutes: Value(j['leftBreastMinutes'] as int?),
      // Diaper / potty
      contents: Value(j['contents'] as String?),
      contentSize: Value(j['contentSize'] as String?),
      pooColour: Value(j['pooColour'] as String?),
      pooConsistency: Value(j['pooConsistency'] as String?),
      peeSize: Value(j['peeSize'] as String?),
      // Meds
      medicationName: Value(j['medicationName'] as String?),
      dose: Value(j['dose'] as String?),
      doseUnit: Value(j['doseUnit'] as String?),
      // Solids
      foodDescription: Value(j['foodDescription'] as String?),
      reaction: Value(j['reaction'] as String?),
      // Growth
      weightKg: Value((j['weightKg'] as num?)?.toDouble()),
      lengthCm: Value((j['lengthCm'] as num?)?.toDouble()),
      headCircumferenceCm:
          Value((j['headCircumferenceCm'] as num?)?.toDouble()),
      // Temperature
      tempCelsius: Value((j['tempCelsius'] as num?)?.toDouble()),
    );
