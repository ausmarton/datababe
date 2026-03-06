import 'package:cloud_firestore/cloud_firestore.dart';

class ChildModel {
  final String id;
  final String name;
  final DateTime dateOfBirth;
  final String notes;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final bool isDeleted;

  ChildModel({
    required this.id,
    required this.name,
    required this.dateOfBirth,
    this.notes = '',
    required this.createdAt,
    required this.modifiedAt,
    this.isDeleted = false,
  });

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'dateOfBirth': Timestamp.fromDate(dateOfBirth),
        'notes': notes,
        'createdAt': Timestamp.fromDate(createdAt),
        'modifiedAt': Timestamp.fromDate(modifiedAt),
        'isDeleted': isDeleted,
      };

  Map<String, dynamic> toMap() => {
        'name': name,
        'dateOfBirth': dateOfBirth.toIso8601String(),
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'modifiedAt': modifiedAt.toIso8601String(),
        'isDeleted': isDeleted,
      };

  factory ChildModel.fromMap(String id, Map<String, dynamic> d) {
    final createdAt = d['createdAt'] != null
        ? DateTime.parse(d['createdAt'] as String)
        : DateTime.now();
    return ChildModel(
      id: id,
      name: d['name'] as String? ?? '',
      dateOfBirth: d['dateOfBirth'] != null
          ? DateTime.parse(d['dateOfBirth'] as String)
          : DateTime.now(),
      notes: d['notes'] as String? ?? '',
      createdAt: createdAt,
      modifiedAt: d['modifiedAt'] != null
          ? DateTime.parse(d['modifiedAt'] as String)
          : createdAt,
      isDeleted: d['isDeleted'] as bool? ?? false,
    );
  }

  factory ChildModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    final createdAt =
        (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    return ChildModel(
      id: doc.id,
      name: d['name'] as String? ?? '',
      dateOfBirth:
          (d['dateOfBirth'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notes: d['notes'] as String? ?? '',
      createdAt: createdAt,
      modifiedAt:
          (d['modifiedAt'] as Timestamp?)?.toDate() ?? createdAt,
      isDeleted: d['isDeleted'] as bool? ?? false,
    );
  }
}
