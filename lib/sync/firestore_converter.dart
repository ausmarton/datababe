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
        result[field] = value.toDate().toIso8601String();
      }
    }

    // Ensure isDeleted has a default value (Firestore docs may lack it).
    result.putIfAbsent('isDeleted', () => false);

    // Ensure required timestamp fields have defaults at storage time.
    // Without this, records with missing fields generate a new DateTime.now()
    // on every read via fromMap() fallback — making modifiedAt unstable and
    // breaking sync comparisons.
    const requiredTimestamps = {'startTime', 'createdAt', 'modifiedAt'};
    final missingFields = requiredTimestamps
        .where((f) => result[f] == null || result[f] == '')
        .toList();
    if (missingFields.isNotEmpty) {
      final now = DateTime.now().toIso8601String();
      for (final field in missingFields) {
        if (field == 'modifiedAt') {
          // modifiedAt defaults to createdAt if available, else now
          result[field] = result['createdAt'] as String? ?? now;
        } else {
          result[field] = now;
        }
      }
      debugPrint('[Sync] fromFirestore: filled missing fields '
          '$missingFields — data may be corrupt');
    }

    return result;
  }
}
