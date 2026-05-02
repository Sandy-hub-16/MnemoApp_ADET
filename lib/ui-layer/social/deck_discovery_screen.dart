import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../landing_page/app_theme.dart';
import '../../data-layer/social/public_deck_summary.dart';
import '../../data-layer/social/social_route_args.dart';
import 'widgets/public_deck_card.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DECK DISCOVERY SCREEN  —  route: /discover
//
// Paginated catalogue of all public decks. Supports:
//   • Client-side keyword search (title contains keyword, case-insensitive)
//   • Tag filter (re-queries Firestore with where('tag', isEqualTo: tag))
//   • Infinite scroll pagination (page size 20, startAfterDocument)
//
// Architecture: public StatelessWidget → private StatefulWidget _Body
// ─────────────────────────────────────────────────────────────────────────────

class DeckDiscoveryScreen extends StatelessWidget {
  const DeckDiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _DeckDiscoveryBody();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BODY
// ─────────────────────────────────────────────────────────────────────────────

class _DeckDiscoveryBody extends StatefulWidget {
  const _DeckDiscoveryBody();

  @override
  State<_DeckDiscoveryBody> createState() => _DeckDiscoveryBodyState();
}

class _DeckDiscoveryBodyState extends State<_DeckDiscoveryBody> {
  // ── State ─────────────────────────────────────────────────────────────────

  final TextEditingController _searchController = TextEditingController();
  String? _activeTag;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDoc;
  List<PublicDeckSummary> _decks = [];

  static const int _pageSize = 20;

  // Tags available as filter chips — matches the tags used in create_deck_screen
  static const List<String> _tags = [
    'Biology',
    'Physics',
    'Organic Chem',
    'World History',
    'History',
    'Math',
    'Other',
  ];

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadFirstPage();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  /// Builds the base Firestore query, optionally filtered by [_activeTag].
  Query<Map<String, dynamic>> _baseQuery() {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('public_decks')
        .orderBy('sharedAt', descending: true);

    if (_activeTag != null) {
      q = q.where('tag', isEqualTo: _activeTag);
    }

    return q;
  }

