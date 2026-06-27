import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFICATION PREFERENCES SERVICE
//
// Lets a user independently turn each notification type on/off.
// Toggling one type never affects the others — every type is stored under
// its own key and checked in isolation.
//
// STORAGE
// ───────
//   users/{uid}.notificationPrefs = {
//     new_follower:      bool,
//     new_shared_deck:   bool,
//     deck_cloned:       bool,
//     profile_viewed:    bool,
//     username_changed:  bool,   ← NEW
//     bio_updated:       bool,   ← NEW
//     followed_new_deck: bool,   ← NEW (deck from followed account)
//   }
//
// Missing field/doc/map → defaults to enabled (true). This means existing
// users who have never opened the new Settings section keep receiving every
// notification type exactly as before.
//
// GATING
// ──────
// Every notification-creation call site calls [isEnabledFor] with the
// *recipient's* uid before writing a notification doc. If that single type
// is disabled for that recipient, creation is skipped entirely — no doc is
// written at all, so disabled types never even reach Firestore.
// ─────────────────────────────────────────────────────────────────────────────

/// All notification type identifiers. Also used as `AppNotification.type`
/// values and as the keys inside `notificationPrefs`.
abstract final class NotificationType {
  // ── Original 4 ───────────────────────────────────────────────────────────
  static const String newFollower = 'new_follower';
  static const String newSharedDeck = 'new_shared_deck';
  static const String deckCloned = 'deck_cloned';
  static const String profileViewed = 'profile_viewed';

  // ── Following-based activity (3 new) ─────────────────────────────────────
  /// Someone you follow changed their username.
  static const String usernameChanged = 'username_changed';

  /// Someone you follow updated their bio.
  static const String bioUpdated = 'bio_updated';

  /// Someone you follow published a new public deck
  /// (distinct from new_shared_deck which is the *owner's* perspective).
  static const String followedNewDeck = 'followed_new_deck';

  static const List<String> all = [
    newFollower,
    newSharedDeck,
    deckCloned,
    profileViewed,
    usernameChanged,
    bioUpdated,
    followedNewDeck,
  ];
}

abstract final class NotificationPrefsService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  /// Reads `notificationPrefs` for [uid] and returns whether [type] is
  /// currently enabled for that user. Defaults to `true` if the user, the
  /// map, or the specific key is missing.
  ///
  /// Used as a gate immediately before writing any notification document.
  static Future<bool> isEnabledFor({
    required String uid,
    required String type,
  }) async {
    try {
      final snap = await _db.collection('users').doc(uid).get();
      final prefs = snap.data()?['notificationPrefs'] as Map<String, dynamic>?;
      if (prefs == null) return true;
      return prefs[type] as bool? ?? true;
    } catch (_) {
      // If the read fails, fail open — a missed toggle check should never
      // block a notification that would otherwise be wanted.
      return true;
    }
  }

  /// Streams the current user's full notification-preferences map, with all
  /// keys always present (defaulting missing ones to `true`). Used by the
  /// Settings screen so toggles reflect Firestore in real time.
  static Stream<Map<String, bool>> watchOwnPrefs() {
    final uid = _currentUid;
    if (uid == null) return Stream.value(_defaults());

    return _db.collection('users').doc(uid).snapshots().map((snap) {
      final stored = snap.data()?['notificationPrefs'] as Map<String, dynamic>?;
      return _withDefaults(stored);
    });
  }

  /// Sets a single notification type on/off for the current user. Only the
  /// given [type] key is written — all other types are left completely
  /// untouched, so turning one off/on never affects the others.
  static Future<void> setEnabled({
    required String type,
    required bool enabled,
  }) async {
    final uid = _currentUid;
    if (uid == null) return;

    await _db.collection('users').doc(uid).set({
      'notificationPrefs': {type: enabled},
    }, SetOptions(merge: true));
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static Map<String, bool> _defaults() => {
        for (final t in NotificationType.all) t: true,
      };

  static Map<String, bool> _withDefaults(Map<String, dynamic>? stored) {
    final result = _defaults();
    if (stored == null) return result;
    for (final t in NotificationType.all) {
      result[t] = stored[t] as bool? ?? true;
    }
    return result;
  }
}
