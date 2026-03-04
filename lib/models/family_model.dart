import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyModel {
  final String id;
  final String name;
  final String createdBy;
  final List<String> memberUids;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final List<String> allergenCategories;

  FamilyModel({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.memberUids,
    required this.createdAt,
    required this.modifiedAt,
    this.allergenCategories = const [],
  });

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'createdBy': createdBy,
        'memberUids': memberUids,
        'createdAt': Timestamp.fromDate(createdAt),
        'modifiedAt': Timestamp.fromDate(modifiedAt),
        'allergenCategories': allergenCategories,
      };

  Map<String, dynamic> toMap() => {
        'name': name,
        'createdBy': createdBy,
        'memberUids': memberUids,
        'createdAt': createdAt.toIso8601String(),
        'modifiedAt': modifiedAt.toIso8601String(),
        'allergenCategories': allergenCategories,
      };

  factory FamilyModel.fromMap(String id, Map<String, dynamic> d) {
    return FamilyModel(
      id: id,
      name: d['name'] as String? ?? '',
      createdBy: d['createdBy'] as String? ?? '',
      memberUids: List<String>.from(d['memberUids'] ?? []),
      createdAt: DateTime.parse(d['createdAt'] as String),
      modifiedAt: DateTime.parse(d['modifiedAt'] as String),
      allergenCategories: List<String>.from(d['allergenCategories'] ?? []),
    );
  }

  factory FamilyModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    final createdAt =
        (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    return FamilyModel(
      id: doc.id,
      name: d['name'] as String? ?? '',
      createdBy: d['createdBy'] as String? ?? '',
      memberUids: List<String>.from(d['memberUids'] ?? []),
      createdAt: createdAt,
      modifiedAt:
          (d['modifiedAt'] as Timestamp?)?.toDate() ?? createdAt,
      allergenCategories: List<String>.from(d['allergenCategories'] ?? []),
    );
  }
}
