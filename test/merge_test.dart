import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:filho/sync/merge.dart';

/// Helper to build a minimal valid backup JSON string.
String _backup({
  List<Map<String, dynamic>> families = const [],
  List<Map<String, dynamic>> children = const [],
  List<Map<String, dynamic>> carers = const [],
  List<Map<String, dynamic>> familyCarers = const [],
  List<Map<String, dynamic>> activities = const [],
}) {
  return jsonEncode({
    'version': 1,
    'exportedAt': '2025-01-01T00:00:00.000Z',
    'schemaVersion': 1,
    'families': families,
    'children': children,
    'carers': carers,
    'familyCarers': familyCarers,
    'activities': activities,
  });
}

Map<String, dynamic> _family(String id, {String? createdAt}) => {
      'id': id,
      'name': 'Family $id',
      'createdAt': createdAt ?? '2025-01-01T00:00:00.000Z',
    };

Map<String, dynamic> _activity(
  String id, {
  String? modifiedAt,
  String? notes,
}) =>
    {
      'id': id,
      'childId': 'child-1',
      'type': 'feedBottle',
      'startTime': '2025-01-01T08:00:00.000Z',
      'endTime': null,
      'durationMinutes': null,
      'createdBy': null,
      'createdAt': '2025-01-01T00:00:00.000Z',
      'modifiedAt': modifiedAt ?? '2025-01-01T00:00:00.000Z',
      'lockedBy': null,
      'isDeleted': false,
      'notes': notes,
      'feedType': 'formula',
      'volumeMl': 120.0,
      'rightBreastMinutes': null,
      'leftBreastMinutes': null,
      'contents': null,
      'contentSize': null,
      'pooColour': null,
      'pooConsistency': null,
      'peeSize': null,
      'medicationName': null,
      'dose': null,
      'doseUnit': null,
      'foodDescription': null,
      'reaction': null,
      'weightKg': null,
      'lengthCm': null,
      'headCircumferenceCm': null,
      'tempCelsius': null,
    };

Map<String, dynamic> _familyCarer(
  String familyId,
  String carerId, {
  String? joinedAt,
}) =>
    {
      'familyId': familyId,
      'carerId': carerId,
      'inviteCode': null,
      'joinedAt': joinedAt ?? '2025-01-01T00:00:00.000Z',
    };

