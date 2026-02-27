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
  final String? ingredientName;

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
    this.ingredientName,
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
        'ingredientName': ingredientName,
      };

  factory TargetModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return TargetModel(
      id: doc.id,
      childId: d['childId'] as String? ?? '',
      activityType: d['activityType'] as String? ?? '',
      metric: d['metric'] as String? ?? '',
      period: d['period'] as String? ?? '',
      targetValue: (d['targetValue'] as num?)?.toDouble() ?? 0,
      isActive: d['isActive'] as bool? ?? true,
      createdBy: d['createdBy'] as String? ?? '',
      createdAt:
          (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      ingredientName: d['ingredientName'] as String?,
    );
  }
}
