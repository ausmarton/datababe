import 'package:cloud_firestore/cloud_firestore.dart';

class IngredientModel {
  final String id;
  final String name;
  final List<String> allergens;
  final bool isDeleted;
  final String createdBy;
  final DateTime createdAt;
  final DateTime modifiedAt;

  const IngredientModel({
    required this.id,
    required this.name,
    this.allergens = const [],
    this.isDeleted = false,
    required this.createdBy,
    required this.createdAt,
    required this.modifiedAt,
  });

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'allergens': allergens,
        'isDeleted': isDeleted,
        'createdBy': createdBy,
        'createdAt': Timestamp.fromDate(createdAt),
        'modifiedAt': Timestamp.fromDate(modifiedAt),
      };

  Map<String, dynamic> toMap() => {
        'name': name,
        'allergens': allergens,
        'isDeleted': isDeleted,
        'createdBy': createdBy,
        'createdAt': createdAt.toIso8601String(),
        'modifiedAt': modifiedAt.toIso8601String(),
      };

  factory IngredientModel.fromMap(String id, Map<String, dynamic> d) {
    final createdAt = d['createdAt'] != null
        ? DateTime.parse(d['createdAt'] as String)
        : DateTime.now();
    return IngredientModel(
      id: id,
      name: d['name'] as String? ?? '',
      allergens: List<String>.from(d['allergens'] ?? []),
      isDeleted: d['isDeleted'] as bool? ?? false,
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: createdAt,
      modifiedAt: d['modifiedAt'] != null
          ? DateTime.parse(d['modifiedAt'] as String)
          : createdAt,
    );
  }

  factory IngredientModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return IngredientModel(
      id: doc.id,
      name: d['name'] as String? ?? '',
      allergens: List<String>.from(d['allergens'] ?? []),
      isDeleted: d['isDeleted'] as bool? ?? false,
      createdBy: d['createdBy'] as String? ?? '',
      createdAt:
          (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      modifiedAt:
          (d['modifiedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
