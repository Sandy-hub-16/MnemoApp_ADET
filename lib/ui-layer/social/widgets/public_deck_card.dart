import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data-layer/models/social/public_deck_summary.dart';
import '../../landing_page/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PUBLIC DECK CARD
//
// Displays a single PublicDeckSummary in a card matching the visual style of
// _DeckCard in deck_screen.dart. Shows title, tag, owner identity, card count,
// and time elapsed since sharedAt. Tappable via [onTap] callback.
// ─────────────────────────────────────────────────────────────────────────────

class PublicDeckCard extends StatelessWidget {
  const PublicDeckCard({
    super.key,
    required this.deck,
    required this.onTap,
  });

  final PublicDeckSummary deck;
  final VoidCallback onTap;

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Returns a human-readable "time ago" string for [dateTime].
  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return '$m ${m == 1 ? 'min' : 'mins'} ago';
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return '$h ${h == 1 ? 'hour' : 'hours'} ago';
    }
    if (diff.inDays < 30) {
      final d = diff.inDays;
      return '$d ${d == 1 ? 'day' : 'days'} ago';
    }
    if (diff.inDays < 365) {
      final mo = (diff.inDays / 30).floor();
      return '$mo ${mo == 1 ? 'month' : 'months'} ago';
    }
    final y = (diff.inDays / 365).floor();
    return '$y ${y == 1 ? 'year' : 'years'} ago';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.onSurface.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Tag row ───────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    deck.tag.toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onSecondaryContainer,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Text(
                  _timeAgo(deck.sharedAt),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Title ─────────────────────────────────────────────────
            Text(
              deck.title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),

            // ── Owner + card count row ────────────────────────────────
            Row(
              children: [
                // Avatar
                _OwnerAvatar(
                  ownerUid: deck.ownerUid,
                  fallbackPhotoUrl: deck.ownerPhotoUrl,
                  size: 26,
                ),
                const SizedBox(width: 8),
                // Full name
                Expanded(
                  child: Text(
                    deck.ownerFullName,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Card count chip
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.style_rounded,
                        size: 12,
                        color: AppColors.outline,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${deck.cardCount} cards',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OWNER AVATAR
//
// Circular avatar that shows the owner's CURRENT profile photo, fetched live
// from users/{ownerUid} — unlike the title/owner name, the photo is meant to
// stay in sync if the owner changes their picture after sharing the deck.
// Falls back to [fallbackPhotoUrl] (the frozen snapshot stored on the public
// deck doc) while the live read is in flight or if it fails, and falls back
// to a person icon if no photo is available at all.
// ─────────────────────────────────────────────────────────────────────────────

class _OwnerAvatar extends StatelessWidget {
  const _OwnerAvatar({
    required this.ownerUid,
    this.fallbackPhotoUrl,
    this.size = 32,
  });

  final String ownerUid;
  final String? fallbackPhotoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ownerUid.isEmpty
          ? null
          : FirebaseFirestore.instance
              .collection('users')
              .doc(ownerUid)
              .snapshots(),
      builder: (context, snapshot) {
        final livePhotoUrl = snapshot.data?.data()?['photoUrl'] as String?;
        final photoUrl = (livePhotoUrl != null && livePhotoUrl.isNotEmpty)
            ? livePhotoUrl
            : fallbackPhotoUrl;

        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryContainer,
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          child: ClipOval(
            child: photoUrl != null && photoUrl.isNotEmpty
                ? Image.network(
                    photoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.person_rounded,
                      color: AppColors.primary,
                      size: 16,
                    ),
                  )
                : const Icon(
                    Icons.person_rounded,
                    color: AppColors.primary,
                    size: 16,
                  ),
          ),
        );
      },
    );
  }
}
