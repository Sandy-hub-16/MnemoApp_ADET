import 'package:cloud_firestore/cloud_firestore.dart';

import '../../data-layer/social/public_deck_summary.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FEED SERVICE
//
// Assembles the Social Feed for a given user.
//
// DATA PATH
// ─────────
//   1. Read  users/{currentUid}/following          → list of followee UIDs
//   2. Query public_decks where ownerUid in [...]  → up to 50 docs, ordered
//      by sharedAt descending
//
// LIFECYCLE
// ─────────
//   feedStream() opens a real-time Firestore listener.  The caller is
//   responsible for cancelling the subscription (e.g. in dispose()).
//   When the following list is empty the stream immediately emits [] and
//   no public_decks listener is opened.
// ─────────────────────────────────────────────────────────────────────────────

abstract final class FeedService {
  // ── Helpers ──────────────────────────────────────────────────────────────

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  // ── FEED STREAM ───────────────────────────────────────────────────────────

  /// Returns a real-time stream of up to 50 [PublicDeckSummary] documents
  /// from users the [currentUid] follows, ordered by [sharedAt] descending.
  ///
  /// Emits an empty list immediately when the user follows nobody.
  static Stream<List<PublicDeckSummary>> feedStream(String currentUid) async* {
    // ── Step 1: fetch the following sub-collection (one-time read) ──────────
    final followingSnap = await _db
        .collection('users')
        .doc(currentUid)
        .collection('following')
        .get();

    final followeeUids =
        followingSnap.docs.map((doc) => doc.id).toList();

    // ── Step 2: guard — no followees → emit empty list and stop ─────────────
    if (followeeUids.isEmpty) {
      yield [];
      return;
    }

    // ── Step 3: open real-time listener on public_decks ──────────────────────
    //
    // Firestore's `whereIn` supports up to 30 values per query.
    // For the expected scale of a study app this is sufficient; a chunked
    // merge strategy would be added if follower counts grow beyond 30.
    final query = _db
        .collection('public_decks')
        .where('ownerUid', whereIn: followeeUids)
        .orderBy('sharedAt', descending: true)
        .limit(50);

    yield* query.snapshots().map(
          (snapshot) => snapshot.docs
              .map(PublicDeckSummary.fromFirestore)
              .toList(),
        );
  }
}
