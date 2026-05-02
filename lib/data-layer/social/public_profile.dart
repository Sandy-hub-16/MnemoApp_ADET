import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PUBLIC PROFILE
//
// Read-only view of another user's identity fields, sourced from
// users/{targetUid}.  Only the fields that are safe to expose publicly
// are included here.
// ─────────────────────────────────────────────────────────────────────────────

class PublicProfile {
  const PublicProfile({
    required this.uid,
    required this.fullName,
    required this.username,
    this.photoUrl,
  });

  final String uid;
  final String fullName;
  final String username;
  final String? photoUrl;

  // ── Firestore deserialization ─────────────────────────────────────────────

  factory PublicProfile.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return PublicProfile(
      uid: doc.id,
      fullName: data['fullName'] as String? ?? '',
      username: data['username'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
    );
  }
}