  /// Loads the first page of results, replacing any existing data.
  Future<void> _loadFirstPage() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _decks = [];
      _lastDoc = null;
      _hasMore = true;
    });

    try {
      final snapshot = await _baseQuery().limit(_pageSize).get();
      final docs = snapshot.docs;

      setState(() {
        _decks = docs
            .map((d) => PublicDeckSummary.fromFirestore(
                d as DocumentSnapshot<Map<String, dynamic>>))
            .toList();
        _lastDoc = docs.isNotEmpty ? docs.last : null;
        _hasMore = docs.length == _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Failed to load decks. Please try again.');
      }
    }
  }

  /// Loads the next page of results, appending to existing data.
  Future<void> _loadNextPage() async {
    if (_isLoadingMore || !_hasMore || _lastDoc == null) return;
    setState(() => _isLoadingMore = true);

    try {
      final snapshot = await _baseQuery()
          .startAfterDocument(_lastDoc!)
          .limit(_pageSize)
          .get();
      final docs = snapshot.docs;

      setState(() {
        _decks.addAll(docs.map((d) => PublicDeckSummary.fromFirestore(
            d as DocumentSnapshot<Map<String, dynamic>>)));
        _lastDoc = docs.isNotEmpty ? docs.last : _lastDoc;
        _hasMore = docs.length == _pageSize;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
        _showErrorSnackBar('Failed to load more decks.');
      }
    }
  }

  // ── Filtering ─────────────────────────────────────────────────────────────

  /// Returns the subset of [_decks] matching the current search keyword.
  List<PublicDeckSummary> get _filteredDecks {
    final keyword = _searchController.text.trim().toLowerCase();
    if (keyword.isEmpty) return _decks;
    return _decks
        .where((d) => d.title.toLowerCase().contains(keyword))
        .toList();
  }

  /// Activates or deactivates a tag filter and reloads from Firestore.
  void _onTagSelected(String tag) {
    final newTag = _activeTag == tag ? null : tag;
    setState(() => _activeTag = newTag);
    _loadFirstPage();
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _openDeckDetail(PublicDeckSummary deck) {
    Navigator.of(context).pushNamed(
      '/shared-deck-detail',
      arguments: SharedDeckDetailArgs(
        deckId: deck.deckId,
        ownerUid: deck.ownerUid,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      ),
    );
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
            bottom: false,
            child: Column(
              children: [
                // ── Top bar ───────────────────────────────────────────────
                const _DiscoveryTopBar(),

                // ── Search + filters ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SearchField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 14),
                      _TagFilterRow(
                        tags: _tags,
                        activeTag: _activeTag,
                        onTagSelected: _onTagSelected,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Deck list ─────────────────────────────────────────────
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        )
                      : _DeckList(
                          decks: _filteredDecks,
                          isLoadingMore: _isLoadingMore,
                          hasMore: _hasMore,
                          onLoadMore: _loadNextPage,
                          onTap: _openDeckDetail,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const _DiscoveryBottomNavBar(activeIndex: 2),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOP BAR
// ─────────────────────────────────────────────────────────────────────────────

class _DiscoveryTopBar extends StatelessWidget {
  const _DiscoveryTopBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background.withValues(alpha: 0.80),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
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
            child: const Icon(
              Icons.explore_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Discover',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              letterSpacing: -0.4,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: AppColors.onSurface.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.public_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
                const SizedBox(width: 5),
                Text(
                  'COMMUNITY',
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
// SEARCH FIELD
// ─────────────────────────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          color: AppColors.onSurface,
        ),
        decoration: InputDecoration(
          hintText: 'Search public decks...',
          hintStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            color: AppColors.outline.withValues(alpha: 0.6),
          ),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 6),
            child: Icon(
              Icons.search_rounded,
              color: AppColors.outline,
              size: 22,
            ),
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, __) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.outline,
                  size: 20,
                ),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              );
            },
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
// TAG FILTER ROW
// ─────────────────────────────────────────────────────────────────────────────

class _TagFilterRow extends StatelessWidget {
  const _TagFilterRow({
    required this.tags,
    required this.activeTag,
    required this.onTagSelected,
  });

  final List<String> tags;
  final String? activeTag;
  final ValueChanged<String> onTagSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tags.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final tag = tags[i];
          final active = activeTag == tag;
          return GestureDetector(
            onTap: () => onTagSelected(tag),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: active
                    ? AppColors.primary
                    : AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(999),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : [],
              ),
              child: Text(
                tag,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: active
                      ? AppColors.onPrimary
                      : AppColors.onSurfaceVariant,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DECK LIST
//
// Renders the filtered deck list with infinite scroll and empty state.
// ─────────────────────────────────────────────────────────────────────────────

class _DeckList extends StatefulWidget {
  const _DeckList({
    required this.decks,
    required this.isLoadingMore,
    required this.hasMore,
    required this.onLoadMore,
    required this.onTap,
  });

  final List<PublicDeckSummary> decks;
  final bool isLoadingMore;
  final bool hasMore;
  final VoidCallback onLoadMore;
  final ValueChanged<PublicDeckSummary> onTap;

  @override
  State<_DeckList> createState() => _DeckListState();
}

class _DeckListState extends State<_DeckList> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      widget.onLoadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.decks.isEmpty) {
      return _EmptyState();
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 140),
      itemCount: widget.decks.length + (widget.isLoadingMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == widget.decks.length) {
          // Loading more indicator at the bottom
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        final deck = widget.decks[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: PublicDeckCard(
            deck: deck,
            onTap: () => widget.onTap(deck),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 72,
              color: AppColors.outline.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 20),
            Text(
              'No decks found',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term or tag filter.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.onSurfaceVariant,
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

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM NAV BAR
//
// Mirrors the pattern from _HomeBottomNavBar. Discover is index 2 (per task 14
// which will shift Progress → 3 and Profile → 4). For now this nav bar is
// self-contained and navigates to the same routes as the other screens.
// ─────────────────────────────────────────────────────────────────────────────

class _DiscoveryBottomNavBar extends StatelessWidget {
  const _DiscoveryBottomNavBar({required this.activeIndex});

  final int activeIndex;

  static const _items = [
    _NavItem(icon: Icons.home_outlined, label: 'Home', route: '/home'),
    _NavItem(icon: Icons.layers_outlined, label: 'Decks', route: '/decks'),
    _NavItem(
        icon: Icons.explore_outlined, label: 'Discover', route: '/discover'),
    _NavItem(
        icon: Icons.analytics_outlined,
        label: 'Progress',
        route: '/progress'),
    _NavItem(
        icon: Icons.person_outline_rounded,
        label: 'Profile',
        route: '/profile'),
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
                          fontSize: 10,
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
  const _NavItem(
      {required this.icon, required this.label, required this.route});
  final IconData icon;
  final String label;
  final String route;
}
