import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RATE LIMIT SERVICE
// Client-side read-only mirror of the server's rate limit state.
// The server (generate-deck.js) is the source of truth and hard enforcer.
// This service is used only to gate the UI before dialogs are shown.
//
// Firestore path: users/{uid}/rateLimits/aiGeneration
//   dailyCount  : int       — number of generations used in the current window
//   windowStart : Timestamp — when the current 24-hour window started
// ─────────────────────────────────────────────────────────────────────────────

class RateLimitService {
  static const int dailyLimit = 5;
  static const Duration window = Duration(hours: 24);

  static const _rateLimitsCollection = 'rateLimits';
  static const _aiGenerationDoc = 'aiGeneration';

  static DocumentReference<Map<String, dynamic>> _ref(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection(_rateLimitsCollection)
          .doc(_aiGenerationDoc);

  /// Returns how many AI generations remain in the current window.
  /// Returns [dailyLimit] on any error so the server always has final say.
  static Future<int> getRemainingGenerations() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return 0;

      final snap = await _ref(uid).get();
      if (!snap.exists) return dailyLimit;

      final data = snap.data()!;
      final windowStart = (data['windowStart'] as Timestamp?)?.toDate();
      final count = (data['dailyCount'] as int?) ?? 0;

      if (windowStart == null) return dailyLimit;
      if (DateTime.now().difference(windowStart) >= window) return dailyLimit;

      return (dailyLimit - count).clamp(0, dailyLimit);
    } catch (_) {
      // On read failure, don't block the user — server will enforce.
      return dailyLimit;
    }
  }

  /// Returns when the current window resets, or null if no active window.
  static Future<DateTime?> getResetTime() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return null;

      final snap = await _ref(uid).get();
      if (!snap.exists) return null;

      final data = snap.data()!;
      final windowStart = (data['windowStart'] as Timestamp?)?.toDate();
      if (windowStart == null) return null;

      final reset = windowStart.add(window);
      return DateTime.now().isBefore(reset) ? reset : null;
    } catch (_) {
      return null;
    }
  }

  /// Real-time stream of remaining generations.
  /// Emits immediately when the server increments the counter after a generation.
  static Stream<int> remainingStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(0);

    return _ref(uid).snapshots().map((snap) {
      if (!snap.exists) return dailyLimit;
      final data = snap.data()!;
      final windowStart = (data['windowStart'] as Timestamp?)?.toDate();
      final count = (data['dailyCount'] as int?) ?? 0;
      if (windowStart == null) return dailyLimit;
      if (DateTime.now().difference(windowStart) >= window) return dailyLimit;
      return (dailyLimit - count).clamp(0, dailyLimit);
    });
  }
  
  /// Human-readable reset string, e.g. "in 3h 22m" or "in 45m".
  static String formatResetTime(DateTime? resetTime) {
    if (resetTime == null) return 'in 24 hours';
    final diff = resetTime.difference(DateTime.now());
    if (diff.inHours > 0) {
      return 'in ${diff.inHours}h ${diff.inMinutes.remainder(60)}m';
    }
    return 'in ${diff.inMinutes}m';
  }
}
