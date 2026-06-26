import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFICATION PREFERENCES SERVICE
//
// Lets a user independently turn each of the 4 notification types on/off.
// Toggling one type never affects the other 3 — every type is stored under
// its own key and checked in isolation.
//
// STORAGE
// ───────
//   users/{uid}.notificationPrefs = {
//     new_follower:    bool,
//     new_shared_deck: bool,
//     deck_cloned:     bool,
//     profile_viewed:  bool,
//   }
//
// Missing field/doc/map → defaults to enabled (true). This means existing
// users who have never opened the new Settings section keep receiving every
// notification type exactly as before — nothing changes until they explicitly
// flip a toggle off.
//
// GATING
// ──────
// Every notification-creation call site (in ShareService and
// PublicProfileScreen) calls [isEnabledFor] with the *recipient's* uid before
// writing a notification doc. If that single type is disabled for that
// recipient, creation is skipped entirely — no doc is written at all, so
// disabled types never even reach Firestore.
// ─────────────────────────────────────────────────────────────────────────────

/// The 4 notification type identifiers also used as `AppNotification.type`
/// values and as the keys inside `notificationPrefs`.
abstract final class NotificationType {
  static const String newFollower = 'new_follower';
  static const String newSharedDeck = 'new_shared_deck';
  static const String deckCloned = 'deck_cloned';
  static const String profileViewed = 'profile_viewed';

  static const List<String> all = [
    newFollower,
    newSharedDeck,
    deckCloned,
    profileViewed,
  ];
}

abstract final class NotificationPrefsService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  /// Reads `notificationPrefs` for [uid] and returns whether [type] is
  /// currently enabled for that user. Defaults to `true` if the user, the
  /// map, or the specific key is missing — so a brand-new user (or one who
  /// signed up before this feature existed) receives notifications normally
  /// until they explicitly opt out.
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
  /// 4 keys always present (defaulting missing ones to `true`). Used by the
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
  /// given [type] key is written — the other 3 types are left completely
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
