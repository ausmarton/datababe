import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final List<String> familyIds;
  final DateTime createdAt;

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.familyIds,
    required this.createdAt,
  });

  Map<String, dynamic> toFirestore() => {
        'email': email,
        'displayName': displayName,
        'familyIds': familyIds,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory AppUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return AppUser(
      uid: doc.id,
      email: d['email'] as String? ?? '',
      displayName: d['displayName'] as String? ?? '',
      familyIds: List<String>.from(d['familyIds'] ?? []),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