void main() {
  group('mergeBackups', () {
    test('identical data produces no changes', () {
      final json = _backup(families: [_family('f1')]);
      final result = mergeBackups(json, json);
      expect(result.hasChanges, false);
      expect(result.addedToLocal, 0);
      expect(result.addedToCloud, 0);
      expect(result.updatedLocal, 0);
      expect(result.updatedCloud, 0);
    });

    test('record only in local is added to cloud', () {
      final local = _backup(families: [_family('f1'), _family('f2')]);
      final cloud = _backup(families: [_family('f1')]);
      final result = mergeBackups(local, cloud);

      expect(result.cloudChanged, true);
      expect(result.localChanged, false);
      expect(result.addedToCloud, 1);

      final merged = jsonDecode(result.mergedJson);
      expect((merged['families'] as List).length, 2);
    });

    test('record only in cloud is added to local', () {
      final local = _backup(families: [_family('f1')]);
      final cloud = _backup(families: [_family('f1'), _family('f2')]);
      final result = mergeBackups(local, cloud);

      expect(result.localChanged, true);
      expect(result.cloudChanged, false);
      expect(result.addedToLocal, 1);

      final merged = jsonDecode(result.mergedJson);
      expect((merged['families'] as List).length, 2);
    });

    test('newer cloud record wins over older local', () {
      final local = _backup(activities: [
        _activity('a1', modifiedAt: '2025-01-01T10:00:00.000Z', notes: 'old'),
      ]);
      final cloud = _backup(activities: [
        _activity('a1', modifiedAt: '2025-01-01T12:00:00.000Z', notes: 'new'),
      ]);

      final result = mergeBackups(local, cloud);
      expect(result.localChanged, true);
      expect(result.updatedLocal, 1);

      final merged = jsonDecode(result.mergedJson);
      final acts = merged['activities'] as List;
      expect(acts.first['notes'], 'new');
    });

    test('newer local record wins over older cloud', () {
      final local = _backup(activities: [
        _activity('a1', modifiedAt: '2025-01-01T14:00:00.000Z', notes: 'local'),
      ]);
      final cloud = _backup(activities: [
        _activity('a1', modifiedAt: '2025-01-01T12:00:00.000Z', notes: 'cloud'),
      ]);

      final result = mergeBackups(local, cloud);
      expect(result.cloudChanged, true);
      expect(result.updatedCloud, 1);

      final merged = jsonDecode(result.mergedJson);
      final acts = merged['activities'] as List;
      expect(acts.first['notes'], 'local');
    });

    test('local wins ties (equal timestamps)', () {
      final ts = '2025-01-01T10:00:00.000Z';
      final local = _backup(activities: [
        _activity('a1', modifiedAt: ts, notes: 'local-version'),
      ]);
      final cloud = _backup(activities: [
        _activity('a1', modifiedAt: ts, notes: 'cloud-version'),
      ]);

      final result = mergeBackups(local, cloud);
      // Equal timestamps = no real change counted
      expect(result.hasChanges, false);

      final merged = jsonDecode(result.mergedJson);
      expect((merged['activities'] as List).first['notes'], 'local-version');
    });

    test('familyCarers use composite key', () {
      final local = _backup(familyCarers: [
        _familyCarer('f1', 'c1'),
      ]);
      final cloud = _backup(familyCarers: [
        _familyCarer('f1', 'c2'),
      ]);

      final result = mergeBackups(local, cloud);
      expect(result.addedToLocal, 1); // f1|c2 from cloud
      expect(result.addedToCloud, 1); // f1|c1 from local

      final merged = jsonDecode(result.mergedJson);
      expect((merged['familyCarers'] as List).length, 2);
    });

    test('both sides empty produces no changes', () {
      final json = _backup();
      final result = mergeBackups(json, json);
      expect(result.hasChanges, false);
    });

    test('mixed changes across multiple tables', () {
      final local = _backup(
        families: [_family('f1')],
        activities: [
          _activity('a1', modifiedAt: '2025-01-01T10:00:00.000Z'),
        ],
      );
      final cloud = _backup(
        families: [_family('f1'), _family('f2')],
        activities: [
          _activity('a2', modifiedAt: '2025-01-01T10:00:00.000Z'),
        ],
      );

      final result = mergeBackups(local, cloud);
      expect(result.localChanged, true); // got f2 and a2
      expect(result.cloudChanged, true); // got a1
      expect(result.addedToLocal, 2); // f2 + a2
      expect(result.addedToCloud, 1); // a1
    });

    test('supports millisecond epoch timestamps', () {
      final local = _backup(activities: [
        _activity(
          'a1',
          modifiedAt: '2025-01-01T14:00:00.000Z',
          notes: 'local',
        ),
      ]);

      // Cloud uses epoch millis for the same activity, but earlier
      final cloudData = {
        'version': 1,
        'exportedAt': '2025-01-01T00:00:00.000Z',
        'schemaVersion': 1,
        'families': <Map<String, dynamic>>[],
        'children': <Map<String, dynamic>>[],
        'carers': <Map<String, dynamic>>[],
        'familyCarers': <Map<String, dynamic>>[],
        'activities': [
          {
            ..._activity('a1', notes: 'cloud'),
            // epoch for 2025-01-01T12:00:00Z
            'modifiedAt': DateTime.utc(2025, 1, 1, 12).millisecondsSinceEpoch,
          },
        ],
      };
      final cloud = jsonEncode(cloudData);

      final result = mergeBackups(local, cloud);
      final merged = jsonDecode(result.mergedJson);
      expect((merged['activities'] as List).first['notes'], 'local');
    });
  });
}
