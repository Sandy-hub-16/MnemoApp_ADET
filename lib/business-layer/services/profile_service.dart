import 'package:cloud_firestore/cloud_firestore.dart';

import '../../data-layer/models/social/public_deck_summary.dart';
import '../../data-layer/models/social/public_profile.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PROFILE SERVICE
//
// Read-only service for fetching public user data.  All methods are static;
// the class is never instantiated.
//
// DATA PATHS
// ──────────
//   getProfile()      → reads users/{targetUid}
//                       returns PublicProfile (fullName, username, photoUrl)
//                       throws StateError if the document does not exist
//
//   userDecksStream() → listens to public_decks where ownerUid == targetUid,
//                       ordered by sharedAt descending
//                       emits List<PublicDeckSummary> on every snapshot
//
// Requirements: 5.1, 5.2, 5.3, 5.5
// ─────────────────────────────────────────────────────────────────────────────

abstract final class ProfileService {
  // ── Helpers ──────────────────────────────────────────────────────────────

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  // ── GET PROFILE ───────────────────────────────────────────────────────────

  /// Fetches the public profile fields for [targetUid].
  ///
  /// Reads `users/{targetUid}` and returns a [PublicProfile] containing
  /// `fullName`, `username`, and `photoUrl`.
  ///
  /// Throws [StateError] if no document exists for [targetUid].
  ///
  /// Requirements: 5.1, 5.5
  static Future<PublicProfile> getProfile(String targetUid) async {
    final doc = await _db.collection('users').doc(targetUid).get();

    if (!doc.exists) {
      throw StateError('User not found.');
    }

    return PublicProfile.fromFirestore(doc);
  }

  // ── USER DECKS STREAM ─────────────────────────────────────────────────────

  /// Returns a real-time stream of all public decks owned by [targetUid].
  ///
  /// Queries `public_decks` where `ownerUid == targetUid`, ordered by
  /// `sharedAt` descending.  Each snapshot is mapped to a
  /// `List<PublicDeckSummary>`.
  ///
  /// Requirements: 5.2, 5.3
  static Stream<List<PublicDeckSummary>> userDecksStream(String targetUid) {
    return _db
        .collection('public_decks')
        .where('ownerUid', isEqualTo: targetUid)
        .orderBy('sharedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(PublicDeckSummary.fromFirestore)
              .toList(),
        );
  }
}
