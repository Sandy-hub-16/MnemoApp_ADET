import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import '../../landing_page/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'deck_quiz_screen.dart';
import 'edit_deck_screen.dart';
import 'create_deck_screen.dart';
import 'create_deck_options.dart';
import 'deck_study_screen.dart';
import '../../../business-layer/services/deck_service.dart';
import '../../../business-layer/services/export_service.dart';
import '../../../business-layer/services/share_service.dart';
import '../../../business-layer/services/deck_search_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DECK SCREEN  —  route: /decks
// Displays the main deck library with AI import, filters, and deck cards.
//
// SECTIONS:
//   1. Static content  — hero, search bar, filter chips, AI import, create card
//   2. Drafts          — unfinished decks (isDraft:true); tap → /create-deck
//   3. Recent Decks    — completed decks (isDraft:false); tap → /quiz
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// DECK HUB SCREEN
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
<<<<<<< HEAD
  String? _selectedTag; // null = "All Decks"; set to a tag string to filter
  List<String> _availableTags = []; // derived live from Firestore
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _deckSubscription;
=======
  int _selectedFilter = 0;
  bool _draftsExpanded = false;

  static const _filters = [
    'All Decks',
    'Biology',
    'Physics',
    'Organic Chem',
    'World History',
  ];
>>>>>>> ff97d7672ed03169de17e1ebedce4e8b5626f234

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _searchQuery = '';
  List<QueryDocumentSnapshot<Map<String, dynamic>>>? _cachedResults;
  final DeckSearchEngine<QueryDocumentSnapshot<Map<String, dynamic>>> _engine =
      DeckSearchEngine();

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      ShareService.repairCardCounts(uid: uid).catchError((_) {});
    }
    _searchController.addListener(_onSearchChanged);
    _deckSubscription = _deckStream().listen((snap) {
      final tags = snap.docs
          .map((d) => d.data()['tag'] as String? ?? '')
          .where((t) => t.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      if (mounted) {
        setState(() {
          _availableTags = tags;
          // If the user deleted all decks of the selected tag, reset to All
          if (_selectedTag != null && !tags.contains(_selectedTag)) {
            _selectedTag = null;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    _deckSubscription?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () async {
      final keyword = _searchController.text.trim().toLowerCase();
      if (_engine.length < 500) {
        if (mounted) {
          setState(() {
            _searchQuery = keyword;
            _cachedResults = null;
          });
        }
      } else {
        final activeTag = _selectedTag;
        try {
          await compute(runIsolateQuery, (
            index: _engine.snapshot(
                tagOf: (doc) => doc.data()['tag'] as String? ?? ''),
            keyword: keyword,
            tagFilter: activeTag,
          ));
          if (mounted) {
            setState(() {
              _searchQuery = keyword;
              _cachedResults = null;
            });
          }
        } catch (_) {
          if (mounted) {
            setState(() {
              _searchQuery = keyword;
              _cachedResults = null;
            });
          }
        }
      }
    });
  }

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

  Future<void> _continueDraft(
    BuildContext context,
    String deckId,
    Map<String, dynamic> data,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    try {
      final savedCards = await DeckService.getDeckCards(deckId);
      if (!context.mounted) return;
      Navigator.pop(context);

      Navigator.of(context).pushNamed(
        '/create-deck',
        arguments: ContinueDraftArgs(
          draftId: deckId,
          title: data['title'] ?? '',
          tag: data['tag'] ?? 'Other',
          targetCardCount: (data['targetCardCount'] ?? 10) as int,
          savedCards: savedCards,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      showCreateDeckErrorSnackBar(
          context, 'Could not load draft. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: Stack(
        children: [
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
                Expanded(
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            _HeroGreeting(),
                            const SizedBox(height: 20),
                            _SearchBar(controller: _searchController),
                            if (_availableTags.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 40,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _availableTags.length +
                                      1, // +1 for "All Decks"
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 8),
                                  itemBuilder: (context, i) {
                                    if (i == 0) {
                                      return _FilterChip(
                                        label: 'All Decks',
                                        active: _selectedTag == null,
                                        onTap: () =>
                                            setState(() => _selectedTag = null),
                                      );
                                    }
                                    final tag = _availableTags[i - 1];
                                    return _FilterChip(
                                      label: tag,
                                      active: _selectedTag == tag,
                                      onTap: () =>
                                          setState(() => _selectedTag = tag),
                                    );
                                  },
                                ),
                              ),
                            ],
                            const SizedBox(height: 28),
                          ]),
                        ),
                      ),
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _deckStream(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 40),
                                child: Center(
                                  child: CircularProgressIndicator(
                                      color: AppColors.primary),
                                ),
                              ),
                            );
                          }

                          final allDocs = snapshot.data?.docs ?? [];

                          // Rebuild the search index on every Firestore emission
                          _engine.rebuild(
                            allDocs,
                            (doc) =>
                                '${doc.data()['title'] ?? ''} ${doc.data()['tag'] ?? ''}'
                                    .toLowerCase(),
                          );

                          final String? tagFilter = _selectedTag;

                          // Apply search + tag filter via the engine
                          final filteredDocs =
                              (_cachedResults != null && _engine.length >= 500)
                                  ? _cachedResults!
                                  : _engine.query(
                                      _searchQuery,
                                      tagFilter: tagFilter,
                                      tagOf: (doc) =>
                                          doc.data()['tag'] as String? ?? '',
                                    );

                          final draftDocs = filteredDocs
                              .where((d) => d.data()['isDraft'] == true)
                              .toList();

                          final completedDocs = filteredDocs
                              .where((d) => d.data()['isDraft'] != true)
                              .toList();

                          final items = <Widget>[];

                          if (draftDocs.isNotEmpty) {
                            items.add(
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 0, 20, 24),
                                child: _DraftsAccordionSection(
                                  draftDocs: draftDocs,
                                  expanded: _draftsExpanded,
                                  onToggle: () => setState(
                                      () => _draftsExpanded = !_draftsExpanded),
                                  onContinue: (id, data) =>
                                      _continueDraft(context, id, data),
                                  onDelete: (id, title) =>
                                      _confirmDeleteDraft(context, id, title),
                                ),
                              ),
                            );
                          }

                          items.add(
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                              child: Text(
                                'Recent Decks',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.onSurface,
                                ),
                              ),
                            ),
                          );

                          if (completedDocs.isEmpty) {
                            final hasDecksButFiltered =
                                allDocs.any((d) => d.data()['isDraft'] != true);
                            items.add(
                              Padding(
                                padding: const EdgeInsets.all(40),
                                child: hasDecksButFiltered
                                    ? Column(
                                        children: [
                                          Icon(
                                            Icons.search_off_rounded,
                                            size: 64,
                                            color: AppColors.outline
                                                .withOpacity(0.5),
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'No decks found',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.onSurface,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            _searchQuery.isNotEmpty
                                                ? 'No decks match "$_searchQuery". Try a different keyword or clear the filter.'
                                                : 'No decks match the active filter.',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 14,
                                              color: AppColors.onSurfaceVariant,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      )
                                    : Column(
                                        children: [
                                          Icon(Icons.layers_outlined,
                                              size: 64,
                                              color: AppColors.outline),
                                          const SizedBox(height: 16),
                                          Text(
                                            'No decks yet',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.onSurface,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Create your first deck to get started!',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 14,
                                              color: AppColors.onSurfaceVariant,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                              ),
                            );
                          } else {
                            for (final doc in completedDocs) {
                              final deck = doc.data();
                              items.add(
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(20, 0, 20, 12),
                                  child: _DeckCard(
                                    deckId: doc.id,
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
                                    visibility: deck['visibility'] as String? ??
                                        'private',
                                    clonedFromUsername:
                                        deck['clonedFromUsername'] as String?,
                                    createdAt: (deck['createdAt'] as Timestamp?)
                                        ?.toDate(),
                                  ),
                                ),
                              );
                            }
                          }

                          return SliverList(
                            delegate: SliverChildListDelegate(items),
                          );
                        },
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 140)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteDraft(
      BuildContext context, String deckId, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: AppColors.surfaceContainerLowest,
        title: Text(
          'Delete draft "$title"?',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
          ),
        ),
        content: Text(
          'This will permanently delete this unfinished deck. This action cannot be undone.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(_, false),
            child: Text('Cancel',
                style: GoogleFonts.plusJakartaSans(
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(_, true),
            child: Text('Delete',
                style: GoogleFonts.plusJakartaSans(
                    color: AppColors.error, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    try {
      await DeckService.deleteDeck(deckId);
    } catch (e) {
      if (context.mounted) {
        showCreateDeckErrorSnackBar(context, 'Failed to delete draft.');
      }
    }
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
          'Your Deck Library',
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
          'Create, import, and organize your flashcard decks',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.onSurfaceVariant,
            height: 1.4,
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
  const _SearchBar({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.text,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.outlineVariant.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.onSurface.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: controller,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppColors.onSurface,
          ),
          decoration: InputDecoration(
            hintText: 'Search your decks...',
            hintStyle: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.onSurfaceVariant.withOpacity(0.6),
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 16, right: 12),
              child: Icon(
                Icons.search_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (_, value, __) {
                if (value.text.isEmpty) return const SizedBox.shrink();
                return IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: AppColors.onSurfaceVariant,
                    size: 20,
                  ),
                  onPressed: () => controller.clear(),
                );
              },
            ),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryFixedDim],
                  )
                : null,
            color: active ? null : AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active
                  ? AppColors.primary.withOpacity(0.3)
                  : AppColors.outlineVariant.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
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
              color: active ? Colors.white : AppColors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DRAFTS ACCORDION SECTION
// Collapsed by default — header always visible, draft cards only render
// once expanded. Keeps the same warm amber palette as the draft cards
// themselves so the whole section reads as one cohesive unit.
// ─────────────────────────────────────────────────────────────────────────────

class _DraftsAccordionSection extends StatelessWidget {
  const _DraftsAccordionSection({
    required this.draftDocs,
    required this.expanded,
    required this.onToggle,
    required this.onContinue,
    required this.onDelete,
  });

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> draftDocs;
  final bool expanded;
  final VoidCallback onToggle;
  final void Function(String deckId, Map<String, dynamic> data) onContinue;
  final void Function(String deckId, String title) onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF0),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFFD95C).withOpacity(0.7),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD95C).withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header — always visible, tap anywhere to toggle ─────────────
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onToggle,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3CD),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.edit_note_rounded,
                            size: 14,
                            color: Color(0xFF856404),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'DRAFTS',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF856404),
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Unfinished Decks',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Count chip — visible whether expanded or not, so the
                    // collapsed state still communicates how many drafts exist.
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF856404).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${draftDocs.length}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF856404),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF856404),
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Body — draft cards, only built once expanded ────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !expanded
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final doc in draftDocs)
                          Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 8),
                            child: _DraftDeckCard(
                              deckId: doc.id,
                              data: doc.data(),
                              onContinue: () => onContinue(doc.id, doc.data()),
                              onDelete: () => onDelete(doc.id,
                                  doc.data()['title'] as String? ?? 'Untitled'),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DRAFT DECK CARD
// ─────────────────────────────────────────────────────────────────────────────

class _DraftDeckCard extends StatelessWidget {
  const _DraftDeckCard({
    required this.deckId,
    required this.data,
    required this.onContinue,
    required this.onDelete,
  });

  final String deckId;
  final Map<String, dynamic> data;
  final VoidCallback onContinue;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final title = data['title'] as String? ?? 'Untitled';
    final tag = data['tag'] as String? ?? 'Other';
    final cardCount = (data['cardCount'] ?? 0) as int;
    final targetCardCount = (data['targetCardCount'] ?? 10) as int;
    final ratio = targetCardCount > 0
        ? (cardCount / targetCardCount).clamp(0.0, 1.0)
        : 0.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onContinue,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBF0),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFFFD95C).withOpacity(0.7),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD95C).withOpacity(0.15),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBA0),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          tag.toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF856404),
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF856404).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: const Color(0xFF856404).withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.hourglass_top_rounded,
                              size: 10,
                              color: Color(0xFF856404),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'DRAFT',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF856404),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => _showDraftMenu(context),
                      child: const Icon(Icons.more_vert_rounded,
                          color: Color(0xFFAA8800), size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
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
                'Tap to continue building this deck',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: const Color(0xFFAA8800),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'CARDS COMPLETED',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFAA8800),
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    '$cardCount / $targetCardCount',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFAA8800),
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFFFD95C).withOpacity(0.25),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Color(0xFFFFB800)),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB800),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.edit_rounded,
                        size: 14, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      'Continue Draft',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              if (data['createdAt'] != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 11,
                      color: const Color(0xFFAA8800).withOpacity(0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDeckDate(
                          (data['createdAt'] as Timestamp).toDate()),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        color: const Color(0xFFAA8800).withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showDraftMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _DraftOptionsSheet(
        deckId: deckId,
        deckTitle: data['title'] ?? 'Untitled',
        onContinue: onContinue,
        onDelete: onDelete,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DRAFT OPTIONS SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _DraftOptionsSheet extends StatelessWidget {
  const _DraftOptionsSheet({
    required this.deckId,
    required this.deckTitle,
    required this.onContinue,
    required this.onDelete,
  });

  final String deckId;
  final String deckTitle;
  final VoidCallback onContinue;
  final VoidCallback onDelete;

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
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.hourglass_top_rounded,
                          size: 11, color: Color(0xFF856404)),
                      const SizedBox(width: 4),
                      Text(
                        'DRAFT',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF856404),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    deckTitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline_rounded,
                      size: 16, color: AppColors.outline),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Finish this deck to unlock Quiz & Edit',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _SheetOption(
            icon: Icons.edit_rounded,
            label: 'Continue Draft',
            color: const Color(0xFFAA8800),
            onTap: () {
              Navigator.pop(context);
              onContinue();
            },
          ),
          _SheetOption(
            icon: Icons.delete_outline_rounded,
            label: 'Delete Draft',
            color: AppColors.error,
            onTap: () {
              Navigator.pop(context);
              onDelete();
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DECK CARD (completed decks only)
// ─────────────────────────────────────────────────────────────────────────────

class _DeckCard extends StatefulWidget {
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
    required this.visibility,
    this.clonedFromUsername,
    this.createdAt,
  });

  final String deckId;
  final String deckTitle;
  final Color tagColor;
  final Color tagTextColor;
  final String tag;
  final String title;
  final String subtitle;
  final double progress;
  final Color progressColor;
  final String visibility;
  final String? clonedFromUsername;
  final DateTime? createdAt;

  @override
  State<_DeckCard> createState() => _DeckCardState();
}

class _DeckCardState extends State<_DeckCard> {
  late String _currentVisibility;

  @override
  void initState() {
    super.initState();
    _currentVisibility = widget.visibility;
  }

  @override
  void didUpdateWidget(_DeckCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visibility != widget.visibility) {
      _currentVisibility = widget.visibility;
    }
  }

  void _onVisibilityChanged(String newVisibility) {
    setState(() => _currentVisibility = newVisibility);
  }

  @override
  Widget build(BuildContext context) {
    final isPublic = _currentVisibility == 'public';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => Navigator.of(context).pushNamed(
          '/quiz',
          arguments:
              QuizArgs(deckId: widget.deckId, deckTitle: widget.deckTitle),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: widget.tagColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          widget.tag.toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: widget.tagTextColor,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isPublic
                              ? AppColors.primary.withOpacity(0.10)
                              : AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: isPublic
                                ? AppColors.primary.withOpacity(0.35)
                                : AppColors.outlineVariant,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPublic
                                  ? Icons.public_rounded
                                  : Icons.lock_outline_rounded,
                              size: 11,
                              color: isPublic
                                  ? AppColors.primary
                                  : AppColors.outline,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isPublic ? 'Public' : 'Private',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: isPublic
                                    ? AppColors.primary
                                    : AppColors.outline,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => _showDeckMenu(context),
                      child: Icon(Icons.more_vert_rounded,
                          color: AppColors.outline, size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.subtitle,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (widget.clonedFromUsername != null &&
                  widget.clonedFromUsername!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      size: 11,
                      color: AppColors.outline,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Cloned from @${widget.clonedFromUsername}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        color: AppColors.outline,
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
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
                    '${(widget.progress * 100).round()}%',
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
                  value: widget.progress,
                  minHeight: 8,
                  backgroundColor: AppColors.outlineVariant.withOpacity(0.25),
                  valueColor:
                      AlwaysStoppedAnimation<Color>(widget.progressColor),
                ),
              ),
              if (widget.createdAt != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 11,
                      color: AppColors.outline.withOpacity(0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDeckDate(widget.createdAt!),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        color: AppColors.outline.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showDeckMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _DeckOptionsSheet(
        deckId: widget.deckId,
        deckTitle: widget.deckTitle,
        currentVisibility: _currentVisibility,
        onVisibilityChanged: _onVisibilityChanged,
        onExport: () async {
          final format = await _showExportFormatDialog(context);
          if (format == null || !context.mounted) return;
          await ExportService.exportDeck(
            context: context,
            deckId: widget.deckId,
            deckTitle: widget.deckTitle,
            format: format,
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DECK OPTIONS SHEET (completed decks)
// ─────────────────────────────────────────────────────────────────────────────

class _DeckOptionsSheet extends StatefulWidget {
  const _DeckOptionsSheet({
    required this.deckId,
    required this.deckTitle,
    required this.currentVisibility,
    required this.onVisibilityChanged,
    required this.onExport,
  });

  final String deckId;
  final String deckTitle;
  final String currentVisibility;
  final ValueChanged<String> onVisibilityChanged;
  final VoidCallback onExport;

  @override
  State<_DeckOptionsSheet> createState() => _DeckOptionsSheetState();
}

class _DeckOptionsSheetState extends State<_DeckOptionsSheet> {
  bool _isTogglingVisibility = false;

  void _handleEdit(BuildContext context) {
    Navigator.pop(context);
    Navigator.of(context).pushNamed(
      '/edit-deck',
      arguments:
          EditDeckArgs(deckId: widget.deckId, deckTitle: widget.deckTitle),
    );
  }

  void _handleDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: AppColors.surfaceContainerLowest,
        title: Text(
          'Delete "${widget.deckTitle}"?',
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
            child: Text('Cancel',
                style: GoogleFonts.plusJakartaSans(
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(_, true),
            child: Text('Delete',
                style: GoogleFonts.plusJakartaSans(
                    color: AppColors.error, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // REPLACE WITH:
    try {
      await DeckService.deleteDeck(widget.deckId);
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.20),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete_rounded,
                      color: Colors.white, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Deck deleted',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '"${widget.deckTitle}" has been removed',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.85),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        showCreateDeckErrorSnackBar(context, 'Failed to delete deck.');
      }
    }
  }

  Future<void> _handleVisibilityToggle(BuildContext context) async {
    if (_isTogglingVisibility) return;

    final newVisibility =
        widget.currentVisibility == 'public' ? 'private' : 'public';

    setState(() => _isTogglingVisibility = true);

    try {
      await ShareService.setVisibility(
        deckId: widget.deckId,
        visibility: newVisibility,
      );

      widget.onVisibilityChanged(newVisibility);

      if (context.mounted) Navigator.pop(context);
    } on StateError catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        showCreateDeckErrorSnackBar(context, e.message);
      }
    } on ArgumentError {
      if (context.mounted) Navigator.pop(context);
    } catch (e, st) {
      debugPrint('[ShareService.setVisibility] error: $e\n$st');
      if (context.mounted) {
        Navigator.pop(context);
        showCreateDeckErrorSnackBar(
            context, 'Failed to update visibility. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isTogglingVisibility = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPublic = widget.currentVisibility == 'public';

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
            icon: Icons.auto_stories_rounded,
            label: 'Browse Cards',
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).pushNamed(
                '/study',
                arguments: StudyScreenArgs(
                    deckId: widget.deckId, deckTitle: widget.deckTitle),
              );
            },
          ),
          _SheetOption(
            icon: Icons.edit_outlined,
            label: 'Edit Deck',
            onTap: () => _handleEdit(context),
          ),
          _isTogglingVisibility
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              : ListTile(
                  leading: Icon(
                    isPublic
                        ? Icons.lock_outline_rounded
                        : Icons.public_rounded,
                    color: isPublic
                        ? AppColors.onSurfaceVariant
                        : AppColors.primary,
                    size: 22,
                  ),
                  title: Text(
                    isPublic ? 'Make Private' : 'Make Public',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isPublic ? AppColors.onSurface : AppColors.primary,
                    ),
                  ),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPublic
                          ? AppColors.primary.withOpacity(0.10)
                          : AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isPublic
                            ? AppColors.primary.withOpacity(0.35)
                            : AppColors.outlineVariant,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      isPublic ? 'Public' : 'Private',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isPublic ? AppColors.primary : AppColors.outline,
                      ),
                    ),
                  ),
                  onTap: () => _handleVisibilityToggle(context),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
          _SheetOption(
            icon: Icons.ios_share_rounded,
            label: 'Export Deck',
            onTap: () {
              Navigator.pop(context); // close options sheet
              widget.onExport();
            },
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

// ─────────────────────────────────────────────────────────────────────────────
// EXPORT FORMAT DIALOG
// ─────────────────────────────────────────────────────────────────────────────

Future<ExportFormat?> _showExportFormatDialog(BuildContext context) {
  return showModalBottomSheet<ExportFormat>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ExportFormatDialog(),
  );
}

class _ExportFormatDialog extends StatelessWidget {
  const _ExportFormatDialog();

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
          // ── Drag handle ──────────────────────────────────────────────────
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.outlineVariant,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 16),

          // ── Header ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryFixedDim],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.ios_share_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Export Deck',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'Choose a format',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── PDF option ───────────────────────────────────────────────────
          _SheetOption(
            icon: Icons.picture_as_pdf_rounded,
            label: 'Save as PDF',
            onTap: () => Navigator.pop(context, ExportFormat.pdf),
          ),

          // ── Plain Text option ────────────────────────────────────────────
          _SheetOption(
            icon: Icons.text_snippet_outlined,
            label: 'Save as Plain Text (.txt)',
            onTap: () => Navigator.pop(context, ExportFormat.plainText),
          ),

          // ── Cancel ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context, null),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHEET OPTION (shared by deck options and export format dialog)
// ─────────────────────────────────────────────────────────────────────────────

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
// DATE FORMATTER
// ─────────────────────────────────────────────────────────────────────────────

String _formatDeckDate(DateTime dt) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final period = dt.hour >= 12 ? 'PM' : 'AM';
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year} · $hour:$minute $period';
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
