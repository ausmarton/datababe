import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;

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

  /// Create from Firebase Auth user. Only uid/email/displayName are available;
  /// familyIds are populated later via initial sync.
  factory AppUser.fromFirebaseUser(auth.User user) => AppUser(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName ?? '',
        familyIds: const [],
        createdAt: user.metadata.creationTime ?? DateTime.now(),
      );

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
