import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../landing_page/app_theme.dart';
import '../../data-layer/models/social/public_deck_summary.dart';
import '../../data-layer/route_args/social_route_args.dart';
import '../../business-layer/services/share_service.dart';
import '../main_screens/deck/deck_quiz_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SHARED DECK DETAIL SCREEN  —  route: /shared-deck-detail
//
// Displays a public deck's summary, a preview of up to 5 cards (question only),
// and a Clone button that copies the deck into the current user's library.
//
// Arguments: SharedDeckDetailArgs (deckId, ownerUid) via settings.arguments
//
// Architecture: public StatelessWidget → private StatefulWidget _Body
// ─────────────────────────────────────────────────────────────────────────────

class SharedDeckDetailScreen extends StatelessWidget {
  const SharedDeckDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)!.settings.arguments as SharedDeckDetailArgs;
    return _SharedDeckDetailBody(args: args);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BODY
// ─────────────────────────────────────────────────────────────────────────────

class _SharedDeckDetailBody extends StatefulWidget {
  const _SharedDeckDetailBody({required this.args});

  final SharedDeckDetailArgs args;

  @override
  State<_SharedDeckDetailBody> createState() => _SharedDeckDetailBodyState();
}

class _SharedDeckDetailBodyState extends State<_SharedDeckDetailBody> {
  // ── State ─────────────────────────────────────────────────────────────────

  bool _isLoadingData = true;
  bool _isCloning = false;

  PublicDeckSummary? _summary;
  List<Map<String, dynamic>> _previewCards = [];

  String? _errorMessage;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    setState(() {
      _isLoadingData = true;
      _errorMessage = null;
    });

