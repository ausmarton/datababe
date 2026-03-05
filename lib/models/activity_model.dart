import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityModel {
  final String id;
  final String childId;
  final String type;
  final DateTime startTime;
  final DateTime? endTime;
  final int? durationMinutes;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final bool isDeleted;
  final String? notes;

  // Feed (bottle)
  final String? feedType;
  final double? volumeMl;

  // Feed (breast)
  final int? rightBreastMinutes;
  final int? leftBreastMinutes;

  // Diaper / potty
  final String? contents;
  final String? contentSize;
  final String? pooColour;
  final String? pooConsistency;
  final String? peeSize;

  // Meds
  final String? medicationName;
  final String? dose;
  final String? doseUnit;

  // Solids
  final String? foodDescription;
  final String? reaction;
  final String? recipeId;
  final List<String>? ingredientNames;
  final List<String>? allergenNames;

  // Growth
  final double? weightKg;
  final double? lengthCm;
  final double? headCircumferenceCm;

  // Temperature
  final double? tempCelsius;

  ActivityModel({
    required this.id,
    required this.childId,
    required this.type,
    required this.startTime,
    this.endTime,
    this.durationMinutes,
    this.createdBy,
    required this.createdAt,
    required this.modifiedAt,
    this.isDeleted = false,
    this.notes,
    this.feedType,
    this.volumeMl,
    this.rightBreastMinutes,
    this.leftBreastMinutes,
    this.contents,
    this.contentSize,
    this.pooColour,
    this.pooConsistency,
    this.peeSize,
    this.medicationName,
    this.dose,
    this.doseUnit,
    this.foodDescription,
    this.reaction,
    this.recipeId,
    this.ingredientNames,
    this.allergenNames,
    this.weightKg,
    this.lengthCm,
    this.headCircumferenceCm,
    this.tempCelsius,
  });

  Map<String, dynamic> toFirestore() => {
        'childId': childId,
        'type': type,
        'startTime': Timestamp.fromDate(startTime),
        'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
        'durationMinutes': durationMinutes,
        'createdBy': createdBy,
        'createdAt': Timestamp.fromDate(createdAt),
        'modifiedAt': Timestamp.fromDate(modifiedAt),
        'isDeleted': isDeleted,
        'notes': notes,
        'feedType': feedType,
        'volumeMl': volumeMl,
        'rightBreastMinutes': rightBreastMinutes,
        'leftBreastMinutes': leftBreastMinutes,
        'contents': contents,
        'contentSize': contentSize,
        'pooColour': pooColour,
        'pooConsistency': pooConsistency,
        'peeSize': peeSize,
        'medicationName': medicationName,
        'dose': dose,
        'doseUnit': doseUnit,
        'foodDescription': foodDescription,
        'reaction': reaction,
        'recipeId': recipeId,
        'ingredientNames': ingredientNames,
        'allergenNames': allergenNames,
        'weightKg': weightKg,
        'lengthCm': lengthCm,
        'headCircumferenceCm': headCircumferenceCm,
        'tempCelsius': tempCelsius,
      };

  Map<String, dynamic> toMap() => {
        'childId': childId,
        'type': type,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'durationMinutes': durationMinutes,
        'createdBy': createdBy,
        'createdAt': createdAt.toIso8601String(),
        'modifiedAt': modifiedAt.toIso8601String(),
        'isDeleted': isDeleted,
        'notes': notes,
        'feedType': feedType,
        'volumeMl': volumeMl,
        'rightBreastMinutes': rightBreastMinutes,
        'leftBreastMinutes': leftBreastMinutes,
        'contents': contents,
        'contentSize': contentSize,
        'pooColour': pooColour,
        'pooConsistency': pooConsistency,
        'peeSize': peeSize,
        'medicationName': medicationName,
        'dose': dose,
        'doseUnit': doseUnit,
        'foodDescription': foodDescription,
        'reaction': reaction,
        'recipeId': recipeId,
        'ingredientNames': ingredientNames,
        'allergenNames': allergenNames,
        'weightKg': weightKg,
        'lengthCm': lengthCm,
        'headCircumferenceCm': headCircumferenceCm,
        'tempCelsius': tempCelsius,
      };

  factory ActivityModel.fromMap(String id, Map<String, dynamic> d) {
    final createdAt = d['createdAt'] != null
        ? DateTime.parse(d['createdAt'] as String)
        : DateTime.now();
    return ActivityModel(
      id: id,
      childId: d['childId'] as String? ?? '',
      type: d['type'] as String? ?? '',
      startTime: d['startTime'] != null
          ? DateTime.parse(d['startTime'] as String)
          : DateTime.now(),
      endTime: d['endTime'] != null
          ? DateTime.parse(d['endTime'] as String)
          : null,
      durationMinutes: d['durationMinutes'] as int?,
      createdBy: d['createdBy'] as String?,
      createdAt: createdAt,
      modifiedAt: d['modifiedAt'] != null
          ? DateTime.parse(d['modifiedAt'] as String)
          : createdAt,
      isDeleted: d['isDeleted'] as bool? ?? false,
      notes: d['notes'] as String?,
      feedType: d['feedType'] as String?,
      volumeMl: (d['volumeMl'] as num?)?.toDouble(),
      rightBreastMinutes: d['rightBreastMinutes'] as int?,
      leftBreastMinutes: d['leftBreastMinutes'] as int?,
      contents: d['contents'] as String?,
      contentSize: d['contentSize'] as String?,
      pooColour: d['pooColour'] as String?,
      pooConsistency: d['pooConsistency'] as String?,
      peeSize: d['peeSize'] as String?,
      medicationName: d['medicationName'] as String?,
      dose: d['dose'] as String?,
      doseUnit: d['doseUnit'] as String?,
      foodDescription: d['foodDescription'] as String?,
      reaction: d['reaction'] as String?,
      recipeId: d['recipeId'] as String?,
      ingredientNames: (d['ingredientNames'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      allergenNames: (d['allergenNames'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      weightKg: (d['weightKg'] as num?)?.toDouble(),
      lengthCm: (d['lengthCm'] as num?)?.toDouble(),
      headCircumferenceCm: (d['headCircumferenceCm'] as num?)?.toDouble(),
      tempCelsius: (d['tempCelsius'] as num?)?.toDouble(),
    );
  }

  factory ActivityModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return ActivityModel(
      id: doc.id,
      childId: d['childId'] as String? ?? '',
      type: d['type'] as String? ?? '',
      startTime:
          (d['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endTime: (d['endTime'] as Timestamp?)?.toDate(),
      durationMinutes: d['durationMinutes'] as int?,
      createdBy: d['createdBy'] as String?,
      createdAt:
          (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      modifiedAt:
          (d['modifiedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isDeleted: d['isDeleted'] as bool? ?? false,
      notes: d['notes'] as String?,
      feedType: d['feedType'] as String?,
      volumeMl: (d['volumeMl'] as num?)?.toDouble(),
      rightBreastMinutes: d['rightBreastMinutes'] as int?,
      leftBreastMinutes: d['leftBreastMinutes'] as int?,
      contents: d['contents'] as String?,
      contentSize: d['contentSize'] as String?,
      pooColour: d['pooColour'] as String?,
      pooConsistency: d['pooConsistency'] as String?,
      peeSize: d['peeSize'] as String?,
      medicationName: d['medicationName'] as String?,
      dose: d['dose'] as String?,
      doseUnit: d['doseUnit'] as String?,
      foodDescription: d['foodDescription'] as String?,
      reaction: d['reaction'] as String?,
      recipeId: d['recipeId'] as String?,
      ingredientNames: (d['ingredientNames'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      allergenNames: (d['allergenNames'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      weightKg: (d['weightKg'] as num?)?.toDouble(),
      lengthCm: (d['lengthCm'] as num?)?.toDouble(),
      headCircumferenceCm: (d['headCircumferenceCm'] as num?)?.toDouble(),
      tempCelsius: (d['tempCelsius'] as num?)?.toDouble(),
    );
  }
}
