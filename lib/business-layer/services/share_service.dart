import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'notification_prefs_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SHARE SERVICE
//
// Handles all social Firestore operations:
//
//   VISIBILITY CONTROL
//   ──────────────────
//   setVisibility()              → publishes or unpublishes a deck; mirrors a
//                                  summary doc to public_decks/{deckId}
//
//   CLONE
//   ─────
//   cloneDeck()                  → copies a public deck + its cards into the
//                                  current user's library; notifies the deck
//                                  owner ("deck_cloned")
//
//   FOLLOW GRAPH
//   ────────────
//   follow()                     → writes both sides of the follow relationship;
//                                  notifies the followee ("new_follower")
//   unfollow()                   → deletes both sides in a batched write
//
//   NOTIFICATIONS
//   ─────────────
//   fanOutNewDeckNotification()  → writes one notification doc per follower
//                                  when the owner publishes a new deck
//   (deck_cloned / new_follower notifications are written inline by
//   cloneDeck() / follow() via private helpers, fire-and-forget)
//
// All methods are static; the class is never instantiated.
//
// Firestore paths touched:
//   users/{uid}/decks/{deckId}
//   public_decks/{deckId}
//   users/{uid}/following/{followeeUid}
//   users/{uid}/followers/{followerUid}
//   users/{uid}/notifications/{notificationId}
// ─────────────────────────────────────────────────────────────────────────────

abstract final class ShareService {
  // ── Helpers ──────────────────────────────────────────────────────────────

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static String get _uid {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('User is not signed in.');
    return uid;
  }

  // ── SET VISIBILITY ────────────────────────────────────────────────────────

  /// Publishes or unpublishes a completed deck.
  ///
  /// - [deckId]     Firestore ID of the deck to update.
  /// - [visibility] Either `"public"` or `"private"`.
  ///
  /// Throws [StateError] if the deck is still a draft or if the deck is cloned.
  /// Throws [ArgumentError] if the deck already has the requested visibility.
  ///
  /// When setting `"public"`:
  ///   • Updates `users/{uid}/decks/{deckId}` with `visibility: "public"`.
  ///   • Writes a mirror doc to `public_decks/{deckId}` with discovery fields.
  ///
  /// When setting `"private"`:
  ///   • Updates `users/{uid}/decks/{deckId}` with `visibility: "private"`.
  ///   • Deletes `public_decks/{deckId}`.
  ///
  /// Both operations are committed in a single batched write.
  static Future<void> setVisibility({
    required String deckId,
    required String visibility,
  }) async {
    final uid = _uid;

    // ── Read current deck state ───────────────────────────────────────────
    final deckRef =
        _db.collection('users').doc(uid).collection('decks').doc(deckId);
    final deckSnap = await deckRef.get();

    if (!deckSnap.exists) {
      throw StateError('Deck not found.');
    }

    final deckData = deckSnap.data()!;
    debugPrint('[ShareService.setVisibility] deckData: $deckData');

    if (deckData['isDraft'] == true) {
      throw StateError('Cannot share a draft deck.');
    }

    // Prevent cloned decks from being made public
    if (visibility == 'public' && deckData['clonedFrom'] != null) {
      throw StateError(
          'Cannot share a cloned deck. Only original decks can be made public.');
    }

    final currentVisibility = deckData['visibility'] as String? ?? 'private';
    debugPrint(
        '[ShareService.setVisibility] currentVisibility=$currentVisibility, requested=$visibility');
    if (currentVisibility == visibility) {
      throw ArgumentError('Deck visibility is already "$visibility".');
    }

    // ── Read owner profile and real card count in parallel ────────────────
    final results = await Future.wait([
      _db.collection('users').doc(uid).get(),
      _db
          .collection('users')
          .doc(uid)
          .collection('decks')
          .doc(deckId)
          .collection('cards')
          .count()
          .get(),
    ]);

    debugPrint(
        '[ShareService.setVisibility] userSnap.exists=${(results[0] as DocumentSnapshot).exists}');
    final userData =
        (results[0] as DocumentSnapshot<Map<String, dynamic>>).data() ?? {};
    final ownerUsername = userData['username'] as String? ?? '';
    final ownerFullName = userData['fullName'] as String? ?? '';
    final ownerPhotoUrl = userData['photoUrl'] as String?;
    final realCardCount = (results[1] as AggregateQuerySnapshot).count ?? 0;

    // ── Batched write ─────────────────────────────────────────────────────
    final batch = _db.batch();
    final publicDeckRef = _db.collection('public_decks').doc(deckId);

    if (visibility == 'public') {
      // Update the private deck doc (also fix cardCount if it was missing)
      batch.update(deckRef, {
        'visibility': 'public',
        'cardCount': realCardCount,
      });

      // Write the public mirror document with the real card count
      batch.set(publicDeckRef, {
        'title': deckData['title'] as String? ?? '',
        'tag': deckData['tag'] as String? ?? '',
        'cardCount': realCardCount,
        'ownerUid': uid,
        'ownerUsername': ownerUsername,
        'ownerFullName': ownerFullName,
        'ownerPhotoUrl': ownerPhotoUrl,
        'sharedAt': FieldValue.serverTimestamp(),
        'cloneCount': 0,
      });
    } else {
      // Update the private deck doc
      batch.update(deckRef, {'visibility': 'private'});

      // Remove the public mirror document
      batch.delete(publicDeckRef);
    }

    await batch.commit();
  }

