import 'package:cloud_firestore/cloud_firestore.dart';

class ChildModel {
  final String id;
  final String name;
  final DateTime dateOfBirth;
  final String notes;
  final DateTime createdAt;

  ChildModel({
    required this.id,
    required this.name,
    required this.dateOfBirth,
    this.notes = '',
    required this.createdAt,
  });

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'dateOfBirth': Timestamp.fromDate(dateOfBirth),
        'notes': notes,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory ChildModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return ChildModel(
      id: doc.id,
      name: d['name'] as String? ?? '',
      dateOfBirth:
          (d['dateOfBirth'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notes: d['notes'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
