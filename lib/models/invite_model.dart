import 'package:cloud_firestore/cloud_firestore.dart';

import 'enums.dart';

class InviteModel {
  final String id;
  final String familyId;
  final String familyName;
  final String invitedByUid;
  final String invitedByName;
  final String inviteeEmail;
  final String role;
  final InviteStatus status;
  final DateTime createdAt;
  final DateTime? respondedAt;

  InviteModel({
    required this.id,
    required this.familyId,
    required this.familyName,
    required this.invitedByUid,
    required this.invitedByName,
    required this.inviteeEmail,
    required this.role,
    required this.status,
    required this.createdAt,
    this.respondedAt,
  });

  /// Deterministic ID: "{familyId}_{email}" — prevents duplicate invites.
  static String computeId(String familyId, String email) =>
      '${familyId}_${email.toLowerCase()}';

  Map<String, dynamic> toFirestore() => {
        'familyId': familyId,
        'familyName': familyName,
        'invitedByUid': invitedByUid,
        'invitedByName': invitedByName,
        'inviteeEmail': inviteeEmail,
        'role': role,
        'status': status.name,
        'createdAt': Timestamp.fromDate(createdAt),
        if (respondedAt != null)
          'respondedAt': Timestamp.fromDate(respondedAt!),
      };

  factory InviteModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return InviteModel(
      id: doc.id,
      familyId: d['familyId'] as String? ?? '',
      familyName: d['familyName'] as String? ?? '',
      invitedByUid: d['invitedByUid'] as String? ?? '',
      invitedByName: d['invitedByName'] as String? ?? '',
      inviteeEmail: d['inviteeEmail'] as String? ?? '',
      role: d['role'] as String? ?? 'carer',
      status: InviteStatus.values.byName(
        d['status'] as String? ?? 'pending',
      ),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      respondedAt: (d['respondedAt'] as Timestamp?)?.toDate(),
    );
  }
}
