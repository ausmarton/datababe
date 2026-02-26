import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyModel {
  final String id;
  final String name;
  final String createdBy;
  final List<String> memberUids;
  final DateTime createdAt;

  FamilyModel({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.memberUids,
    required this.createdAt,
  });

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'createdBy': createdBy,
        'memberUids': memberUids,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory FamilyModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return FamilyModel(
      id: doc.id,
      name: d['name'] as String? ?? '',
      createdBy: d['createdBy'] as String? ?? '',
      memberUids: List<String>.from(d['memberUids'] ?? []),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
