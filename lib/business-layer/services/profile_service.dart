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
//                       returns PublicProfile (all public fields)
//                       throws StateError if the document does not exist
//
//   getLibraryStats() → reads users/{targetUid}/decks and public_decks
//                       returns a _LibraryStats with deckCount, cardCount,
//                       sharedDeckCount (excludes drafts).
//
//   userDecksStream() → listens to public_decks where ownerUid == targetUid,
//                       ordered by sharedAt descending
//                       emits List<PublicDeckSummary> on every snapshot
//
// Requirements: 5.1, 5.2, 5.3, 5.5
// ─────────────────────────────────────────────────────────────────────────────

class PublicLibraryStats {
  const PublicLibraryStats({
    required this.deckCount,
    required this.cardCount,
    required this.sharedDeckCount,
  });

  /// Total non-draft decks.
  final int deckCount;

  /// Total cards across all non-draft decks.
  final int cardCount;

  /// Number of decks shared to the public feed.
  final int sharedDeckCount;
}

abstract final class ProfileService {
  // ── Helpers ──────────────────────────────────────────────────────────────

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  // ── GET PROFILE ───────────────────────────────────────────────────────────

  /// Fetches the public profile fields for [targetUid].
  ///
  /// Reads `users/{targetUid}` and returns a [PublicProfile] containing
  /// all publicly displayable fields (name, username, photo, bio, about,
  /// privacy flag).
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

  // ── LIBRARY STATS ─────────────────────────────────────────────────────────

  /// Reads the deck sub-collection of [targetUid] to compute:
  ///   • deckCount       — non-draft decks
  ///   • cardCount       — total cards across non-draft decks
  ///   • sharedDeckCount — decks mirrored to public_decks
  ///
  /// Drafts are intentionally excluded so viewers never see a user's
  /// draft count.
  static Future<PublicLibraryStats> getLibraryStats(String targetUid) async {
    final decksSnap =
        await _db.collection('users').doc(targetUid).collection('decks').get();

    int deckCount = 0;
    int cardCount = 0;

    for (final doc in decksSnap.docs) {
      final d = doc.data();
      if (d['isDraft'] == true) continue; // skip drafts
      deckCount++;
      if (d['cardCount'] is int) {
        cardCount += (d['cardCount'] as int);
      } else if (d['cards'] is List) {
        cardCount += (d['cards'] as List).length;
      }
    }

    final publicSnap = await _db
        .collection('public_decks')
        .where('ownerUid', isEqualTo: targetUid)
        .count()
        .get();

    return PublicLibraryStats(
      deckCount: deckCount,
      cardCount: cardCount,
      sharedDeckCount: publicSnap.count ?? 0,
    );
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
          (snapshot) =>
              snapshot.docs.map(PublicDeckSummary.fromFirestore).toList(),
        );
  }
}
