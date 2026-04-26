import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../landing_page/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'deck-quiz_screen.dart';
import 'edit_deck_screen.dart';
import '../../services/deck_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DECK HUB SCREEN  —  route: /decks
// Displays the main deck library with AI import, filters, and deck cards.
//
// 🎨 FRONTEND NOTE:
// All deck data is hardcoded as placeholder _DeckData objects.
// Replace with a Firestore stream/query in _DeckBody.
// Filter chip selection state lives in _DeckHubScreenState.
// ─────────────────────────────────────────────────────────────────────────────

class DeckHubScreen extends StatelessWidget {
  const DeckHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _DeckHubScaffold();
  }
}

class _DeckHubScaffold extends StatefulWidget {
  const _DeckHubScaffold();

  @override
  State<_DeckHubScaffold> createState() => _DeckHubScaffoldState();
}

class _DeckHubScaffoldState extends State<_DeckHubScaffold> {
  int _selectedFilter = 0;

  static const _filters = [
    'All Decks',
    'Biology',
    'Physics',
    'Organic Chem',
    'World History',
  ];

  Stream<QuerySnapshot<Map<String, dynamic>>> _deckStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('decks')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: Stack(
        children: [
          // ── Decorative blobs ─────────────────────────────
          Positioned(
            top: -40,
            right: -80,
            child: _Blob(
              size: 320,
              color: AppColors.primaryContainer.withOpacity(0.22),
            ),
          ),

          Positioned(
            bottom: 200,
            left: -100,
            child: _Blob(
              size: 280,
              color: AppColors.secondaryContainer.withOpacity(0.25),
            ),
          ),

          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const _DeckTopBar(),
                Expanded(
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      // ✅ 1. STATIC CONTENT (always shows)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            _HeroGreeting(),
                            const SizedBox(height: 20),
                            _SearchBar(),
                            const SizedBox(height: 16),

                            // FILTERS
                            SizedBox(
                              height: 40,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _filters.length + 1,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (context, i) {
                                  if (i == _filters.length) {
                                    return _FilterChip(
                                        label: '+ Add Filter',
                                        active: false,
                                        onTap: () {});
                                  }
                                  return _FilterChip(
                                    label: _filters[i],
                                    active: _selectedFilter == i,
                                    onTap: () =>
                                        setState(() => _selectedFilter = i),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 28),
                            _AIImportCard(),
                            const SizedBox(height: 16),
                            _CreateDeckCard(),
                            const SizedBox(height: 28),

                            // "Recent Decks" HEADER
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Recent Decks',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.onSurface,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ]),
                        ),
                      ),

                      // ✅ 2. STREAM DECKS (shows immediately after header)
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _deckStream(),
                        builder: (context, snapshot) {
                          print('🔥 Stream: ${snapshot.connectionState}');
                          print(
                              '🔥 UID: ${FirebaseAuth.instance.currentUser?.uid}');
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 40),
                                child: Center(
                                    child: CircularProgressIndicator(
                                        color: AppColors.primary)),
                              ),
                            );
                          }

                          final docs = snapshot.data?.docs ?? [];