  // ── CLONE DECK ────────────────────────────────────────────────────────────

  /// Clones a public deck into the current user's library.
  ///
  /// - [sourceDeckId]   Firestore ID of the deck to clone.
  /// - [sourceOwnerUid] UID of the deck's original owner.
  ///
  /// Throws [StateError] if the source deck is not found or is no longer public.
  ///
  /// On success:
  ///   • Creates a new deck doc under `users/{currentUid}/decks/{newDeckId}`
  ///     with `isDraft: false`, `visibility: "private"`, `clonedFrom: sourceDeckId`.
  ///   • Copies all cards preserving `question`, `answer`, and `order`.
  ///   • Increments `cloneCount` on `public_decks/{sourceDeckId}`.
  ///   • Notifies [sourceOwnerUid] with a "deck_cloned" notification.
  ///
  /// Returns the new deck's Firestore document ID.
  static Future<String> cloneDeck({
    required String sourceDeckId,
    required String sourceOwnerUid,
  }) async {
    final currentUid = _uid;

    // ── Verify the source deck is still public ────────────────────────────
    final publicDeckSnap =
        await _db.collection('public_decks').doc(sourceDeckId).get();

    if (!publicDeckSnap.exists) {
      throw StateError('Deck is no longer available.');
    }

    final publicData = publicDeckSnap.data()!;

    // ── Fetch source cards ────────────────────────────────────────────────
    // Try ordered first; fall back to unordered if 'order' field is missing
    // (e.g. cards created by the AI import before the field was added).
    QuerySnapshot<Map<String, dynamic>> cardsSnap;
    try {
      cardsSnap = await _db
          .collection('users')
          .doc(sourceOwnerUid)
          .collection('decks')
          .doc(sourceDeckId)
          .collection('cards')
          .orderBy('order')
          .get();
    } catch (_) {
      cardsSnap = await _db
          .collection('users')
          .doc(sourceOwnerUid)
          .collection('decks')
          .doc(sourceDeckId)
          .collection('cards')
          .get();
    }

    // If orderBy succeeded but returned nothing, retry without ordering
    // (happens when no document in the collection has the 'order' field).
    if (cardsSnap.docs.isEmpty) {
      cardsSnap = await _db
          .collection('users')
          .doc(sourceOwnerUid)
          .collection('decks')
          .doc(sourceDeckId)
          .collection('cards')
          .get();
    }

    // ── Build the new deck reference ──────────────────────────────────────
    final newDeckRef =
        _db.collection('users').doc(currentUid).collection('decks').doc();

    final batch = _db.batch();

    // Write the new deck document
    batch.set(newDeckRef, {
      'title': publicData['title'] as String? ?? '',
      'tag': publicData['tag'] as String? ?? '',
      'isDraft': false,
      'visibility': 'private',
      'clonedFrom': sourceDeckId,
      'clonedFromUsername': publicData['ownerFullName'] as String? ?? '',
      'cardCount': cardsSnap.docs.length,
      'targetCardCount': cardsSnap.docs.length,
      'progress': 0.0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Copy each card into the new deck's sub-collection
    for (int i = 0; i < cardsSnap.docs.length; i++) {
      final cardData = cardsSnap.docs[i].data();
      final newCardRef = newDeckRef.collection('cards').doc();
      batch.set(newCardRef, {
        'question': cardData['question'] ?? '',
        'answer': cardData['answer'] ?? '',
        'order': cardData['order'] ?? i, // fall back to index if field missing
      });
    }

    // Increment cloneCount on the public mirror document
    batch.update(
      _db.collection('public_decks').doc(sourceDeckId),
      {'cloneCount': FieldValue.increment(1)},
    );

    await batch.commit();

    // ── Notify the deck owner that their deck was cloned ───────────────────
    // Fire-and-forget; a notification failure should never fail the clone
    // itself, and we never notify someone about their own clone of their
    // own deck (shouldn't happen since you can't clone your own public
    // deck via the UI, but guarded here for safety).
    if (sourceOwnerUid != currentUid) {
      _notifyDeckCloned(
        ownerUid: sourceOwnerUid,
        clonerUid: currentUid,
        deckId: sourceDeckId,
        deckTitle: publicData['title'] as String? ?? '',
      );
    }

    return newDeckRef.id;
  }

  /// Writes a "deck_cloned" notification to [ownerUid] letting them know
  /// [clonerUid] cloned their deck. Fire-and-forget; errors are silent so a
  /// notification hiccup never surfaces as a clone failure to the user.
  ///
  /// Skipped entirely (no doc written) if [ownerUid] has turned off
  /// "deck_cloned" notifications in Settings.
  static Future<void> _notifyDeckCloned({
    required String ownerUid,
    required String clonerUid,
    required String deckId,
    required String deckTitle,
  }) async {
    try {
      final enabled = await NotificationPrefsService.isEnabledFor(
        uid: ownerUid,
        type: NotificationType.deckCloned,
      );
      if (!enabled) return;

      final clonerSnap = await _db.collection('users').doc(clonerUid).get();
      final clonerFullName =
          clonerSnap.data()?['fullName'] as String? ?? 'Someone';

      await _db
          .collection('users')
          .doc(ownerUid)
          .collection('notifications')
          .add({
        'type': 'deck_cloned',
        'fromUid': clonerUid,
        'fromUsername': clonerFullName,
        'deckId': deckId,
        'deckTitle': deckTitle,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (_) {
      // Silently ignore — notification is best-effort
    }
  }

  // ── FOLLOW ────────────────────────────────────────────────────────────────

  /// Creates a follow relationship from [followerUid] to [followeeUid].
  ///
  /// Throws [ArgumentError] if a user attempts to follow themselves.
  ///
  /// Writes:
  ///   • `users/{followerUid}/following/{followeeUid}` with `createdAt`
  ///   • `users/{followeeUid}/followers/{followerUid}` with `createdAt`
  ///
  /// Notifies [followeeUid] directly with a "new_follower" notification.
  ///
  /// Fan-out: if the followee has any public decks, also writes one
  /// "new_shared_deck" notification doc per existing follower of the
  /// followee (skipped when no public decks exist).
  static Future<void> follow({
    required String followerUid,
    required String followeeUid,
  }) async {
    if (followerUid == followeeUid) {
      throw ArgumentError('Cannot follow yourself.');
    }

    final batch = _db.batch();
    final now = FieldValue.serverTimestamp();

    // Write both sides of the follow relationship
    batch.set(
      _db
          .collection('users')
          .doc(followerUid)
          .collection('following')
          .doc(followeeUid),
      {'createdAt': now},
    );

    batch.set(
      _db
          .collection('users')
          .doc(followeeUid)
          .collection('followers')
          .doc(followerUid),
      {'createdAt': now},
    );

    await batch.commit();

    // ── Notify the followee that they have a new follower ─────────────────
    // Fire-and-forget; independent of the public-deck fan-out below, so it
    // still fires even when the followee has no public decks to fan out.
    _notifyNewFollower(
      followeeUid: followeeUid,
      followerUid: followerUid,
    );

    // ── Fan-out: notify existing followers of the followee's latest deck ──
    // Check if the followee has any public decks to notify about.
    final publicDecksSnap = await _db
        .collection('public_decks')
        .where('ownerUid', isEqualTo: followeeUid)
        .orderBy('sharedAt', descending: true)
        .limit(1)
        .get();

    if (publicDecksSnap.docs.isEmpty) return;

    final latestDeck = publicDecksSnap.docs.first;
    final latestDeckData = latestDeck.data();

    // Read the followee's full name for the notification
    final followeeSnap = await _db.collection('users').doc(followeeUid).get();
    final followeeFullName = followeeSnap.data()?['fullName'] as String? ?? '';

    // Read all current followers of the followee
    final followersSnap = await _db
        .collection('users')
        .doc(followeeUid)
        .collection('followers')
        .get();

    if (followersSnap.docs.isEmpty) return;

    final fanOutBatch = _db.batch();

    for (final followerDoc in followersSnap.docs) {
      final fUid = followerDoc.id;

      // Independent per-recipient check: a follower who has turned off
      // "new_shared_deck" notifications simply gets no doc written for them,
      // while everyone else in the fan-out is unaffected.
      final enabled = await NotificationPrefsService.isEnabledFor(
        uid: fUid,
        type: NotificationType.newSharedDeck,
      );
      if (!enabled) continue;

      final notifRef =
          _db.collection('users').doc(fUid).collection('notifications').doc();

      fanOutBatch.set(notifRef, {
        'type': 'new_shared_deck',
        'fromUid': followeeUid,
        'fromUsername': followeeFullName,
        'deckId': latestDeck.id,
        'deckTitle': latestDeckData['title'] as String? ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    }

    await fanOutBatch.commit();
  }

  /// Writes a "new_follower" notification to [followeeUid] letting them know
  /// [followerUid] just followed them. Fire-and-forget; errors are silent so
  /// a notification hiccup never surfaces as a follow failure to the user.
  ///
  /// Skipped entirely (no doc written) if [followeeUid] has turned off
  /// "new_follower" notifications in Settings.
  static Future<void> _notifyNewFollower({
    required String followeeUid,
    required String followerUid,
  }) async {
    try {
      final enabled = await NotificationPrefsService.isEnabledFor(
        uid: followeeUid,
        type: NotificationType.newFollower,
      );
      if (!enabled) return;

      final followerSnap = await _db.collection('users').doc(followerUid).get();
      final followerFullName =
          followerSnap.data()?['fullName'] as String? ?? 'Someone';

      await _db
          .collection('users')
          .doc(followeeUid)
          .collection('notifications')
          .add({
        'type': 'new_follower',
        'fromUid': followerUid,
        'fromUsername': followerFullName,
        'deckId': '',
        'deckTitle': '',
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (_) {
      // Silently ignore — notification is best-effort
    }
  }

  // ── UNFOLLOW ──────────────────────────────────────────────────────────────

  /// Removes the follow relationship between [followerUid] and [followeeUid].
  ///
  /// Deletes both sub-collection documents in a single batched write:
  ///   • `users/{followerUid}/following/{followeeUid}`
  ///   • `users/{followeeUid}/followers/{followerUid}`
  static Future<void> unfollow({
    required String followerUid,
    required String followeeUid,
  }) async {
    final batch = _db.batch();

    batch.delete(
      _db
          .collection('users')
          .doc(followerUid)
          .collection('following')
          .doc(followeeUid),
    );

    batch.delete(
      _db
          .collection('users')
          .doc(followeeUid)
          .collection('followers')
          .doc(followerUid),
    );

    await batch.commit();
  }

  // ── FAN-OUT NEW DECK NOTIFICATION ─────────────────────────────────────────

  /// Writes one notification document per follower when [ownerUid] publishes
  /// a new deck.
  ///
  /// Called by the UI after [setVisibility] succeeds when setting `"public"`.
  ///
  /// Reads `users/{ownerUid}/followers` and writes to
  /// `users/{followerUid}/notifications/{notificationId}` for each follower
  /// in a single batched write.
  ///
  /// No-ops silently if the owner has no followers.
  static Future<void> fanOutNewDeckNotification({
    required String ownerUid,
    required String deckId,
    required String deckTitle,
    required String ownerFullName,
  }) async {
    final followersSnap = await _db
        .collection('users')
        .doc(ownerUid)
        .collection('followers')
        .get();

    if (followersSnap.docs.isEmpty) return;

    final batch = _db.batch();

    for (final followerDoc in followersSnap.docs) {
      final followerUid = followerDoc.id;

      // Independent per-recipient check — same as the fan-out inside
      // follow(); a follower who disabled this type gets no doc, others
      // are unaffected.
      final enabled = await NotificationPrefsService.isEnabledFor(
        uid: followerUid,
        type: NotificationType.newSharedDeck,
      );
      if (!enabled) continue;

      final notifRef = _db
          .collection('users')
          .doc(followerUid)
          .collection('notifications')
          .doc();

      batch.set(notifRef, {
        'type': 'new_shared_deck',
        'fromUid': ownerUid,
        'fromUsername': ownerFullName,
        'deckId': deckId,
        'deckTitle': deckTitle,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    }

    await batch.commit();
  }

  // ── REPAIR CARD COUNTS ────────────────────────────────────────────────────

  /// Fixes stale `cardCount: 0` on all public_decks docs owned by [uid].
  ///
  /// Call this once after the user has already-public decks with wrong counts.
  /// For each public deck owned by the user, counts the real cards and updates
  /// both the mirror doc and the private deck doc.
  static Future<void> repairCardCounts({required String uid}) async {
    final publicDecksSnap = await _db
        .collection('public_decks')
        .where('ownerUid', isEqualTo: uid)
        .get();

    if (publicDecksSnap.docs.isEmpty) return;

    for (final mirrorDoc in publicDecksSnap.docs) {
      final deckId = mirrorDoc.id;

      final countSnap = await _db
          .collection('users')
          .doc(uid)
          .collection('decks')
          .doc(deckId)
          .collection('cards')
          .count()
          .get();

      final realCount = countSnap.count ?? 0;
      final storedCount = (mirrorDoc.data()['cardCount'] as num?)?.toInt() ?? 0;

      if (realCount != storedCount) {
        final batch = _db.batch();
        batch.update(mirrorDoc.reference, {'cardCount': realCount});
        batch.update(
          _db.collection('users').doc(uid).collection('decks').doc(deckId),
          {'cardCount': realCount},
        );
        await batch.commit();
        debugPrint(
            '[ShareService.repairCardCounts] $deckId: $storedCount → $realCount');
      }
    }
  }
}
