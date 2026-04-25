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
      String uid, String deckId) {
    return _deckRef(uid).doc(deckId).collection('cards');
  }

  /// CREATE DECK + CARDS
  static Future<String> createDeck({
    required String title,
    required String tag,
    required List<Map<String, dynamic>> cards,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final deckDoc = _deckRef(user.uid).doc();

      // 🔥 Create deck (NO cards inside)
      await deckDoc.set({
        'title': title.trim(),
        'tag': tag,
        'progress': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 🔥 Batch insert cards
      final batch = _db.batch();

      for (final card in cards) {
        final cardDoc = _cardRef(user.uid, deckDoc.id).doc();

        batch.set(cardDoc, {
          'question': card['question'],
          'answer': card['answer'],
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

  /// OPTIONAL: Add single card later
  static Future<void> addCard({
    required String deckId,
    required String question,
    required String answer,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await _cardRef(user.uid, deckId).add({
      'question': question,
      'answer': answer,
      'createdAt': Timestamp.now(),
    });
  }
}