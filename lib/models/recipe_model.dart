import 'package:cloud_firestore/cloud_firestore.dart';

class RecipeModel {
  final String id;
  final String name;
  final List<String> ingredients;
  final bool isDeleted;
  final String createdBy;
  final DateTime createdAt;
  final DateTime modifiedAt;

  const RecipeModel({
    required this.id,
    required this.name,
    required this.ingredients,
    this.isDeleted = false,
    required this.createdBy,
    required this.createdAt,
    required this.modifiedAt,
  });

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'ingredients': ingredients,
        'isDeleted': isDeleted,
        'createdBy': createdBy,
        'createdAt': Timestamp.fromDate(createdAt),
        'modifiedAt': Timestamp.fromDate(modifiedAt),
      };

  Map<String, dynamic> toMap() => {
        'name': name,
        'ingredients': ingredients,
        'isDeleted': isDeleted,
        'createdBy': createdBy,
        'createdAt': createdAt.toIso8601String(),
        'modifiedAt': modifiedAt.toIso8601String(),
      };

  factory RecipeModel.fromMap(String id, Map<String, dynamic> d) {
    return RecipeModel(
      id: id,
      name: d['name'] as String? ?? '',
      ingredients: (d['ingredients'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      isDeleted: d['isDeleted'] as bool? ?? false,
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: DateTime.parse(d['createdAt'] as String),
      modifiedAt: DateTime.parse(d['modifiedAt'] as String),
    );
  }

  factory RecipeModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return RecipeModel(
      id: doc.id,
      name: d['name'] as String? ?? '',
      ingredients: (d['ingredients'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      isDeleted: d['isDeleted'] as bool? ?? false,
      createdBy: d['createdBy'] as String? ?? '',
      createdAt:
          (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      modifiedAt:
          (d['modifiedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
