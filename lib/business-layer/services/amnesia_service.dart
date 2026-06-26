import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AMNESIA SERVICE
//
// Handles a full progress reset ("Amnesia") for the current user:
//   1. Deletes all quizAttempts, deckProgress, cardProgress, and
//      recentSessions subcollection documents.
//   2. Zeroes out progress fields on every deck document (progress,
//      quizAttemptCount, bestScore, lastQuizScore, lastStudiedAt).
//
// Decks and cards themselves are NOT touched — only progress data is wiped.
//
// Throws AmnesiaException with a user-facing message on any failure so
// the caller can display it without catching raw Firestore/Auth errors.
// ─────────────────────────────────────────────────────────────────────────────

class AmnesiaException implements Exception {
  AmnesiaException(this.message, {this.code});
  final String message;
  final String? code;

  @override
  String toString() => message;
}

class AmnesiaService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Main entry point ──────────────────────────────────────────────────────
  // Throws AmnesiaException with a user-facing message on any failure.
  // Caller is responsible for catching and displaying it.
  Future<void> resetAllProgress() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw AmnesiaException('No signed-in user found. Please sign in again.');
    }

    try {
      await _resetProgressData(user.uid);
    } on AmnesiaException {
      rethrow;
    } on FirebaseException catch (e) {
      // Surface the real Firestore error code so it's visible during debugging,
      // but show a clean message to the user.
      print('[AmnesiaService] FirebaseException: ${e.code} — ${e.message}');
      throw AmnesiaException(
        e.code == 'permission-denied'
            ? 'Permission denied. Please sign out and sign back in, then try again.'
            : 'A database error occurred (${e.code}). Please try again.',
        code: e.code,
      );
    } catch (e) {
      print('[AmnesiaService] Unexpected error: $e');
      throw AmnesiaException(
        'Something went wrong. Please try again.',
      );
    }
  }

  // ── Core reset logic ──────────────────────────────────────────────────────
  Future<void> _resetProgressData(String uid) async {
    final userRef = _db.collection('users').doc(uid);

    // 1) Delete all quiz attempt history.
    final attempts = await userRef.collection('quizAttempts').get();
    await _batchDelete(attempts.docs.map((d) => d.reference));

    // 2) Delete per-deck progress aggregates.
    final deckProgress = await userRef.collection('deckProgress').get();
    await _batchDelete(deckProgress.docs.map((d) => d.reference));

    // 3) Delete per-card mastery data.
    final cardProgress = await userRef.collection('cardProgress').get();
    await _batchDelete(cardProgress.docs.map((d) => d.reference));

    // 4) Delete recent activity sessions.
    final recentSessions = await userRef.collection('recentSessions').get();
    await _batchDelete(recentSessions.docs.map((d) => d.reference));

    // 5) Zero out progress fields on every deck doc.
    //    set+merge is used so this works even if the fields were never
    //    written before (batch.update throws on missing fields).
    final decks = await userRef.collection('decks').get();
    for (var i = 0; i < decks.docs.length; i += 450) {
      final chunk = decks.docs.skip(i).take(450);
      final batch = _db.batch();
      for (final doc in chunk) {
        batch.set(
          doc.reference,
          {
            'progress': 0.0,
            'quizAttemptCount': 0,
            'bestScore': 0.0,
            'lastQuizScore': 0.0,
            'lastStudiedAt': FieldValue.delete(),
          },
          SetOptions(merge: true),
        );
      }
      await batch.commit();
    }
  }

  // Firestore batch cap is 500 — chunk at 450 to be safe.
  Future<void> _batchDelete(Iterable<DocumentReference> refs) async {
    final list = refs.toList();
    if (list.isEmpty) return;

    for (var i = 0; i < list.length; i += 450) {
      final chunk = list.skip(i).take(450);
      final batch = _db.batch();
      for (final ref in chunk) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }
}
