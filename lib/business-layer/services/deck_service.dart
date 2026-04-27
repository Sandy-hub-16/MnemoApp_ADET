import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DeckService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Reference: users/{uid}/decks
  static CollectionReference<Map<String, dynamic>> _deckRef(String uid) =>
      _db.collection('users').doc(uid).collection('decks');

  /// Reference: users/{uid}/decks/{deckId}/cards
  static CollectionReference<Map<String, dynamic>> _cardRef(
          String uid, String deckId) =>
      _deckRef(uid).doc(deckId).collection('cards');

  // ─────────────────────────────────────────────────────────────────────────
  // CREATE DECK + CARDS
  // ─────────────────────────────────────────────────────────────────────────

  static Future<String> createDeck({
    required String title,
    required String tag,
    required List<Map<String, dynamic>> cards,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final deckDoc = _deckRef(user.uid).doc();

      await deckDoc.set({
        'title': title.trim(),
        'tag': tag,
        'progress': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final batch = _db.batch();
      for (final card in cards) {
        final cardDoc = _cardRef(user.uid, deckDoc.id).doc();
        batch.set(cardDoc, {
          'question': card['question'],
          'answer': card['answer'],
          'type': card['type'] ?? 'identification',
          'choices': card['choices'],
          'correctIndex': card['correctIndex'],
          'createdAt': Timestamp.now(),
        });
      }
      await batch.commit();

      print('✅ Deck + Cards saved: ${deckDoc.id}');
      return deckDoc.id;
    } on FirebaseException catch (e) {
      throw Exception('Firestore error: ${e.message}');
    } catch (e) {
      print('❌ DeckService ERROR: $e');
      throw Exception('Failed to create deck: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DELETE ENTIRE DECK (deck doc + all cards subcollection)
  // ─────────────────────────────────────────────────────────────────────────

  static Future<void> deleteDeck(String deckId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // 1. Fetch all cards in the subcollection
      final cardsSnap = await _cardRef(user.uid, deckId).get();

      final batch = _db.batch();

      // 2. Schedule card deletions
      for (final doc in cardsSnap.docs) {
        batch.delete(doc.reference);
      }

      // 3. Schedule deck document deletion
      batch.delete(_deckRef(user.uid).doc(deckId));

      await batch.commit();
      print('✅ Deck deleted: $deckId (${cardsSnap.docs.length} cards removed)');
    } on FirebaseException catch (e) {
      throw Exception('Firestore error: ${e.message}');
    } catch (e) {
      print('❌ DeckService.deleteDeck ERROR: $e');
      throw Exception('Failed to delete deck: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ADD SINGLE CARD (optional utility)
  // ─────────────────────────────────────────────────────────────────────────

  static Future<void> addCard({
    required String deckId,
    required String question,
    required String answer,
    String type = 'identification',
    List<String>? choices,
    int? correctIndex,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await _cardRef(user.uid, deckId).add({
      'question': question,
      'answer': answer,
      'type': type,
      'choices': choices,
      'correctIndex': correctIndex,
      'createdAt': Timestamp.now(),
    });
  }
}

