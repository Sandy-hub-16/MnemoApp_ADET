import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// APP NOTIFICATION
//
// In-app notification document stored at
// users/{uid}/notifications/{notificationId}.
//
// Current `type` values:
//   • "new_shared_deck" — someone you follow published a new public deck
//   • "profile_viewed"  — someone viewed your public profile
//   • "deck_cloned"     — someone cloned one of your public decks
//   • "new_follower"    — someone followed you
//
// `deckId` / `deckTitle` are empty strings for types with no associated
// deck (profile_viewed, new_follower). `type` is kept as a plain String to
// allow future notification types without a breaking model change.
// ─────────────────────────────────────────────────────────────────────────────

class AppNotification {
  const AppNotification({
    required this.notificationId,
    required this.type,
    required this.fromUid,
    required this.fromUsername,
    required this.deckId,
    required this.deckTitle,
    required this.createdAt,
    required this.read,
  });

  final String notificationId;

  /// Notification type identifier — e.g. "new_shared_deck".
  final String type;

  final String fromUid;
  final String fromUsername;
  final String deckId;
  final String deckTitle;
  final DateTime createdAt;
  final bool read;

  // ── Firestore deserialization ─────────────────────────────────────────────

  factory AppNotification.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return AppNotification(
      notificationId: doc.id,
      type: data['type'] as String? ?? '',
      fromUid: data['fromUid'] as String? ?? '',
      fromUsername: data['fromUsername'] as String? ?? '',
      deckId: data['deckId'] as String? ?? '',
      deckTitle: data['deckTitle'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      read: data['read'] as bool? ?? false,
    );
  }
}
