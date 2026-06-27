import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// APP NOTIFICATION
//
// In-app notification document stored at
// users/{uid}/notifications/{notificationId}.
//
// Current `type` values (7 total):
//   Original 4
//   ───────────
//   • "new_shared_deck"   — someone you follow published a new public deck
//   • "profile_viewed"    — someone viewed your public profile
//   • "deck_cloned"       — someone cloned one of your public decks
//   • "new_follower"      — someone followed you
//
//   Following-based activity (3 new)
//   ──────────────────────────────────
//   • "username_changed"  — someone you follow changed their username
//   • "bio_updated"       — someone you follow updated their bio
//   • "followed_new_deck" — someone you follow published a new public deck
//                           (fan-out from the sharer's side; recipient sees it
//                            as "someone you follow shared a deck")
//
// `deckId` / `deckTitle` are empty strings for types with no associated deck.
// `oldValue` carries the previous username for "username_changed", and is an
// empty string for all other types.
// `type` is kept as a plain String to allow future types without a breaking
// model change.
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
    this.oldValue = '',
  });

  final String notificationId;

  /// Notification type identifier — e.g. "username_changed".
  final String type;

  final String fromUid;
  final String fromUsername;
  final String deckId;
  final String deckTitle;
  final DateTime createdAt;
  final bool read;

  /// For "username_changed": the previous username (before the change).
  /// Empty string for all other notification types.
  final String oldValue;

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
      oldValue: data['oldValue'] as String? ?? '',
    );
  }
}
