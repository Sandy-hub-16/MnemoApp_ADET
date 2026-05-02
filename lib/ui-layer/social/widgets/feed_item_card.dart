import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../data-layer/social/public_deck_summary.dart';
import '../../landing_page/app_theme.dart';
import 'public_deck_card.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FEED ITEM CARD
//
// Wraps PublicDeckCard with a subtle "from your network" label above it,
// indicating the item originates from a followed user. Tap behaviour is
// identical to PublicDeckCard — delegates to [onTap].
//
// Requirements: 6.5
// ─────────────────────────────────────────────────────────────────────────────

class FeedItemCard extends StatelessWidget {
  const FeedItemCard({
    super.key,
    required this.deck,
    required this.onTap,
  });

  final PublicDeckSummary deck;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── "From your network" label ─────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.people_outline_rounded,
                size: 13,
                color: AppColors.outline,
              ),
              const SizedBox(width: 4),
              Text(
                'from your network',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.outline,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),

        // ── Deck card ─────────────────────────────────────────────────
        PublicDeckCard(deck: deck, onTap: onTap),
      ],
    );
  }
}