                          // ✅ EMPTY STATE - shows right under header
                          if (docs.isEmpty) {
                            return SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.all(40),
                                child: Column(
                                  children: [
                                    Icon(Icons.layers_outlined,
                                        size: 64, color: AppColors.outline),
                                    const SizedBox(height: 16),
                                    Text(
                                      "No decks yet",
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      "Create your first deck to get started!",
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          // ✅ FILTER & BUILD DECKS
                          final selectedCategory = _filters[_selectedFilter];
                          final filteredDocs = selectedCategory == 'All Decks'
                              ? docs
                              : docs
                                  .where((doc) =>
                                      doc.data()['tag'] == selectedCategory)
                                  .toList();

                          return SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final deck = filteredDocs[index].data();
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _DeckCard(
                                      deckId: filteredDocs[index].id,
                                      deckTitle: deck['title'] ?? 'Untitled',
                                      tag: deck['tag'] ?? 'Other',
                                      tagColor: AppColors.secondaryContainer,
                                      tagTextColor:
                                          AppColors.onSecondaryContainer,
                                      title: deck['title'] ?? 'Untitled',
                                      subtitle: 'Tap to view cards',
                                      progress:
                                          (deck['progress'] ?? 0.0).toDouble(),
                                      progressColor: AppColors.primary,
                                    ),
                                  );
                                },
                                childCount: filteredDocs.length,
                              ),
                            ),
                          );
                        },
                      ),

                      // ✅ 3. BOTTOM SPACING
                      const SliverToBoxAdapter(child: SizedBox(height: 140)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: const _QuickAddFAB(),
      bottomNavigationBar: const _DeckBottomNavBar(activeIndex: 1),
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// TOP BAR
// ─────────────────────────────────────────────────────────────────────────────

class _DeckTopBar extends StatelessWidget {
  const _DeckTopBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background.withOpacity(0.80),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // ── Avatar + Brand ───────────────────────────────────────────────
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryContainer,
              border: Border.all(
                color: AppColors.primary.withOpacity(0.2),
                width: 2,
              ),
            ),
            child: const Icon(Icons.person_rounded,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 10),
          Text(
            'Study Buddy',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              letterSpacing: -0.4,
            ),
          ),
          const Spacer(),

          // ── Sync status chip ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: AppColors.onSurface.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.cloud_done_outlined,
                    color: AppColors.primary, size: 18),
                const SizedBox(width: 5),
                Text(
                  'SYNCED',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    letterSpacing: 1.2,
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
// HERO GREETING
// ─────────────────────────────────────────────────────────────────────────────

class _HeroGreeting extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hello, Active Scholar! 👋',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
            letterSpacing: -0.6,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Ready to master your knowledge today?',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SEARCH BAR
// ─────────────────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        style: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          color: AppColors.onSurface,
        ),
        decoration: InputDecoration(
          hintText: 'Search your knowledge base...',
          hintStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            color: AppColors.outline.withOpacity(0.6),
          ),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 6),
            child:
                Icon(Icons.search_rounded, color: AppColors.outline, size: 22),
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FILTER CHIP
// ─────────────────────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(999),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: active ? AppColors.onPrimary : AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI IMPORT CARD
// ─────────────────────────────────────────────────────────────────────────────

