import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../landing_page/app_theme.dart';
import '../../data-layer/models/social/public_deck_summary.dart';
import '../../data-layer/models/social/public_profile.dart';
import '../../data-layer/route_args/social_route_args.dart';
import '../../business-layer/services/deck_search_engine.dart';
import '../../main.dart';
import 'widgets/public_deck_card.dart';
import '../widgets/app_spinner.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DECK DISCOVERY SCREEN  —  route: /discover
//
// Paginated catalogue of all public decks. Supports:
//   • Client-side keyword search (title contains keyword, case-insensitive)
//   • Tag filter (re-queries Firestore with where('tag', isEqualTo: tag))
//   • Infinite scroll pagination (page size 20, startAfterDocument)
//   • "@username" search — when the search text starts with "@", deck
//     search is bypassed entirely and an exact-match user lookup runs
//     instead (users/{uid} where username == <text after "@">, then
//     filtered client-side to public accounts only). Tapping the result
//     navigates to their public profile. Private accounts never surface
//     here.
//   • "Following" section — when the user follows at least one account,
//     their most recent public decks are shown in a distinct, labelled
//     horizontal carousel above the main feed.
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

  // ── "Following" deck section ─────────────────────────────────────────────
  // Decks from accounts the current user follows, fetched once on init.
  List<PublicDeckSummary> _followingDecks = [];
  bool _isLoadingFollowing = false;
  bool _followingSectionVisible = false; // true once we know there are results

  // ── "@username" search mode ──────────────────────────────────────────────
  bool _isUserSearchMode = false;
  bool _isSearchingUser = false;
  PublicProfile? _foundUser;
  int _userSearchToken = 0;

  static const int _pageSize = 20;
  // Max decks to show per followed account in the "Following" section.
  static const int _followingDeckLimit = 3;

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
    _loadFollowingDecks();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ── Following deck loader ─────────────────────────────────────────────────

  /// Loads up to [_followingDeckLimit] recent public decks per followed
  /// account. Runs a single `following` collection read, then batches one
  /// `public_decks` query per followee (up to 20 followees to stay within
  /// Firestore limits). Decks are de-duplicated and sorted by sharedAt.
  Future<void> _loadFollowingDecks() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    if (mounted) setState(() => _isLoadingFollowing = true);

    try {
      // 1. Fetch the UIDs the current user follows (limit to 20 to avoid
      //    runaway reads on large following lists).
      final followingSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('following')
          .limit(20)
          .get();

      if (followingSnap.docs.isEmpty) {
        if (mounted) setState(() => _isLoadingFollowing = false);
        return;
      }

      final followedUids = followingSnap.docs.map((d) => d.id).toList();

      // 2. For each followed UID, query their most recent public decks.
      final futures = followedUids.map((followedUid) {
        return FirebaseFirestore.instance
            .collection('public_decks')
            .where('ownerUid', isEqualTo: followedUid)
            .orderBy('sharedAt', descending: true)
            .limit(_followingDeckLimit)
            .get();
      });

      final snapshots = await Future.wait(futures);

      // 3. Flatten, convert, sort by sharedAt desc, de-duplicate by deckId.
      final seen = <String>{};
      final results = <PublicDeckSummary>[];

      for (final snap in snapshots) {
        for (final doc in snap.docs) {
          final id = doc.id;
          if (seen.contains(id)) continue;
          seen.add(id);
          results.add(PublicDeckSummary.fromFirestore(
            doc as DocumentSnapshot<Map<String, dynamic>>,
          ));
        }
      }

      results.sort((a, b) => b.sharedAt.compareTo(a.sharedAt));

      if (mounted) {
        setState(() {
          _followingDecks = results;
          _followingSectionVisible = results.isNotEmpty;
          _isLoadingFollowing = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingFollowing = false);
    }
  }

  // ── Search ────────────────────────────────────────────────────────────────

  static String _summaryKey(PublicDeckSummary s) =>
      '${s.title} ${s.tag} ${s.ownerUsername}'.toLowerCase();

  void _onSearchChanged() {
    _debounce?.cancel();

    final rawText = _searchController.text.trim();

    if (rawText.startsWith('@')) {
      final candidate = rawText.substring(1);
      setState(() {
        _isUserSearchMode = true;
        _foundUser = null;
      });

      if (candidate.isEmpty) {
        setState(() => _isSearchingUser = false);
        return;
      }

      _debounce = Timer(
        const Duration(milliseconds: 300),
        () => _lookupUsername(candidate),
      );
      return;
    }

    if (_isUserSearchMode) {
      setState(() {
        _isUserSearchMode = false;
        _isSearchingUser = false;
        _foundUser = null;
      });
    }

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

  Future<void> _lookupUsername(String username) async {
    final token = ++_userSearchToken;
    if (mounted) setState(() => _isSearchingUser = true);

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (!mounted || token != _userSearchToken) return;

      PublicProfile? result;
      if (snap.docs.isNotEmpty) {
        final profile = PublicProfile.fromFirestore(snap.docs.first);
        if (!profile.isPrivate) result = profile;
      }

      setState(() {
        _foundUser = result;
        _isSearchingUser = false;
      });
    } catch (e) {
      if (!mounted || token != _userSearchToken) return;
      setState(() {
        _foundUser = null;
        _isSearchingUser = false;
      });
    }
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Query<Map<String, dynamic>> _baseQuery() {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('public_decks')
        .orderBy('sharedAt', descending: true);

    if (_activeTag != null) {
      q = q.where('tag', isEqualTo: _activeTag);
    }

    return q;
  }

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

  List<PublicDeckSummary> get _filteredDecks {
    if (_cachedResults != null) return _cachedResults!;
    if (_searchQuery.isEmpty && _activeTag == null) return _decks;
    return _engine.query(
      _searchQuery,
      tagFilter: _activeTag,
      tagOf: (s) => s.tag,
    );
  }

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

  void _openPublicProfile(PublicProfile user) {
    Navigator.of(context).pushNamed(
      AppRoutes.publicProfile,
      arguments: PublicProfileArgs(targetUid: user.uid),
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

  // ── Whether the "Following" section should be shown ───────────────────────

  /// The following section is suppressed while the user is typing in the
  /// search field, so it doesn't compete with search results.
  bool get _showFollowingSection =>
      _followingSectionVisible &&
      !_isUserSearchMode &&
      _searchQuery.isEmpty &&
      _activeTag == null;

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
                      if (!_isUserSearchMode) ...[
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
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Deck list / user search result ─────────────────────────
                Expanded(
                  child: _isUserSearchMode
                      ? _UserSearchResult(
                          isSearching: _isSearchingUser,
                          foundUser: _foundUser,
                          onTapUser: _openPublicProfile,
                        )
                      : _isLoading
                          ? const Center(child: AppSpinner())
                          : _DeckFeed(
                              // "Following" section
                              followingDecks: _showFollowingSection
                                  ? _followingDecks
                                  : const [],
                              isLoadingFollowing: _isLoadingFollowing,
                              // Main feed
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
            hintText: 'Search decks, topics, or @username...',
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
// USER SEARCH RESULT
// ─────────────────────────────────────────────────────────────────────────────

class _UserSearchResult extends StatelessWidget {
  const _UserSearchResult({
    required this.isSearching,
    required this.foundUser,
    required this.onTapUser,
  });

  final bool isSearching;
  final PublicProfile? foundUser;
  final ValueChanged<PublicProfile> onTapUser;

  @override
  Widget build(BuildContext context) {
    if (isSearching) {
      return const Center(child: AppSpinner());
    }

    final user = foundUser;
    if (user == null) {
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
                  Icons.person_search_rounded,
                  size: 56,
                  color: AppColors.outline.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No Account Found',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Make sure the username is spelled correctly. Private accounts won\'t show up here either.',
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 140),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 4),
            child: Text(
              'ACCOUNT',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurfaceVariant,
                letterSpacing: 1.2,
              ),
            ),
          ),
          _UserResultCard(user: user, onTap: () => onTapUser(user)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// USER RESULT CARD
// ─────────────────────────────────────────────────────────────────────────────

class _UserResultCard extends StatelessWidget {
  const _UserResultCard({required this.user, required this.onTap});

  final PublicProfile user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.onSurface.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryContainer,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: user.photoUrl != null && user.photoUrl!.isNotEmpty
                      ? Image.network(
                          user.photoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.person_rounded,
                            color: AppColors.primary,
                            size: 26,
                          ),
                        )
                      : const Icon(
                          Icons.person_rounded,
                          color: AppColors.primary,
                          size: 26,
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '@${user.username}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (user.fullName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        user.fullName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.outline,
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
// DECK FEED
//
// Combines the "Following" horizontal carousel (when non-empty) and the main
// paginated vertical list into a single scrollable widget.
//
// Layout (when following section is present):
//
//   ┌──────────────────────────────────────┐
//   │  👥 FROM PEOPLE YOU FOLLOW           │  ← section header with badge
//   │  [deck] [deck] [deck] →              │  ← horizontal scroll carousel
//   ├──────────────────────────────────────┤
//   │  🌐 ALL PUBLIC DECKS                 │  ← section header
//   │  [deck card]                         │
//   │  [deck card]                         │
//   │  …                                   │
//   └──────────────────────────────────────┘
// ─────────────────────────────────────────────────────────────────────────────

class _DeckFeed extends StatefulWidget {
  const _DeckFeed({
    required this.followingDecks,
    required this.isLoadingFollowing,
    required this.decks,
    required this.isLoadingMore,
    required this.hasMore,
    required this.onLoadMore,
    required this.onTap,
    required this.searchQuery,
    this.activeTag,
  });

  final List<PublicDeckSummary> followingDecks;
  final bool isLoadingFollowing;
  final List<PublicDeckSummary> decks;
  final bool isLoadingMore;
  final bool hasMore;
  final VoidCallback onLoadMore;
  final ValueChanged<PublicDeckSummary> onTap;
  final String searchQuery;
  final String? activeTag;

  @override
  State<_DeckFeed> createState() => _DeckFeedState();
}

class _DeckFeedState extends State<_DeckFeed> {
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
    final hasFollowing = widget.followingDecks.isNotEmpty;
    final hasMain = widget.decks.isNotEmpty;

    if (!hasFollowing && !hasMain) {
      return _EmptyState(
        searchQuery: widget.searchQuery,
        activeTag: widget.activeTag,
      );
    }

    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── "From People You Follow" section ────────────────────────────
        if (hasFollowing) ...[
          SliverToBoxAdapter(
            child: _FollowingSectionHeader(),
          ),
          SliverToBoxAdapter(
            child: _FollowingCarousel(
              decks: widget.followingDecks,
              onTap: widget.onTap,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          // Visual divider before main feed
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Divider(
                color: AppColors.outlineVariant.withValues(alpha: 0.4),
                thickness: 1,
              ),
            ),
          ),
        ],

        // ── "All Public Decks" section header ────────────────────────────
        SliverToBoxAdapter(
          child: _AllDecksSectionHeader(hasFollowingSection: hasFollowing),
        ),

        // ── Main deck list ────────────────────────────────────────────────
        if (hasMain)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  if (i == widget.decks.length) {
                    // Loading-more indicator
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Column(
                          children: [
                            const SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                color: AppColors.primary,
                                strokeWidth: 2.5,
                                strokeCap: StrokeCap.round,
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
                childCount:
                    widget.decks.length + (widget.isLoadingMore ? 1 : 0),
              ),
            ),
          )
        else
          SliverToBoxAdapter(
            child: _EmptyState(
              searchQuery: widget.searchQuery,
              activeTag: widget.activeTag,
            ),
          ),

        // Bottom padding for nav bar
        const SliverToBoxAdapter(child: SizedBox(height: 140)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FOLLOWING SECTION HEADER
//
// The "FROM PEOPLE YOU FOLLOW" label with a people-badge icon and a subtle
// recommended pill. Visually distinct from the "ALL PUBLIC DECKS" header
// below so users immediately understand the provenance of the top section.
// ─────────────────────────────────────────────────────────────────────────────

class _FollowingSectionHeader extends StatelessWidget {
  const _FollowingSectionHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.people_rounded,
              size: 16,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FROM PEOPLE YOU FOLLOW',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurface,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Recommended based on who you follow',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: 11,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  'For You',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
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
// FOLLOWING CAROUSEL
//
// Horizontal scrollable row of compact deck cards from followed accounts.
// Each card is narrower than the main-feed cards (280 px) so multiple are
// visible at once, hinting at the scroll affordance.
// ─────────────────────────────────────────────────────────────────────────────

class _FollowingCarousel extends StatelessWidget {
  const _FollowingCarousel({
    required this.decks,
    required this.onTap,
  });

  final List<PublicDeckSummary> decks;
  final ValueChanged<PublicDeckSummary> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 172,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
        itemCount: decks.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final deck = decks[i];
          return SizedBox(
            width: 260,
            child: _FollowingDeckCard(deck: deck, onTap: () => onTap(deck)),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FOLLOWING DECK CARD
//
// A compact variant of PublicDeckCard used in the horizontal carousel.
// Carries a subtle primary-tinted left border to visually tie the card back
// to the "following" brand color without repeating the section header.
// ─────────────────────────────────────────────────────────────────────────────

class _FollowingDeckCard extends StatelessWidget {
  const _FollowingDeckCard({required this.deck, required this.onTap});

  final PublicDeckSummary deck;
  final VoidCallback onTap;

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays < 1) return 'today';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(18),
          border: Border(
            left: BorderSide(
              color: AppColors.primary.withValues(alpha: 0.55),
              width: 3,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: AppColors.onSurface.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tag + time
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    deck.tag.toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onSecondaryContainer,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                Text(
                  _timeAgo(deck.sharedAt),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppColors.outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Title
            Expanded(
              child: Text(
                deck.title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                  height: 1.25,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 10),

            // Owner + card count
            Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryContainer,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: ClipOval(
                    child: deck.ownerPhotoUrl != null &&
                            deck.ownerPhotoUrl!.isNotEmpty
                        ? Image.network(deck.ownerPhotoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                                  Icons.person_rounded,
                                  color: AppColors.primary,
                                  size: 12,
                                ))
                        : const Icon(
                            Icons.person_rounded,
                            color: AppColors.primary,
                            size: 12,
                          ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    deck.ownerFullName,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${deck.cardCount} cards',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.outline,
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
// ALL DECKS SECTION HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _AllDecksSectionHeader extends StatelessWidget {
  const _AllDecksSectionHeader({required this.hasFollowingSection});

  final bool hasFollowingSection;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, hasFollowingSection ? 12 : 0, 20, 12),
      child: Row(
        children: [
          Icon(
            Icons.public_rounded,
            size: 16,
            color: AppColors.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            'ALL PUBLIC DECKS',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColors.onSurfaceVariant,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
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
