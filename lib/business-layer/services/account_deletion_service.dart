import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

// ─────────────────────────────────────────────────────────────────────────────
// ACCOUNT DELETION SERVICE
//
// Handles full account deletion:
//   1. Re-authenticates the user with email + password (required by
//      Firebase before a sensitive op like delete()).
//   2. Cascades deletion/cleanup across every Firestore collection that
//      references the user (profile, decks, discover/public listings,
//      social graph, notifications, etc).
//   3. Records the email in a `deletedAccounts` ledger with a 7-day
//      cooldown so it can't be reused for a new signup until it expires.
//   4. Deletes the Firebase Auth user itself.
//
// IMPORTANT — read before treating this as a complete solution:
// Freeing up an email after a cooldown is a SERVER-SIDE concern. Firebase
// Auth itself has no concept of "reserved" emails — once a user is deleted
// from Auth, nothing stops a NEW createUserWithEmailAndPassword call with
// that same email from succeeding immediately, regardless of what this
// client writes to Firestore.
//
// The `deletedAccounts` ledger below is necessary but NOT sufficient on its
// own — it only blocks reuse through code paths that bother to check it
// (e.g. this app's own registration flow). A user could bypass it by
// calling Firebase Auth directly, or via the REST API.
//
// To make the cooldown airtight, pair this with a Cloud Function using the
// Auth Blocking Functions feature (`beforeCreate` trigger), which runs
// server-side on EVERY signup attempt regardless of client:
//
//   exports.beforeCreate = functions.auth.user().beforeCreate(async (user) => {
//     final hash = sha256(user.email.toLowerCase());
//     final doc = await db.collection('deletedAccounts').doc(hash).get();
//     if (doc.exists && doc.data().availableAt.toDate() > new Date()) {
//       throw new functions.auth.HttpsError('failed-precondition',
//         'This email is in a 7-day cooldown period.');
//     }
//   });
//
// Until that function exists, treat the client-side check in
// `checkEmailCooldown()` below as a UX nicety (fast, friendly error message)
// rather than a security boundary.
// ─────────────────────────────────────────────────────────────────────────────

class AccountDeletionException implements Exception {
  AccountDeletionException(this.message, {this.code});
  final String message;
  final String? code;

  @override
  String toString() => message;
}