class _AIImportCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryFixedDim],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.28),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Icon + Title ─────────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Smart AI Import',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    'Convert any content into flashcards',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.75),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Import options ───────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _ImportOption(
                  icon: Icons.upload_file_rounded,
                  label: 'Upload PDF / TXT',
                  onTap: () {},
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ImportOption(
                  icon: Icons.content_paste_rounded,
                  label: 'Paste Notes',
                  onTap: () {},
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImportOption extends StatelessWidget {
  const _ImportOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CREATE DECK CARD (dashed border)
// ─────────────────────────────────────────────────────────────────────────────

class _CreateDeckCard extends StatefulWidget {
  @override
  State<_CreateDeckCard> createState() => _CreateDeckCardState();
}

class _CreateDeckCardState extends State<_CreateDeckCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushNamed('/create-deck');
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.primary.withOpacity(0.05)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _hovered
                  ? AppColors.primary.withOpacity(0.5)
                  : AppColors.outlineVariant.withOpacity(0.5),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _hovered
                      ? AppColors.primaryContainer
                      : AppColors.surfaceContainerLow,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: _hovered ? AppColors.primary : AppColors.outline,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create New Deck',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                  Text(
                    'Start from scratch manually',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DECK CARD
// ─────────────────────────────────────────────────────────────────────────────

class _DeckCard extends StatelessWidget {
  const _DeckCard({
    required this.deckId,
    required this.deckTitle,
    required this.tag,
    required this.tagColor,
    required this.tagTextColor,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.progressColor,
  });

  final String deckId;
  final String deckTitle;
  final String tag;
  final Color tagColor;
  final Color tagTextColor;
  final String title;
  final String subtitle;
  final double progress;
  final Color progressColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed(
        '/quiz',
        arguments: QuizArgs(deckId: deckId, deckTitle: deckTitle),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.onSurface.withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Tag + More icon ───────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: tagColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    tag.toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: tagTextColor,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _showDeckMenu(context),
                  child: Icon(Icons.more_vert_rounded,
                      color: AppColors.outline, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Title + subtitle ──────────────────────────────────────────
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),

            // ── Progress bar ──────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'MASTERY PROGRESS',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.outline,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  '${(progress * 100).round()}%',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.outline,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppColors.outlineVariant.withOpacity(0.25),
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeckMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _DeckOptionsSheet(deckId: deckId, deckTitle: deckTitle),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DECK OPTIONS SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _DeckOptionsSheet extends StatelessWidget {
  const _DeckOptionsSheet({
    required this.deckId,
    required this.deckTitle,
  });

  final String deckId;
  final String deckTitle;

  // ── Navigate to Edit Deck ─────────────────────────────────────────────────
  void _handleEdit(BuildContext context) {
    Navigator.pop(context); // close sheet
    Navigator.of(context).pushNamed(
      '/edit-deck',
      arguments: EditDeckArgs(deckId: deckId, deckTitle: deckTitle),
    );
  }

  // ── Confirm + Delete whole deck ───────────────────────────────────────────
  void _handleDelete(BuildContext context) async {
    // Show dialog WHILE sheet is still visible so context is valid
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: AppColors.surfaceContainerLowest,
        title: Text(
          'Delete "$deckTitle"?',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
          ),
        ),
        content: Text(
          'This will permanently delete the deck and all its cards. This action cannot be undone.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(_, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(_, true),
            child: Text(
              'Delete',
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.error,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    Navigator.pop(context); // close sheet

    try {
      await DeckService.deleteDeck(deckId);
      // The Firestore stream in _DeckHubScaffold auto-refreshes the list.
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to delete deck.',
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.outlineVariant,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 8),
          _SheetOption(
            icon: Icons.play_arrow_rounded,
            label: 'Study This Deck',
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).pushNamed(
                '/quiz',
                arguments: QuizArgs(deckId: deckId, deckTitle: deckTitle),
              );
            },
          ),
          _SheetOption(
            icon: Icons.edit_outlined,
            label: 'Edit Deck',
            onTap: () => _handleEdit(context),
          ),
          _SheetOption(
            icon: Icons.share_outlined,
            label: 'Share',
            onTap: () => Navigator.pop(context),
          ),
          _SheetOption(
            icon: Icons.delete_outline_rounded,
            label: 'Delete Deck',
            color: AppColors.error,
            onTap: () => _handleDelete(context),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  const _SheetOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.onSurface;
    return ListTile(
      leading: Icon(icon, color: c, size: 22),
      title: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: c,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QUICK ADD FAB
// ─────────────────────────────────────────────────────────────────────────────

class _QuickAddFAB extends StatelessWidget {
  const _QuickAddFAB();

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () {},
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      icon: const Icon(Icons.add_rounded, size: 24),
      label: Text(
        'Quick Add',
        style: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w800,
          fontSize: 14,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM NAV BAR
// ─────────────────────────────────────────────────────────────────────────────

class _DeckBottomNavBar extends StatelessWidget {
  const _DeckBottomNavBar({required this.activeIndex});
  final int activeIndex;

  static const _items = [
    _NavItem(icon: Icons.home_outlined, label: 'Home', route: '/home'),
    _NavItem(icon: Icons.layers_outlined, label: 'Decks', route: '/decks'),
    _NavItem(
        icon: Icons.analytics_outlined, label: 'Progress', route: '/progress'),
    _NavItem(
        icon: Icons.person_outline_rounded,
        label: 'Profile',
        route: '/profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withOpacity(0.06),
            blurRadius: 32,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
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
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.primaryContainer.withOpacity(0.45)
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

  static final _filledIconMap = {
    Icons.home_outlined: Icons.home_rounded,
    Icons.layers_outlined: Icons.layers_rounded,
    Icons.analytics_outlined: Icons.analytics_rounded,
    Icons.person_outline_rounded: Icons.person_rounded,
  };

  IconData _filledIcon(IconData icon) => _filledIconMap[icon] ?? icon;
}

class _NavItem {
  const _NavItem(
      {required this.icon, required this.label, required this.route});
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