    try {
      final db = FirebaseFirestore.instance;

      // Fetch public deck summary
      final summarySnap = await db
          .collection('public_decks')
          .doc(widget.args.deckId)
          .get();

      if (!summarySnap.exists) {
        if (mounted) {
          _showErrorSnackBar('This deck is no longer available.');
          Navigator.of(context).pop();
        }
        return;
      }

      final summary = PublicDeckSummary.fromFirestore(summarySnap);

      // Fetch up to 5 cards ordered by 'order'
      final cardsSnap = await db
          .collection('users')
          .doc(widget.args.ownerUid)
          .collection('decks')
          .doc(widget.args.deckId)
          .collection('cards')
          .orderBy('order')
          .limit(5)
          .get();

      // Also get the real total card count (the mirror doc may be stale)
      final totalCountSnap = await db
          .collection('users')
          .doc(widget.args.ownerUid)
          .collection('decks')
          .doc(widget.args.deckId)
          .collection('cards')
          .count()
          .get();

      final realCardCount = totalCountSnap.count ?? summary.cardCount;

      final cards = cardsSnap.docs
          .map((d) => d.data())
          .toList();

      // Build a corrected summary with the real card count
      final correctedSummary = realCardCount != summary.cardCount
          ? PublicDeckSummary(
              deckId: summary.deckId,
              title: summary.title,
              tag: summary.tag,
              cardCount: realCardCount,
              ownerUid: summary.ownerUid,
              ownerUsername: summary.ownerUsername,
              ownerPhotoUrl: summary.ownerPhotoUrl,
              sharedAt: summary.sharedAt,
              cloneCount: summary.cloneCount,
            )
          : summary;

      if (mounted) {
        setState(() {
          _summary = correctedSummary;
          _previewCards = cards;
          _isLoadingData = false;
        });
      }
    } catch (e, st) {
      debugPrint('[SharedDeckDetailScreen._loadData] error: $e\n$st');
      if (mounted) {
        setState(() {
          _isLoadingData = false;
          _errorMessage = 'Failed to load deck. Please try again.';
        });
      }
    }
  }

  // ── Clone action ──────────────────────────────────────────────────────────

  Future<void> _cloneDeck() async {
    if (_isCloning) return;

    setState(() => _isCloning = true);

    try {
      await ShareService.cloneDeck(
        sourceDeckId: widget.args.deckId,
        sourceOwnerUid: widget.args.ownerUid,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Deck cloned to your library',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        ),
      );
    } on StateError {
      // Deck is no longer public
      if (!mounted) return;
      _showErrorSnackBar('This deck is no longer available.');
      Navigator.of(context).pop();
      return;
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Failed to clone deck. Please try again.');
    } finally {
      if (mounted) setState(() => _isCloning = false);
    }
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _openOwnerProfile(String ownerUid) {
    Navigator.of(context).pushNamed(
      '/public-profile',
      arguments: PublicProfileArgs(targetUid: ownerUid),
    );
  }

  void _takeQuiz() {
    if (_summary == null) return;
    Navigator.of(context).pushNamed(
      '/quiz',
      arguments: QuizArgs(
        deckId: widget.args.deckId,
        deckTitle: _summary!.title,
        ownerUid: widget.args.ownerUid,
      ),
    );
  }

  // ── Error display ─────────────────────────────────────────────────────────

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Decorative blobs ─────────────────────────────────────────────
          Positioned(
            top: -40,
            right: -80,
            child: _Blob(
              size: 300,
              color: AppColors.primaryContainer.withValues(alpha: 0.22),
            ),
          ),
          Positioned(
            bottom: 200,
            left: -100,
            child: _Blob(
              size: 260,
              color: AppColors.secondaryContainer.withValues(alpha: 0.25),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ── Top bar ───────────────────────────────────────────────
                _DetailTopBar(
                  onBack: () => Navigator.of(context).pop(),
                ),

                // ── Content ───────────────────────────────────────────────
                Expanded(
                  child: _isLoadingData
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        )
                      : _errorMessage != null
                          ? _ErrorState(
                              message: _errorMessage!,
                              onRetry: _loadData,
                            )
                          : _summary == null
                              ? const SizedBox.shrink()
                              : _DeckDetailContent(
                                  summary: _summary!,
                                  previewCards: _previewCards,
                                  isCloning: _isCloning,
                                  onClone: _cloneDeck,
                                  onQuiz: _takeQuiz,
                                  onOwnerTap: () =>
                                      _openOwnerProfile(_summary!.ownerUid),
                                ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOP BAR
// ─────────────────────────────────────────────────────────────────────────────

class _DetailTopBar extends StatelessWidget {
  const _DetailTopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background.withValues(alpha: 0.80),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.onSurface,
              size: 20,
            ),
          ),
          Text(
            'Deck Details',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DECK DETAIL CONTENT
// ─────────────────────────────────────────────────────────────────────────────

class _DeckDetailContent extends StatelessWidget {
  const _DeckDetailContent({
    required this.summary,
    required this.previewCards,
    required this.isCloning,
    required this.onClone,
    required this.onQuiz,
    required this.onOwnerTap,
  });

  final PublicDeckSummary summary;
  final List<Map<String, dynamic>> previewCards;
  final bool isCloning;
  final VoidCallback onClone;
  final VoidCallback onQuiz;
  final VoidCallback onOwnerTap;

  @override
  Widget build(BuildContext context) {
    // Check if the current user is the owner (hide clone button for own decks)
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isOwner = currentUid == summary.ownerUid;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // ── Deck header card ─────────────────────────────────────────
              _DeckHeaderCard(
                summary: summary,
                onOwnerTap: onOwnerTap,
              ),
              const SizedBox(height: 24),

              // ── Card preview section ─────────────────────────────────────
              if (previewCards.isNotEmpty) ...[
                Row(
                  children: [
                    Text(
                      'Card Preview',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${previewCards.length} of ${summary.cardCount}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...previewCards.asMap().entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _CardPreviewTile(
                          index: entry.key + 1,
                          question:
                              entry.value['question'] as String? ?? '',
                        ),
                      ),
                    ),
                const SizedBox(height: 24),
              ],

              // ── Action buttons ───────────────────────────────────────────
              const SizedBox(height: 12),
              if (!isOwner)
                _CloneButton(
                  isCloning: isCloning,
                  onClone: onClone,
                ),

              const SizedBox(height: 40),
            ]),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DECK HEADER CARD
// ─────────────────────────────────────────────────────────────────────────────

class _DeckHeaderCard extends StatelessWidget {
  const _DeckHeaderCard({
    required this.summary,
    required this.onOwnerTap,
  });

  final PublicDeckSummary summary;
  final VoidCallback onOwnerTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Tag chip ───────────────────────────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.secondaryContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              summary.tag,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.onSecondaryContainer,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Title ──────────────────────────────────────────────────────
          Text(
            summary.title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.onSurface,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),

          // ── Stats row ──────────────────────────────────────────────────
          Row(
            children: [
              _StatChip(
                icon: Icons.style_rounded,
                label: '${summary.cardCount} cards',
              ),
              const SizedBox(width: 10),
              _StatChip(
                icon: Icons.copy_rounded,
                label: '${summary.cloneCount} clones',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Divider ────────────────────────────────────────────────────
          Divider(
            color: AppColors.outlineVariant.withValues(alpha: 0.4),
            thickness: 1,
          ),
          const SizedBox(height: 12),

          // ── Owner row ──────────────────────────────────────────────────
          Row(
            children: [
              // Avatar
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryContainer,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    width: 2,
                  ),
                ),
                child: summary.ownerPhotoUrl != null
                    ? ClipOval(
                        child: Image.network(
                          summary.ownerPhotoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.person_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.person_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
              ),
              const SizedBox(width: 10),

              // Username (tappable)
              Expanded(
                child: GestureDetector(
                  onTap: onOwnerTap,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Shared by',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.outline,
                        ),
                      ),
                      Text(
                        '@${summary.ownerUsername}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STAT CHIP
// ─────────────────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD PREVIEW TILE
// ─────────────────────────────────────────────────────────────────────────────

class _CardPreviewTile extends StatelessWidget {
  const _CardPreviewTile({
    required this.index,
    required this.question,
  });

  final int index;
  final String question;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Index badge
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              '$index',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Question text
          Expanded(
            child: Text(
              question,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.onSurface,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CLONE BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _CloneButton extends StatelessWidget {
  const _CloneButton({
    required this.isCloning,
    required this.onClone,
  });

  final bool isCloning;
  final VoidCallback onClone;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isCloning ? null : onClone,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
          foregroundColor: AppColors.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 0,
        ),
        child: isCloning
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: AppColors.onPrimary,
                  strokeWidth: 2.5,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.copy_all_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Clone Deck',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ERROR STATE
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: AppColors.outline.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: onRetry,
              child: Text(
                'Try again',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DECORATIVE BLOB
// ─────────────────────────────────────────────────────────────────────────────

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}