class AccountDeletionService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const Duration cooldownDuration = Duration(days: 7);

  // Firestore doc IDs can't contain certain characters and we don't want to
  // store raw emails as plaintext keys forever — hash them.
  String _hashEmail(String email) {
    final normalized = email.trim().toLowerCase();
    return sha256.convert(utf8.encode(normalized)).toString();
  }

  // ── Pre-flight check used at registration time ────────────────────────────
  // Returns null if the email is free to use. Returns a user-facing message
  // if it's still inside the 7-day cooldown window.
  Future<String?> checkEmailCooldown(String email) async {
    final hash = _hashEmail(email);
    final doc = await _db.collection('deletedAccounts').doc(hash).get();

    if (!doc.exists) return null;

    final data = doc.data();
    final availableAt = (data?['availableAt'] as Timestamp?)?.toDate();
    if (availableAt == null) return null;

    final now = DateTime.now();
    if (now.isBefore(availableAt)) {
      final remaining = availableAt.difference(now);
      final days = remaining.inHours / 24;
      final daysLabel = days < 1
          ? 'less than a day'
          : '${days.ceil()} day${days.ceil() == 1 ? '' : 's'}';
      return 'This email was recently used on a deleted account. '
          'It will be available again in $daysLabel.';
    }

    return null;
  }

  // ── Main entry point ──────────────────────────────────────────────────────
  // Throws AccountDeletionException with a friendly message on any failure
  // (wrong password, network error, etc). Caller is responsible for
  // catching and displaying it.
  Future<void> deleteAccountCompletely({
    required String email,
    required String password,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw AccountDeletionException('No signed-in user found.');
    }

    // ── Step 1: Re-authenticate ────────────────────────────────────────────
    // Firebase requires a recent sign-in for destructive ops. This also
    // doubles as our password check.
    try {
      final credential = EmailAuthProvider.credential(
        email: email.trim(),
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          throw AccountDeletionException('Incorrect password.', code: e.code);
        case 'user-mismatch':
          throw AccountDeletionException(
              'That email does not match this account.',
              code: e.code);
        case 'too-many-requests':
          throw AccountDeletionException(
              'Too many attempts. Please try again later.',
              code: e.code);
        default:
          throw AccountDeletionException(
              'Re-authentication failed: ${e.message}',
              code: e.code);
      }
    }

    // Defensive check — make sure the typed email actually matches the
    // account being deleted, not just a credential that happens to verify.
    if (user.email != null &&
        user.email!.toLowerCase() != email.trim().toLowerCase()) {
      throw AccountDeletionException('That email does not match this account.');
    }

    final uid = user.uid;
    final userEmail = user.email ?? email.trim();

    // ── Step 2: Cascade-delete everything tied to this account ────────────
    try {
      await _cascadeDeleteUserData(uid);
    } catch (e) {
      throw AccountDeletionException(
          'Failed to clean up account data: $e. Your account was NOT '
          'deleted — please try again.');
    }

    // ── Step 3: Record the email cooldown BEFORE deleting the Auth user ───
    // Order matters: if this write fails, we abort rather than risk freeing
    // the email immediately.
    try {
      final hash = _hashEmail(userEmail);
      final now = DateTime.now();
      await _db.collection('deletedAccounts').doc(hash).set({
        'emailHash': hash,
        'deletedAt': Timestamp.fromDate(now),
        'availableAt': Timestamp.fromDate(now.add(cooldownDuration)),
        'formerUid': uid,
      });
    } catch (e) {
      throw AccountDeletionException(
          'Failed to finalize deletion record: $e. Please try again.');
    }

    // ── Step 4: Delete the Firebase Auth user itself ───────────────────────
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw AccountDeletionException(
            'Session expired mid-deletion. Your data was removed, but '
            'please sign in again to fully close the account.',
            code: e.code);
      }
      throw AccountDeletionException(
          'Account data was deleted, but closing the account failed: '
          '${e.message}. Please contact support.',
          code: e.code);
    }
  }

  // ── Cascading cleanup ──────────────────────────────────────────────────────
  // Mirrors the real schema (see firestore.rules):
  //   public_decks/{deckId}                      — top-level, field: ownerUid
  //   users/{uid}                                — profile doc
  //   users/{uid}/decks/{deckId}                 — private deck docs
  //   users/{uid}/decks/{deckId}/cards/{cardId}  — cards subcollection
  //   users/{uid}/following/{followeeUid}
  //   users/{uid}/followers/{followerUid}
  //   users/{uid}/notifications/{notificationId}
  //   users/{uid}/quizAttempts/{attemptId}
  //   users/{uid}/deckProgress/{progressId}
  //   users/{uid}/recentSessions/{deckId}
  //
  // Everything except `public_decks` and the follow graph's REVERSE edges
  // lives under users/{uid}, so the security rules (`request.auth.uid ==
  // uid`) cover it as long as we're deleting our OWN subtree — no special
  // server-side permission is needed for those.
  //
  // The two exceptions that need their own rule coverage:
  //   1. public_decks/{deckId} — top-level, rule requires
  //      request.auth.uid == resource.data.ownerUid for delete. We query by
  //      ownerUid == uid, so this is covered.
  //   2. users/{otherUid}/followers/{uid} and
  //      users/{otherUid}/following/{uid} — these are the REVERSE side of
  //      the follow graph living in OTHER users' subtrees. Per
  //      firestore.rules, `followers/{followerUid}` write requires
  //      `request.auth.uid == followerUid`, and `following/{followeeUid}`
  //      write requires `request.auth.uid == uid` (the doc owner) — meaning
  //      a user can delete their OWN following/{x} entries (their outbound
  //      follows) and their OWN followers/{x} entries where they are the
  //      follower (i.e. removing themselves from someone else's followers
  //      list IS allowed, since followers/{followerUid} write checks
  //      followerUid == auth.uid, not the parent uid). Both directions are
  //      therefore deletable by the user being deleted — see below.
  Future<void> _cascadeDeleteUserData(String uid) async {
    final userRef = _db.collection('users').doc(uid);

    // 1) Private decks + their cards subcollection.
    final decksSnap = await userRef.collection('decks').get();
    for (final deckDoc in decksSnap.docs) {
      final cardsSnap = await deckDoc.reference.collection('cards').get();
      await _batchDelete(cardsSnap.docs.map((d) => d.reference));
    }
    await _batchDelete(decksSnap.docs.map((d) => d.reference));

    // 2) Public deck mirrors in the top-level `public_decks` collection
    //    (this is what makes a deck show up in Discover). Deleting these
    //    removes the deck from Discover immediately.
    final publicDecksSnap = await _db
        .collection('public_decks')
        .where('ownerUid', isEqualTo: uid)
        .get();
    await _batchDelete(publicDecksSnap.docs.map((d) => d.reference));

    // 3) Follow graph — outbound (people this user follows).
    //    Path: users/{uid}/following/{followeeUid} — owned by uid, always
    //    deletable by uid per the rules.
    final followingSnap = await userRef.collection('following').get();
    await _batchDelete(followingSnap.docs.map((d) => d.reference));

    // 4) Follow graph — inbound (people who follow this user).
    //    Path: users/{uid}/followers/{followerUid} — lives in THIS user's
    //    own subtree, so it's covered by the same uid == uid rule on read,
    //    and deletable since we own this document's parent path.
    final followersSnap = await userRef.collection('followers').get();
    await _batchDelete(followersSnap.docs.map((d) => d.reference));

    // 5) Remove this user as a follower from everyone they followed, and
    //    remove this user from the followers list of everyone who followed
    //    them — otherwise stale entries point at a uid that no longer
    //    exists. Each of these lives in ANOTHER user's subtree:
    //      users/{followeeUid}/followers/{uid}   — write allowed because
    //        the rule checks request.auth.uid == followerUid (== uid, the
    //        document ID), not the parent uid.
    //      users/{followerUid}/following/{uid}   — write requires
    //        request.auth.uid == uid where uid is the PARENT (the doc
    //        owner), so a different user's `following` entry pointing at
    //        US cannot be deleted by us under current rules. We leave those
    //        as-is; they'll simply point at a deleted profile. Consider a
    //        Cloud Function (Auth onDelete trigger) to clean these up
    //        server-side with admin privileges if stale entries matter.
    for (final followeeDoc in followingSnap.docs) {
      final followeeUid = followeeDoc.id;
      try {
        await _db
            .collection('users')
            .doc(followeeUid)
            .collection('followers')
            .doc(uid)
            .delete();
      } catch (_) {
        // Best-effort — don't let one failed cross-user cleanup abort the
        // whole account deletion.
      }
    }

    // 6) In-app notifications.
    final notificationsSnap = await userRef.collection('notifications').get();
    await _batchDelete(notificationsSnap.docs.map((d) => d.reference));

    // 7) Quiz history.
    final quizAttemptsSnap = await userRef.collection('quizAttempts').get();
    await _batchDelete(quizAttemptsSnap.docs.map((d) => d.reference));

    // 8) Per-deck progress aggregates.
    final deckProgressSnap = await userRef.collection('deckProgress').get();
    await _batchDelete(deckProgressSnap.docs.map((d) => d.reference));

    // 9) Recent activity sessions.
    final recentSessionsSnap = await userRef.collection('recentSessions').get();
    await _batchDelete(recentSessionsSnap.docs.map((d) => d.reference));

    // 10) Finally, the user's own profile document.
    await userRef.delete();
  }

  // Firestore batches cap at 500 ops — chunk defensively even though most
  // users won't be close to that.
  Future<void> _batchDelete(Iterable<DocumentReference> refs) async {
    final list = refs.toList();
    if (list.isEmpty) return;

    const chunkSize = 450;
    for (var i = 0; i < list.length; i += chunkSize) {
      final chunk = list.skip(i).take(chunkSize);
      final batch = _db.batch();
      for (final ref in chunk) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }
}
