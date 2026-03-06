import 'package:cloud_firestore/cloud_firestore.dart';

class TargetModel {
  final String id;
  final String childId;
  final String activityType;
  final String metric;
  final String period;
  final double targetValue;
  final bool isActive;
  final String createdBy;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final String? ingredientName;
  final String? allergenName;
  final bool isDeleted;

  const TargetModel({
    required this.id,
    required this.childId,
    required this.activityType,
    required this.metric,
    required this.period,
    required this.targetValue,
    this.isActive = true,
    required this.createdBy,
    required this.createdAt,
    required this.modifiedAt,
    this.ingredientName,
    this.allergenName,
    this.isDeleted = false,
  });

  Map<String, dynamic> toFirestore() => {
        'childId': childId,
        'activityType': activityType,
        'metric': metric,
        'period': period,
        'targetValue': targetValue,
        'isActive': isActive,
        'createdBy': createdBy,
        'createdAt': Timestamp.fromDate(createdAt),
        'modifiedAt': Timestamp.fromDate(modifiedAt),
        'ingredientName': ingredientName,
        'allergenName': allergenName,
        'isDeleted': isDeleted,
      };

  Map<String, dynamic> toMap() => {
        'childId': childId,
        'activityType': activityType,
        'metric': metric,
        'period': period,
        'targetValue': targetValue,
        'isActive': isActive,
        'createdBy': createdBy,
        'createdAt': createdAt.toIso8601String(),
        'modifiedAt': modifiedAt.toIso8601String(),
        'ingredientName': ingredientName,
        'allergenName': allergenName,
        'isDeleted': isDeleted,
      };

  factory TargetModel.fromMap(String id, Map<String, dynamic> d) {
    final createdAt = d['createdAt'] != null
        ? DateTime.parse(d['createdAt'] as String)
        : DateTime.now();
    return TargetModel(
      id: id,
      childId: d['childId'] as String? ?? '',
      activityType: d['activityType'] as String? ?? '',
      metric: d['metric'] as String? ?? '',
      period: d['period'] as String? ?? '',
      targetValue: (d['targetValue'] as num?)?.toDouble() ?? 0,
      isActive: d['isActive'] as bool? ?? true,
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: createdAt,
      modifiedAt: d['modifiedAt'] != null
          ? DateTime.parse(d['modifiedAt'] as String)
          : createdAt,
      ingredientName: d['ingredientName'] as String?,
      allergenName: d['allergenName'] as String?,
      isDeleted: d['isDeleted'] as bool? ?? false,
    );
  }

  factory TargetModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    final createdAt =
        (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    return TargetModel(
      id: doc.id,
      childId: d['childId'] as String? ?? '',
      activityType: d['activityType'] as String? ?? '',
      metric: d['metric'] as String? ?? '',
      period: d['period'] as String? ?? '',
      targetValue: (d['targetValue'] as num?)?.toDouble() ?? 0,
      isActive: d['isActive'] as bool? ?? true,
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: createdAt,
      modifiedAt:
          (d['modifiedAt'] as Timestamp?)?.toDate() ?? createdAt,
      ingredientName: d['ingredientName'] as String?,
      allergenName: d['allergenName'] as String?,
      isDeleted: d['isDeleted'] as bool? ?? false,
    );
  }
}
