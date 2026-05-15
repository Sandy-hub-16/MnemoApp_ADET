import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../business-layer/services/feed_service.dart';
import '../../data-layer/models/social/public_deck_summary.dart';
import '../../data-layer/route_args/social_route_args.dart';
import '../../main.dart';
import '../landing_page/app_theme.dart';
import 'widgets/feed_item_card.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SOCIAL FEED SCREEN  —  route: /feed
//
// Displays a real-time stream of public decks shared by users the current
// user follows, powered by FeedService.feedStream().
//
// DATA PATH
// ─────────
//   FeedService.feedStream(currentUid)
//     → users/{currentUid}/following  (one-time read for followee UIDs)
//     → public_decks where ownerUid in [followeeUids]  (real-time listener)
//
// STATES
// ──────
//   loading  — CircularProgressIndicator while stream awaits first event
//   empty    — icon + message + Discover button when following nobody or no
//              shared decks exist
//   data     — scrollable list of FeedItemCard widgets
//   error    — brief error message with retry prompt
//
// Requirements: 6.1, 6.2, 6.3, 6.4, 6.5
// ─────────────────────────────────────────────────────────────────────────────

class SocialFeedScreen extends StatelessWidget {
  const SocialFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SocialFeedBody();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BODY
// ─────────────────────────────────────────────────────────────────────────────

class _SocialFeedBody extends StatefulWidget {
  const _SocialFeedBody();

  @override
  State<_SocialFeedBody> createState() => _SocialFeedBodyState();
}

class _SocialFeedBodyState extends State<_SocialFeedBody> {
  // ── State ─────────────────────────────────────────────────────────────────

  late final String _currentUid;

  @override
  void initState() {
    super.initState();
    _currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  // ── Navigation helpers ────────────────────────────────────────────────────

  void _openDeckDetail(PublicDeckSummary deck) {
    Navigator.of(context).pushNamed(
      '/shared-deck-detail',
      arguments: SharedDeckDetailArgs(
        deckId: deck.deckId,
        ownerUid: deck.ownerUid,
      ),
    );
  }

  void _openDiscover() {
    Navigator.of(context).pushNamed('/discover');
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: Stack(
        children: [
          // ── Decorative blobs ─────────────────────────────────────────────
          Positioned(
            top: -60,
            right: -80,
            child: _Blob(
              size: 300,
              color: AppColors.primaryContainer.withValues(alpha: 0.15),
            ),
          ),
          Positioned(
            bottom: 200,
            left: -100,
            child: _Blob(
              size: 260,
              color: AppColors.secondaryContainer.withValues(alpha: 0.18),
            ),
          ),

          // ── Main content ─────────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _FeedTopBar(onDiscoverTap: _openDiscover),
                Expanded(
                  child: _currentUid.isEmpty
                      ? _buildEmptyState()
                      : StreamBuilder<List<PublicDeckSummary>>(
                          stream: FeedService.feedStream(_currentUid),
                          builder: (context, snapshot) {
                            // ── Loading ──────────────────────────────────
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.primary,
                                ),
                              );
                            }

                            // ── Error ────────────────────────────────────
                            if (snapshot.hasError) {
                              return _buildErrorState(snapshot.error);
                            }

                            final decks = snapshot.data ?? [];

                            // ── Empty ────────────────────────────────────
                            if (decks.isEmpty) {
                              return _buildEmptyState();
                            }

                            // ── Feed list ────────────────────────────────
                            return _buildFeedList(decks);
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const _FeedBottomNavBar(activeIndex: 2),
    );
  }

  // ── Feed list ─────────────────────────────────────────────────────────────

  Widget _buildFeedList(List<PublicDeckSummary> decks) {
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
      itemCount: decks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final deck = decks[index];
        return FeedItemCard(
          deck: deck,
          onTap: () => _openDeckDetail(deck),
        );
      },
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: 0.35),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people_outline_rounded,
                size: 44,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),

            // Headline
            Text(
              'Your feed is empty',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),

            // Sub-message
            Text(
              'Follow other learners to see their decks here',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: AppColors.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            // Discover button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _openDiscover,
                icon: const Icon(Icons.explore_rounded, size: 18),
                label: Text(
                  'Discover Decks',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Error state ───────────────────────────────────────────────────────────

  Widget _buildErrorState(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Unable to load your feed. Please try again later.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppColors.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOP BAR
// ─────────────────────────────────────────────────────────────────────────────

class _FeedTopBar extends StatelessWidget {
  const _FeedTopBar({required this.onDiscoverTap});
  final VoidCallback onDiscoverTap;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          color: AppColors.background.withValues(alpha: 0.75),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Title
              Text(
                'Feed',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface,
                  letterSpacing: -0.5,
                ),
              ),

              // Discover shortcut
              GestureDetector(
                onTap: onDiscoverTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.explore_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Discover',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM NAV BAR  (activeIndex: 2 = Feed / Discover)
//
// Mirrors the nav bar pattern from home_screen.dart.
// Index layout: 0 Home · 1 Decks · 2 Feed · 3 Progress · 4 Profile
// NOTE: Full bottom-nav restructuring (adding Discover tab) is handled in
// Task 14. This local nav bar reflects the intended final index so the screen
// is self-consistent when navigated to directly.
// ─────────────────────────────────────────────────────────────────────────────

class _FeedBottomNavBar extends StatelessWidget {
  const _FeedBottomNavBar({required this.activeIndex});
  final int activeIndex;

  // Route strings match the constants that will be defined in Task 14.
  // Once AppRoutes gains discover/feed/sharedDeckDetail, replace these literals.
  static const _items = [
    _NavItem(icon: Icons.home_outlined, label: 'Home', route: AppRoutes.home),
    _NavItem(
        icon: Icons.layers_outlined, label: 'Decks', route: AppRoutes.decks),
    _NavItem(
        icon: Icons.explore_outlined, label: 'Feed', route: '/feed'),
    _NavItem(
        icon: Icons.analytics_outlined,
        label: 'Progress',
        route: AppRoutes.progress),
    _NavItem(
        icon: Icons.person_outline_rounded,
        label: 'Profile',
        route: AppRoutes.profile),
  ];

  static final Map<IconData, IconData> _filledIconMap = {
    Icons.home_outlined: Icons.home_rounded,
    Icons.layers_outlined: Icons.layers_rounded,
    Icons.explore_outlined: Icons.explore_rounded,
    Icons.analytics_outlined: Icons.analytics_rounded,
    Icons.person_outline_rounded: Icons.person_rounded,
  };

  IconData _filledIcon(IconData outline) => _filledIconMap[outline] ?? outline;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withValues(alpha: 0.06),
            blurRadius: 32,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _items.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              final active = i == activeIndex;

              return GestureDetector(
                onTap: () {
                  if (!active) {
                    Navigator.of(context).pushReplacementNamed(item.route);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.primaryContainer.withValues(alpha: 0.45)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        active ? _filledIcon(item.icon) : item.icon,
                        size: 24,
                        color: active
                            ? AppColors.primary
                            : AppColors.onSurfaceVariant,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: active
                              ? AppColors.primary
                              : AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.icon, required this.label, required this.route});
  final IconData icon;
  final String label;
  final String route;
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED HELPERS
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
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
