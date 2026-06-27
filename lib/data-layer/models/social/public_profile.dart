import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PUBLIC PROFILE
//
// Read-only view of another user's identity fields, sourced from
// users/{targetUid}.  Only the fields that are safe to expose publicly
// are included here.
//
// Extended with bio/about fields so the PublicProfileScreen can render a
// full-fidelity profile card when the account is public, matching the
// same layout used by the owner's own ProfileScreen.
// ─────────────────────────────────────────────────────────────────────────────

class PublicProfile {
  const PublicProfile({
    required this.uid,
    required this.fullName,
    required this.username,
    this.photoUrl,
    this.isPrivate = false,
    this.bio = '',
    this.school = '',
    this.course = '',
    this.yearLevel = '',
    this.region = '',
    this.createdAt,
  });

  final String uid;
  final String fullName;
  final String username;
  final String? photoUrl;
  final bool isPrivate;

  // ── Extended fields shown when the account is public ─────────────────────
  final String bio;
  final String school;
  final String course;
  final String yearLevel;
  final String region;
  final Timestamp? createdAt;

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
      isPrivate: data['isPrivate'] as bool? ?? false,
      bio: data['bio'] as String? ?? '',
      school: data['school'] as String? ?? '',
      course: data['course'] as String? ?? '',
      yearLevel: data['yearLevel'] as String? ?? '',
      region: data['region'] as String? ?? '',
      createdAt: data['createdAt'] as Timestamp?,
    );
  }
}
