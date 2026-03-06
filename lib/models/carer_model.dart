import 'package:cloud_firestore/cloud_firestore.dart';

class CarerModel {
  final String id;
  final String uid;
  final String displayName;
  final String role;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final bool isDeleted;

  CarerModel({
    required this.id,
    required this.uid,
    required this.displayName,
    required this.role,
    required this.createdAt,
    required this.modifiedAt,
    this.isDeleted = false,
  });

  Map<String, dynamic> toFirestore() => {
        'uid': uid,
        'displayName': displayName,
        'role': role,
        'createdAt': Timestamp.fromDate(createdAt),
        'modifiedAt': Timestamp.fromDate(modifiedAt),
        'isDeleted': isDeleted,
      };

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'displayName': displayName,
        'role': role,
        'createdAt': createdAt.toIso8601String(),
        'modifiedAt': modifiedAt.toIso8601String(),
        'isDeleted': isDeleted,
      };

  factory CarerModel.fromMap(String id, Map<String, dynamic> d) {
    final createdAt = d['createdAt'] != null
        ? DateTime.parse(d['createdAt'] as String)
        : DateTime.now();
    return CarerModel(
      id: id,
      uid: d['uid'] as String? ?? '',
      displayName: d['displayName'] as String? ?? '',
      role: d['role'] as String? ?? 'carer',
      createdAt: createdAt,
      modifiedAt: d['modifiedAt'] != null
          ? DateTime.parse(d['modifiedAt'] as String)
          : createdAt,
      isDeleted: d['isDeleted'] as bool? ?? false,
    );
  }

  factory CarerModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    final createdAt =
        (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    return CarerModel(
      id: doc.id,
      uid: d['uid'] as String? ?? '',
      displayName: d['displayName'] as String? ?? '',
      role: d['role'] as String? ?? 'carer',
      createdAt: createdAt,
      modifiedAt:
          (d['modifiedAt'] as Timestamp?)?.toDate() ?? createdAt,
      isDeleted: d['isDeleted'] as bool? ?? false,
    );
  }
}
