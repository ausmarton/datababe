import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Converts between local map format (ISO 8601 strings) and Firestore format
/// (Timestamps). Also strips/adds the familyId field.
class FirestoreConverter {
  FirestoreConverter._();

  /// Known date fields in our data model.
  static const _dateFields = {
    'startTime',
    'endTime',
    'createdAt',
    'modifiedAt',
    'dateOfBirth',
  };

  /// Convert a local map (ISO 8601 strings) to Firestore format (Timestamps).
  /// Removes the 'familyId' field (Firestore uses path segments).
  static Map<String, dynamic> toFirestore(Map<String, dynamic> localMap) {
    final result = Map<String, dynamic>.from(localMap);
    result.remove('familyId');

    for (final field in _dateFields) {
      final value = result[field];
      if (value is String) {
        result[field] = Timestamp.fromDate(DateTime.parse(value));
      }
    }

    return result;
  }

  /// Convert a Firestore document to local map format (ISO 8601 strings).
  /// Adds 'familyId' for local scoping.
  static Map<String, dynamic> fromFirestore(
    Map<String, dynamic> firestoreMap,
    String familyId,
  ) {
    final result = Map<String, dynamic>.from(firestoreMap);
    result['familyId'] = familyId;

    for (final field in _dateFields) {
      final value = result[field];
      if (value is Timestamp) {
        // Convert to LOCAL time before producing ISO string.
        // Queries use DateTime(year, month, day).toIso8601String() which is
        // local time (no 'Z' suffix). Storing UTC (with 'Z') causes
        // lexicographic mismatches at date boundaries — activities near
        // midnight shift to the wrong calendar day in non-UTC timezones.
        result[field] = value.toDate().toLocal().toIso8601String();
      }
    }

    // Ensure isDeleted has a default value (Firestore docs may lack it).
    result.putIfAbsent('isDeleted', () => false);

    // Ensure required timestamp fields have defaults at storage time.
    // Without this, records with missing fields generate a new DateTime.now()
    // on every read via fromMap() fallback — making modifiedAt unstable and
    // breaking sync comparisons.
    final filledFields = <String>[];
    final now = DateTime.now().toIso8601String();

    if (result['createdAt'] == null || result['createdAt'] == '') {
      result['createdAt'] = now;
      filledFields.add('createdAt');
    }

    if (result['modifiedAt'] == null || result['modifiedAt'] == '') {
      result['modifiedAt'] = result['createdAt'] as String;
      filledFields.add('modifiedAt');
    }

    // startTime only applies to activity records (identified by 'type' field).
    // Use createdAt as fallback — it's the closest approximation to when the
    // activity was logged, unlike DateTime.now() which shifts the activity to
    // today's date and makes the original date appear empty.
    if (result.containsKey('type')) {
      if (result['startTime'] == null || result['startTime'] == '') {
        result['startTime'] = result['createdAt'] as String;
        filledFields.add('startTime');
      }
    }

    if (filledFields.isNotEmpty) {
      debugPrint('[Sync] fromFirestore: filled missing fields '
          '$filledFields — data may be corrupt');
    }

    return result;
  }
}
