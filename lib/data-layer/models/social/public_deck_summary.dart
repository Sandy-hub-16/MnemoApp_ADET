import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PUBLIC DECK SUMMARY
//
// Mirror document stored at public_decks/{deckId}.
// Contains only the fields needed for discovery queries — the full card
// sub-collection stays private under users/{uid}/decks/{deckId}/cards.
// ─────────────────────────────────────────────────────────────────────────────

class PublicDeckSummary {
  const PublicDeckSummary({
    required this.deckId,
    required this.title,
    required this.tag,
    required this.cardCount,
    required this.ownerUid,
    required this.ownerUsername,
    this.ownerPhotoUrl,
    required this.sharedAt,
    required this.cloneCount,
  });

  final String deckId;
  final String title;
  final String tag;
  final int cardCount;
  final String ownerUid;
  final String ownerUsername;
  final String? ownerPhotoUrl;
  final DateTime sharedAt;
  final int cloneCount;

  // ── Firestore deserialization ─────────────────────────────────────────────

  factory PublicDeckSummary.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return PublicDeckSummary(
      deckId: doc.id,
      title: data['title'] as String? ?? '',
      tag: data['tag'] as String? ?? '',
      cardCount: (data['cardCount'] as num?)?.toInt() ?? 0,
      ownerUid: data['ownerUid'] as String? ?? '',
      ownerUsername: data['ownerUsername'] as String? ?? '',
      ownerPhotoUrl: data['ownerPhotoUrl'] as String?,
      sharedAt: (data['sharedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      cloneCount: (data['cloneCount'] as num?)?.toInt() ?? 0,
    );
  }

  // ── Firestore serialization ───────────────────────────────────────────────

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'tag': tag,
        'cardCount': cardCount,
        'ownerUid': ownerUid,
        'ownerUsername': ownerUsername,
        'ownerPhotoUrl': ownerPhotoUrl,
        'sharedAt': Timestamp.fromDate(sharedAt),
        'cloneCount': cloneCount,
      };
}
