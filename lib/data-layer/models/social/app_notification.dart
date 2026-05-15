import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// APP NOTIFICATION
//
// In-app notification document stored at
// users/{uid}/notifications/{notificationId}.
// Currently only the "new_shared_deck" type is used, but the `type` field
// is kept as a plain String to allow future notification types without a
// breaking model change.
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
