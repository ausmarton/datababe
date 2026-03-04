import 'package:cloud_firestore/cloud_firestore.dart';

class CarerModel {
  final String id;
  final String uid;
  final String displayName;
  final String role;
  final DateTime createdAt;

  CarerModel({
    required this.id,
    required this.uid,
    required this.displayName,
    required this.role,
    required this.createdAt,
  });

  Map<String, dynamic> toFirestore() => {
        'uid': uid,
        'displayName': displayName,
        'role': role,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'displayName': displayName,
        'role': role,
        'createdAt': createdAt.toIso8601String(),
      };

  factory CarerModel.fromMap(String id, Map<String, dynamic> d) {
    return CarerModel(
      id: id,
      uid: d['uid'] as String? ?? '',
      displayName: d['displayName'] as String? ?? '',
      role: d['role'] as String? ?? 'carer',
      createdAt: DateTime.parse(d['createdAt'] as String),
    );
  }

  factory CarerModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return CarerModel(
      id: doc.id,
      uid: d['uid'] as String? ?? '',
      displayName: d['displayName'] as String? ?? '',
      role: d['role'] as String? ?? 'carer',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
