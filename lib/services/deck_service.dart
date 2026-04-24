import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DeckService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static CollectionReference get _deckRef => _db.collection('decks');

  /// CREATE DECK
  static Future<String> createDeck({
    required String title,
    required String tag,
    required List<Map<String, dynamic>> cards,
  }) async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        throw Exception('User not authenticated');
      }

      final docRef = _deckRef.doc();

      final data = {
        'deckId': docRef.id,
        'userId': user.uid,
        'title': title.trim(),
        'tag': tag,
        'cards': cards,
        'progress': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(data);

      return docRef.id;
    } on FirebaseException catch (e) {
      throw Exception('Firestore error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to create deck: $e');
    }
  }
}
