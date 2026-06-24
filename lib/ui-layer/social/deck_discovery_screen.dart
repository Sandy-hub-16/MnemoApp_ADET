import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../landing_page/app_theme.dart';
import '../../data-layer/models/social/public_deck_summary.dart';
import '../../data-layer/route_args/social_route_args.dart';
import '../../business-layer/services/deck_search_engine.dart';
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
  final DeckSearchEngine<PublicDeckSummary> _engine = DeckSearchEngine();
  Timer? _debounce;
  String _searchQuery = '';
  List<PublicDeckSummary>? _cachedResults;
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
    _searchController.addListener(_onSearchChanged);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ── Search ────────────────────────────────────────────────────────────────

  static String _summaryKey(PublicDeckSummary s) =>
      '${s.title} ${s.tag} ${s.ownerUsername}'.toLowerCase();

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
        try {
          await compute(runIsolateQuery, (
            index: _engine.snapshot(tagOf: (s) => s.tag),
            keyword: keyword,
            tagFilter: _activeTag,
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
      _engine.rebuild(_decks, _summaryKey);
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

      final newDecks = docs
          .map((d) => PublicDeckSummary.fromFirestore(
              d as DocumentSnapshot<Map<String, dynamic>>))
          .toList();
      setState(() {
        _decks.addAll(newDecks);
        _lastDoc = docs.isNotEmpty ? docs.last : _lastDoc;
        _hasMore = docs.length == _pageSize;
        _isLoadingMore = false;
      });
      _engine.extend(newDecks, _summaryKey);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
        _showErrorSnackBar('Failed to load more decks.');
      }
    }
  }

  // ── Filtering ─────────────────────────────────────────────────────────────

  /// Returns the subset of [_decks] matching the current search keyword and tag.
  List<PublicDeckSummary> get _filteredDecks {
    if (_cachedResults != null) return _cachedResults!;
    if (_searchQuery.isEmpty && _activeTag == null) return _decks;
    return _engine.query(
      _searchQuery,
      tagFilter: _activeTag,
      tagOf: (s) => s.tag,
    );
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
            top: -60,
            right: -100,
            child: _Blob(
              size: 340,
              color: AppColors.primaryContainer.withValues(alpha: 0.20),
            ),
          ),
          Positioned(
            bottom: 180,
            left: -120,
            child: _Blob(
              size: 300,
              color: AppColors.secondaryContainer.withValues(alpha: 0.22),
            ),
          ),

          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header section ────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Explore Community',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onSurface,
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Discover and learn from thousands of public decks',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Search + filters ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SearchField(
                        controller: _searchController,
                        onChanged: (_) {},
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(
                            Icons.filter_list_rounded,
                            size: 16,
                            color: AppColors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'FILTER BY CATEGORY',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.onSurfaceVariant,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _TagFilterRow(
                        tags: _tags,
                        activeTag: _activeTag,
                        onTagSelected: _onTagSelected,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Deck list ─────────────────────────────────────────────
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 2.5,
                          ),
                        )
                      : _DeckList(
                          decks: _filteredDecks,
                          isLoadingMore: _isLoadingMore,
                          hasMore: _hasMore,
                          onLoadMore: _loadNextPage,
                          onTap: _openDeckDetail,
                          searchQuery: _searchQuery,
                          activeTag: _activeTag,
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
    return MouseRegion(
      cursor: SystemMouseCursors.text,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.outlineVariant.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.onSurface.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppColors.onSurface,
          ),
          decoration: InputDecoration(
            hintText: 'Search decks, topics, or creators...',
            hintStyle: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
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
                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: AppColors.onSurfaceVariant,
                      size: 20,
                    ),
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  ),
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
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tags.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final tag = tags[i];
          final active = activeTag == tag;
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => onTagSelected(tag),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  gradient: active
                      ? const LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primaryFixedDim
                          ],
                        )
                      : null,
                  color: active ? null : AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: active
                        ? AppColors.primary.withValues(alpha: 0.3)
                        : AppColors.outlineVariant.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (active)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(
                          Icons.check_circle_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    Text(
                      tag,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color:
                            active ? Colors.white : AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
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
    required this.searchQuery,
    this.activeTag,
  });

  final List<PublicDeckSummary> decks;
  final bool isLoadingMore;
  final bool hasMore;
  final VoidCallback onLoadMore;
  final ValueChanged<PublicDeckSummary> onTap;
  final String searchQuery;
  final String? activeTag;

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
      return _EmptyState(
        searchQuery: widget.searchQuery,
        activeTag: widget.activeTag,
      );
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 140),
      itemCount: widget.decks.length + (widget.isLoadingMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == widget.decks.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Column(
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Loading more decks...',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final deck = widget.decks[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
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
  const _EmptyState({this.searchQuery = '', this.activeTag});

  final String searchQuery;
  final String? activeTag;

  @override
  Widget build(BuildContext context) {
    final String title;
    final String subtitle;
    final IconData icon;

    if (searchQuery.isNotEmpty && activeTag != null) {
      title = 'No Results Found';
      subtitle =
          'No decks match "$searchQuery" in the "$activeTag" category. Try adjusting your filters.';
      icon = Icons.search_off_rounded;
    } else if (searchQuery.isNotEmpty) {
      title = 'No Matching Decks';
      subtitle =
          'We couldn\'t find any decks matching "$searchQuery". Try a different keyword or browse by category.';
      icon = Icons.search_off_rounded;
    } else if (activeTag != null) {
      title = 'No Decks in Category';
      subtitle =
          'No public decks found for "$activeTag". Try a different category or clear the filter.';
      icon = Icons.category_outlined;
    } else {
      title = 'No Decks Available';
      subtitle =
          'There are no public decks to display at the moment. Check back later!';
      icon = Icons.explore_off_rounded;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.outlineVariant.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Icon(
                icon,
                size: 56,
                color: AppColors.outline.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
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
