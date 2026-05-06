import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DECK SERVICE
//
// Central data-access layer for all deck operations.  Every method works on
// the path:
//   users/{uid}/decks/{deckId}
//
// DRAFT LIFECYCLE
// ───────────────
//   saveDraft()     → creates a new deck doc with isDraft:true
//   updateDraft()   → overwrites the cards sub-collection of an existing draft
//   completeDraft() → removes isDraft flag and writes the final card set;
//                     the deck becomes fully functional (quiz, edit, share)
//
// REGULAR DECK LIFECYCLE
// ──────────────────────
//   createDeck()    → creates a deck doc directly with isDraft:false
//   updateDeck()    → overwrites title/tag/cards of a completed deck
//   deleteDeck()    → deletes the deck doc + all cards in a batched write
//   getDeckCards()  → fetches saved card maps (used when continuing a draft)
// ─────────────────────────────────────────────────────────────────────────────

abstract final class DeckService {
  // ── Helpers ──────────────────────────────────────────────────────────────

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static String get _uid {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('User is not signed in.');
    return uid;
  }

  static CollectionReference<Map<String, dynamic>> _decksRef() =>
      _db.collection('users').doc(_uid).collection('decks');

  static CollectionReference<Map<String, dynamic>> _cardsRef(String deckId) =>
      _decksRef().doc(deckId).collection('cards');

  // ── Write card sub-collection in a batch ─────────────────────────────────
  //
  // Deletes all existing cards first, then writes the new set.
  // This keeps the sub-collection in sync even on partial re-saves.

  static Future<void> _replaceCards(
    WriteBatch batch,
    String deckId,
    List<Map<String, dynamic>> cards,
  ) async {
    // Delete existing cards
    final existing = await _cardsRef(deckId).get();
    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }

    // Write new cards
    for (int i = 0; i < cards.length; i++) {
      final ref = _cardsRef(deckId).doc();
      batch.set(ref, {
        ...cards[i],
        'order': i, // preserve card order
      });
    }
  }

  // ── CREATE DECK (non-draft) ───────────────────────────────────────────────

  /// Creates a complete, fully-functional deck.
  /// Returns the new Firestore document ID.
  static Future<String> createDeck({
    required String title,
    required String tag,
    required List<Map<String, dynamic>> cards,
  }) async {
    final deckRef = _decksRef().doc();

    final batch = _db.batch();

    batch.set(deckRef, {
      'title': title,
      'tag': tag,
      'isDraft': false,
      'visibility': 'private',
      'cardCount': cards.length,
      'targetCardCount': cards.length,
      'progress': 0.0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    for (int i = 0; i < cards.length; i++) {
      final cardRef = deckRef.collection('cards').doc();
      batch.set(cardRef, {...cards[i], 'order': i});
    }

    await batch.commit();
    return deckRef.id;
  }

  // ── SAVE DRAFT (first save) ───────────────────────────────────────────────

  /// Creates a new deck document marked as a draft.
  /// Returns the new Firestore document ID so the caller can hold onto it
  /// for subsequent updateDraft / completeDraft calls in the same session.
  static Future<String> saveDraft({
    required String title,
    required String tag,
    required int targetCardCount,
    required List<Map<String, dynamic>> cards,
  }) async {
    final deckRef = _decksRef().doc();

    final batch = _db.batch();

    batch.set(deckRef, {
      'title': title,
      'tag': tag,
      'isDraft': true,
      'visibility': 'private',
      'cardCount': cards.length,
      'targetCardCount': targetCardCount,
      'progress': 0.0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    for (int i = 0; i < cards.length; i++) {
      final cardRef = deckRef.collection('cards').doc();
      batch.set(cardRef, {...cards[i], 'order': i});
    }

    await batch.commit();
    return deckRef.id;
  }

  // ── UPDATE DRAFT (subsequent saves) ──────────────────────────────────────

  /// Overwrites the card sub-collection of an existing draft.
  /// Does NOT change isDraft — the deck stays in draft state.
  static Future<void> updateDraft({
    required String draftId,
    required List<Map<String, dynamic>> cards,
  }) async {
    final batch = _db.batch();

    // Update the deck-level card count + timestamp.
    batch.update(_decksRef().doc(draftId), {
      'cardCount': cards.length,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Replace the cards sub-collection.
    await _replaceCards(batch, draftId, cards);

    await batch.commit();
  }

  // ── COMPLETE DRAFT ────────────────────────────────────────────────────────

  /// Finalises a draft:
  ///   • Sets isDraft → false (deck becomes fully functional)
  ///   • Updates title, tag, cardCount
  ///   • Replaces the cards sub-collection with the finished set
  static Future<void> completeDraft({
    required String draftId,
    required String title,
    required String tag,
    required List<Map<String, dynamic>> cards,
  }) async {
    final batch = _db.batch();

    batch.update(_decksRef().doc(draftId), {
      'title': title,
      'tag': tag,
      'isDraft': false,
      'visibility': 'private',
      'cardCount': cards.length,
      'targetCardCount': cards.length,
      'progress': 0.0,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _replaceCards(batch, draftId, cards);

    await batch.commit();
  }

  // ── UPDATE DECK (edit completed deck) ────────────────────────────────────

  /// Updates a completed deck's title, tag, and cards.
  static Future<void> updateDeck({
    required String deckId,
    required String title,
    required String tag,
    required List<Map<String, dynamic>> cards,
  }) async {
    final batch = _db.batch();

    batch.update(_decksRef().doc(deckId), {
      'title': title,
      'tag': tag,
      'cardCount': cards.length,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _replaceCards(batch, deckId, cards);

    await batch.commit();
  }

  // ── GET DECK CARDS ────────────────────────────────────────────────────────

  /// Fetches all card maps from a deck's sub-collection, ordered by `order`.
  /// Used by the deck hub when the user taps "Continue Draft".
  static Future<List<Map<String, dynamic>>> getDeckCards(String deckId) async {
    final snap = await _cardsRef(deckId).orderBy('order').get();
    return snap.docs.map((d) => d.data()).toList();
  }

  // ── DELETE DECK ───────────────────────────────────────────────────────────

  /// Deletes a deck document, all of its cards, and all related progress data.
  /// Works for both drafts and completed decks.
  /// 
  /// Cleanup includes:
  /// - All cards in the deck
  /// - The deck document itself
  /// - All quiz attempts for this deck
  /// - The deck progress document
  static Future<void> deleteDeck(String deckId) async {
    final batch = _db.batch();

    // Delete all cards
    final cards = await _cardsRef(deckId).get();
    for (final card in cards.docs) {
      batch.delete(card.reference);
    }

    // Delete the deck doc
    batch.delete(_decksRef().doc(deckId));

    await batch.commit();

    // Clean up progress data (separate batch to avoid size limits)
    await _cleanupProgressData(deckId);
  }

  /// Removes all progress data associated with a deleted deck.
  static Future<void> _cleanupProgressData(String deckId) async {
    final userRef = _db.collection('users').doc(_uid);

    // Delete all quiz attempts for this deck
    final attempts = await userRef
        .collection('quizAttempts')
        .where('deckId', isEqualTo: deckId)
        .get();

    if (attempts.docs.isNotEmpty) {
      final batch = _db.batch();
      for (final doc in attempts.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    // Delete the deck progress document
    final progressDocs = await userRef
        .collection('deckProgress')
        .where('deckId', isEqualTo: deckId)
        .get();

    if (progressDocs.docs.isNotEmpty) {
      final batch = _db.batch();
      for (final doc in progressDocs.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }
}
