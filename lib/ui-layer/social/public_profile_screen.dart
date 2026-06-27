import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../landing_page/app_theme.dart';
import '../../data-layer/models/social/public_profile.dart';
import '../../data-layer/models/social/public_deck_summary.dart';
import '../../data-layer/route_args/social_route_args.dart';
import '../../business-layer/services/profile_service.dart';
import '../../business-layer/services/share_service.dart';
import '../../business-layer/services/notification_prefs_service.dart';
import 'widgets/public_deck_card.dart';
import 'widgets/follow_button.dart';
import '../widgets/app_spinner.dart';
import '../../main.dart' show AppRoutes;

// ─────────────────────────────────────────────────────────────────────────────
// PUBLIC PROFILE SCREEN  —  route: /public-profile
//
// Behaviour:
//   • PUBLIC account  → full profile: hero header (avatar + gradient ring +
//     privacy badge + name + username + member-since + followers/following),
//     bio card, about card, library stat card (decks, cards, shared — no
//     drafts), and the real-time shared deck list.
//   • PRIVATE account → minimal view: avatar, full name, username and a
//     "This account is private" lock card.  No stats, no decks, no bio.
//
// The design language mirrors the owner's ProfileScreen: gradient header band,
// same card primitives (_SectionCard, _CardLabel, etc.), identical colour
// tokens.  The only intentional differences are:
//   • Back-arrow top bar instead of "Edit Account" button
//   • Follow / Unfollow button (hidden when viewing your own profile)
//   • No Settings, Notifications, or Log Out sections
//
// Arguments : PublicProfileArgs (targetUid, suppressViewNotification)
//             via ModalRoute settings.arguments
//
// Architecture: public StatelessWidget → private StatefulWidget _Body
//
// Requirements: 4.3, 4.5, 4.6, 5.1–5.5
// ─────────────────────────────────────────────────────────────────────────────

class PublicProfileScreen extends StatelessWidget {
  const PublicProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args == null || args is! PublicProfileArgs) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              _TopBar(onBack: () => Navigator.of(context).pop()),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_off_rounded,
                          size: 64,
                          color: AppColors.outline.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Profile not found.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return _PublicProfileBody(
      targetUid: args.targetUid,
      suppressViewNotification: args.suppressViewNotification,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BODY
// ─────────────────────────────────────────────────────────────────────────────

class _PublicProfileBody extends StatefulWidget {
  const _PublicProfileBody({
    required this.targetUid,
    this.suppressViewNotification = false,
  });

  final String targetUid;
  final bool suppressViewNotification;

  @override
  State<_PublicProfileBody> createState() => _PublicProfileBodyState();
}

class _PublicProfileBodyState extends State<_PublicProfileBody> {
  // ── State ─────────────────────────────────────────────────────────────────

  bool _isLoadingProfile = true;
  bool _isFollowLoading = false;

  PublicProfile? _profile;
  PublicLibraryStats? _stats;
  bool _isFollowing = false;
  int _followerCount = 0;
  int _followingCount = 0;

  String? _errorMessage;

  // Hold the decks stream in state so follow/unfollow setState calls do NOT
  // recreate the stream and reset the StreamBuilder.
  late final Stream<List<PublicDeckSummary>> _decksStream;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _decksStream = ProfileService.userDecksStream(widget.targetUid);
    _loadProfile();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadProfile() async {
    setState(() {
      _isLoadingProfile = true;
      _errorMessage = null;
    });

    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final db = FirebaseFirestore.instance;

      final results = await Future.wait([
        ProfileService.getProfile(widget.targetUid),
        db
            .collection('users')
            .doc(widget.targetUid)
            .collection('followers')
            .doc(currentUid)
            .get(const GetOptions(source: Source.server)),
        db
            .collection('users')
            .doc(widget.targetUid)
            .collection('followers')
            .count()
            .get(),
        db
            .collection('users')
            .doc(widget.targetUid)
            .collection('following')
            .count()
            .get(),
      ]);

      if (!mounted) return;

      final profile = results[0] as PublicProfile;
      final followDoc = results[1] as DocumentSnapshot;
      final followerAgg = results[2] as AggregateQuerySnapshot;
      final followingAgg = results[3] as AggregateQuerySnapshot;

      // Fetch library stats only for public profiles (no need if private).
      PublicLibraryStats? stats;
      if (!profile.isPrivate) {
        stats = await ProfileService.getLibraryStats(widget.targetUid);
      }

      if (!mounted) return;

      // Fire profile-viewed notification (public accounts only, not self, not
      // suppressed, not from a private viewer).
      if (currentUid.isNotEmpty &&
          currentUid != widget.targetUid &&
          !profile.isPrivate &&
          !widget.suppressViewNotification) {
        _sendProfileViewedNotification(
          viewerUid: currentUid,
          ownerUid: widget.targetUid,
          ownerUsername: profile.username,
        );
      }

      setState(() {
        _profile = profile;
        _stats = stats;
        _isFollowing = followDoc.exists;
        _followerCount = followerAgg.count ?? 0;
        _followingCount = followingAgg.count ?? 0;
        _isLoadingProfile = false;
      });
    } on StateError catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingProfile = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      debugPrint('[PublicProfileScreen._loadProfile] error: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingProfile = false;
        _errorMessage = 'Failed to load profile. Please try again.';
      });
    }
  }

  // ── Profile viewed notification ───────────────────────────────────────────

  Future<void> _sendProfileViewedNotification({
    required String viewerUid,
    required String ownerUid,
    required String ownerUsername,
  }) async {
    try {
      final enabled = await NotificationPrefsService.isEnabledFor(
        uid: ownerUid,
        type: NotificationType.profileViewed,
      );
      if (!enabled) return;

      final db = FirebaseFirestore.instance;

      final viewerSnap = await db.collection('users').doc(viewerUid).get();
      final viewerData = viewerSnap.data() ?? {};
      final viewerFullName = viewerData['fullName'] as String? ?? 'Someone';

      final viewerIsPrivate = viewerData['isPrivate'] as bool? ?? false;
      if (viewerIsPrivate) return;

      final cutoff = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(hours: 24)),
      );
      final existing = await db
          .collection('users')
          .doc(ownerUid)
          .collection('notifications')
          .where('type', isEqualTo: 'profile_viewed')
          .where('fromUid', isEqualTo: viewerUid)
          .where('createdAt', isGreaterThan: cutoff)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) return;

      await db
          .collection('users')
          .doc(ownerUid)
          .collection('notifications')
          .add({
        'type': 'profile_viewed',
        'fromUid': viewerUid,
        'fromUsername': viewerFullName,
        'deckId': '',
        'deckTitle': '',
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (_) {
      // Silently ignore — notification is best-effort
    }
  }

  // ── Follow / Unfollow ─────────────────────────────────────────────────────

  Future<void> _toggleFollow() async {
    if (_isFollowLoading) return;

    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    setState(() => _isFollowLoading = true);

    try {
      if (_isFollowing) {
        await ShareService.unfollow(
          followerUid: currentUid,
          followeeUid: widget.targetUid,
        );
        if (!mounted) return;
        setState(() {
          _isFollowing = false;
          _followerCount =
              (_followerCount - 1).clamp(0, double.maxFinite.toInt());
        });
      } else {
        await ShareService.follow(
          followerUid: currentUid,
          followeeUid: widget.targetUid,
        );
        if (!mounted) return;
        setState(() {
          _isFollowing = true;
          _followerCount = _followerCount + 1;
        });
      }
    } on ArgumentError catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(e.message.toString());
    } catch (e) {
      debugPrint('[PublicProfileScreen._toggleFollow] error: $e');
      if (!mounted) return;
      _showErrorSnackBar('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isFollowLoading = false);
    }
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

  void _openFollowersList(String tab) async {
    await Navigator.of(context).pushNamed(
      AppRoutes.followList,
      arguments: FollowListArgs(
        targetUid: widget.targetUid,
        initialTab: tab == 'followers'
            ? FollowListTab.followers
            : FollowListTab.following,
      ),
    );
    _loadProfile();
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
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isOwnProfile = currentUid == widget.targetUid;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Decorative blobs — mirror profile_screen positioning ──────────
          Positioned(
            top: -80,
            left: -60,
            child: _Blob(
              size: 340,
              color: AppColors.secondaryContainer.withValues(alpha: 0.18),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).size.height * 0.45,
            right: -100,
            child: _Blob(
              size: 280,
              color: AppColors.tertiaryContainer.withValues(alpha: 0.14),
            ),
          ),

          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // ── Top bar ───────────────────────────────────────────────
                _TopBar(onBack: () => Navigator.of(context).pop()),

                // ── Content ───────────────────────────────────────────────
                Expanded(
                  child: _isLoadingProfile
                      ? const Center(child: AppSpinner())
                      : _errorMessage != null
                          ? _GenericErrorState(
                              message: _errorMessage!,
                              onRetry: _loadProfile,
                            )
                          : _profile == null
                              ? const SizedBox.shrink()
                              : _profile!.isPrivate &&
                                      currentUid != widget.targetUid
                                  ? _PrivateProfileView(
                                      profile: _profile!,
                                    )
                                  : _PublicProfileView(
                                      profile: _profile!,
                                      stats: _stats,
                                      decksStream: _decksStream,
                                      isOwnProfile: isOwnProfile,
                                      isFollowing: _isFollowing,
                                      isFollowLoading: _isFollowLoading,
                                      followerCount: _followerCount,
                                      followingCount: _followingCount,
                                      onFollowToggle: _toggleFollow,
                                      onDeckTap: _openDeckDetail,
                                      onFollowersTap: () =>
                                          _openFollowersList('followers'),
                                      onFollowingTap: () =>
                                          _openFollowersList('following'),
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

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background.withValues(alpha: 0.90),
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
            'Profile',
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
// PRIVATE PROFILE VIEW
//
// Shown when the target account has isPrivate == true and the viewer is not
// the owner.  Only displays avatar, full name, username, and a lock card.
// ─────────────────────────────────────────────────────────────────────────────

class _PrivateProfileView extends StatelessWidget {
  const _PrivateProfileView({required this.profile});

  final PublicProfile profile;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 80),
      child: Column(
        children: [
          // ── Minimal hero — gradient band, avatar, name, username ──────────
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.09),
                  AppColors.secondaryContainer.withValues(alpha: 0.14),
                  AppColors.background,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
            child: Column(
              children: [
                // Avatar with gradient ring
                _AvatarRing(
                  photoUrl: profile.photoUrl,
                  fullName: profile.fullName,
                  isPrivate: true,
                ),
                const SizedBox(height: 16),

                // Full name
                Text(
                  profile.fullName.isNotEmpty ? profile.fullName : 'User',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: AppColors.onSurface,
                    height: 1.1,
                  ),
                  textAlign: TextAlign.center,
                ),

                // @username
                if (profile.username.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '@${profile.username}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                      letterSpacing: 0.1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),

          // ── Lock card ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: _SectionCard(
              child: Column(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.onSurface.withValues(alpha: 0.07),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_outline_rounded,
                      size: 24,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'This account is private',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onSurface,
                      letterSpacing: -0.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Only the name and username\nare visible for private accounts.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.onSurfaceVariant,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
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
// PUBLIC PROFILE VIEW
//
// Full profile layout matching the owner's ProfileScreen in design language:
//   1. Hero header  — gradient band · avatar (gradient ring + privacy badge) ·
//                     full name · @username · member-since ·
//                     followers/following (tappable) · follow button
//   2. Bio card     — shown only when bio is non-empty
//   3. About card   — school / course / year / region
//   4. Library card — Decks | Cards | Shared  (3-cell, no Drafts)
//   5. Shared decks list (real-time stream)
// ─────────────────────────────────────────────────────────────────────────────

class _PublicProfileView extends StatelessWidget {
  const _PublicProfileView({
    required this.profile,
    required this.stats,
    required this.decksStream,
    required this.isOwnProfile,
    required this.isFollowing,
    required this.isFollowLoading,
    required this.followerCount,
    required this.followingCount,
    required this.onFollowToggle,
    required this.onDeckTap,
    required this.onFollowersTap,
    required this.onFollowingTap,
  });

  final PublicProfile profile;
  final PublicLibraryStats? stats;
  final Stream<List<PublicDeckSummary>> decksStream;
  final bool isOwnProfile;
  final bool isFollowing;
  final bool isFollowLoading;
  final int followerCount;
  final int followingCount;
  final VoidCallback onFollowToggle;
  final void Function(PublicDeckSummary) onDeckTap;
  final VoidCallback onFollowersTap;
  final VoidCallback onFollowingTap;

  String get _memberSince {
    if (profile.createdAt == null) return '';
    final dt = profile.createdAt!.toDate();
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
    return 'Member since ${months[dt.month - 1]} ${dt.year}';
  }

  bool get _hasAbout =>
      profile.school.isNotEmpty ||
      profile.course.isNotEmpty ||
      profile.yearLevel.isNotEmpty ||
      profile.region.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── 1. Hero header ────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: _PublicHeroHeader(
            profile: profile,
            memberSince: _memberSince,
            followerCount: followerCount,
            followingCount: followingCount,
            isOwnProfile: isOwnProfile,
            isFollowing: isFollowing,
            isFollowLoading: isFollowLoading,
            onFollowToggle: onFollowToggle,
            onFollowersTap: onFollowersTap,
            onFollowingTap: onFollowingTap,
          ),
        ),

        // ── 2. Bio card ───────────────────────────────────────────────────
        if (profile.bio.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: _BioCard(bio: profile.bio),
            ),
          ),

        // ── 3. About card ─────────────────────────────────────────────────
        if (_hasAbout)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: _AboutCard(
                school: profile.school,
                course: profile.course,
                yearLevel: profile.yearLevel,
                region: profile.region,
              ),
            ),
          ),

        // ── 4. Library stats card ─────────────────────────────────────────
        if (stats != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: _LibraryStatsCard(stats: stats!),
            ),
          ),

        // ── 5. Shared decks section header ────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
            child: Row(
              children: [
                Icon(
                  Icons.public_outlined,
                  size: 13,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'SHARED LIBRARY',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── 6. Deck list (real-time) ──────────────────────────────────────
        StreamBuilder<List<PublicDeckSummary>>(
          stream: decksStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: AppSpinner()),
                ),
              );
            }

            final decks = snapshot.data ?? [];

            if (decks.isEmpty) {
              return const SliverToBoxAdapter(child: _EmptyDecksState());
            }

            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: PublicDeckCard(
                      deck: decks[index],
                      onTap: () => onDeckTap(decks[index]),
                    ),
                  ),
                  childCount: decks.length,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PUBLIC HERO HEADER
//
// Mirrors the _HeroHeader widget in profile_screen.dart but replaces the
// "Edit Account" button with a follow/unfollow action.
// ─────────────────────────────────────────────────────────────────────────────

class _PublicHeroHeader extends StatelessWidget {
  const _PublicHeroHeader({
    required this.profile,
    required this.memberSince,
    required this.followerCount,
    required this.followingCount,
    required this.isOwnProfile,
    required this.isFollowing,
    required this.isFollowLoading,
    required this.onFollowToggle,
    required this.onFollowersTap,
    required this.onFollowingTap,
  });

  final PublicProfile profile;
  final String memberSince;
  final int followerCount;
  final int followingCount;
  final bool isOwnProfile;
  final bool isFollowing;
  final bool isFollowLoading;
  final VoidCallback onFollowToggle;
  final VoidCallback onFollowersTap;
  final VoidCallback onFollowingTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.09),
            AppColors.secondaryContainer.withValues(alpha: 0.14),
            AppColors.background,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        children: [
          // Avatar with gradient ring + privacy badge
          _AvatarRing(
            photoUrl: profile.photoUrl,
            fullName: profile.fullName,
            isPrivate: false,
          ),
          const SizedBox(height: 16),

          // Full name
          Text(
            profile.fullName.isNotEmpty ? profile.fullName : 'User',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: AppColors.onSurface,
              height: 1.1,
            ),
            textAlign: TextAlign.center,
          ),

          // @username
          if (profile.username.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '@${profile.username}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
                letterSpacing: 0.1,
              ),
              textAlign: TextAlign.center,
            ),
          ],

          // Member since
          if (memberSince.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 11,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.55),
                ),
                const SizedBox(width: 5),
                Text(
                  memberSince,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ],

          // Followers / Following — tappable
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _FollowStat(
                count: followerCount,
                label: 'Followers',
                onTap: onFollowersTap,
              ),
              Container(
                width: 1,
                height: 28,
                margin: const EdgeInsets.symmetric(horizontal: 24),
                color: AppColors.outlineVariant.withValues(alpha: 0.5),
              ),
              _FollowStat(
                count: followingCount,
                label: 'Following',
                onTap: onFollowingTap,
              ),
            ],
          ),

          // Follow button (hidden on own profile)
          if (!isOwnProfile) ...[
            const SizedBox(height: 20),
            FollowButton(
              isFollowing: isFollowing,
              isLoading: isFollowLoading,
              onPressed: onFollowToggle,
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AVATAR RING  (gradient ring + privacy badge — mirrors profile_screen)
// ─────────────────────────────────────────────────────────────────────────────

class _AvatarRing extends StatelessWidget {
  const _AvatarRing({
    required this.photoUrl,
    required this.fullName,
    required this.isPrivate,
  });

  final String? photoUrl;
  final String fullName;
  final bool isPrivate;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.30),
                AppColors.secondary.withValues(alpha: 0.20),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(4),
          child: _AvatarContent(photoUrl: photoUrl, fullName: fullName),
        ),
        Positioned(
          bottom: 2,
          right: 2,
          child: _PrivacyBadge(isPrivate: isPrivate),
        ),
      ],
    );
  }
}

class _AvatarContent extends StatelessWidget {
  const _AvatarContent({required this.photoUrl, required this.fullName});

  final String? photoUrl;
  final String fullName;

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          photoUrl!,
          width: 108,
          height: 108,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              width: 108,
              height: 108,
              color: AppColors.primaryContainer.withValues(alpha: 0.2),
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    strokeCap: StrokeCap.round,
                    color: AppColors.primary,
                    value: progress.expectedTotalBytes != null
                        ? progress.cumulativeBytesLoaded /
                            progress.expectedTotalBytes!
                        : null,
                  ),
                ),
              ),
            );
          },
          errorBuilder: (_, __, ___) => _FallbackAvatar(fullName: fullName),
        ),
      );
    }
    return _FallbackAvatar(fullName: fullName);
  }
}

class _FallbackAvatar extends StatelessWidget {
  const _FallbackAvatar({required this.fullName});
  final String fullName;

  @override
  Widget build(BuildContext context) {
    if (fullName.isNotEmpty) {
      return Container(
        width: 108,
        height: 108,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [AppColors.primaryContainer, AppColors.secondaryContainer],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Text(
            fullName[0].toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 38,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ),
      );
    }
    return Container(
      width: 108,
      height: 108,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primaryContainer.withValues(alpha: 0.3),
      ),
      child: Icon(
        Icons.person_rounded,
        size: 56,
        color: AppColors.primary.withValues(alpha: 0.5),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRIVACY BADGE  (mirrors profile_screen._PrivacyBadge exactly)
// ─────────────────────────────────────────────────────────────────────────────

class _PrivacyBadge extends StatelessWidget {
  const _PrivacyBadge({required this.isPrivate});
  final bool isPrivate;

  @override
  Widget build(BuildContext context) {
    final color = isPrivate ? AppColors.onSurface : AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.background, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPrivate ? Icons.lock_rounded : Icons.public_rounded,
            size: 9,
            color: Colors.white,
          ),
          const SizedBox(width: 3),
          Text(
            isPrivate ? 'Private' : 'Public',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FOLLOW STAT  (tappable count + label, no decoration)
// ─────────────────────────────────────────────────────────────────────────────

class _FollowStat extends StatelessWidget {
  const _FollowStat({
    required this.count,
    required this.label,
    required this.onTap,
  });

  final int count;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        splashColor: AppColors.primary.withValues(alpha: 0.08),
        highlightColor: AppColors.primary.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Column(
            children: [
              Text(
                _fmt(count),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BIO CARD  (mirrors profile_screen._BioCard)
// ─────────────────────────────────────────────────────────────────────────────

class _BioCard extends StatelessWidget {
  const _BioCard({required this.bio});
  final String bio;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardLabel(icon: Icons.format_quote_rounded, label: 'BIO'),
          const SizedBox(height: 10),
          Text(
            bio,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.onSurface,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ABOUT CARD  (mirrors profile_screen._AboutCard)
// ─────────────────────────────────────────────────────────────────────────────

class _AboutCard extends StatelessWidget {
  const _AboutCard({
    required this.school,
    required this.course,
    required this.yearLevel,
    required this.region,
  });

  final String school;
  final String course;
  final String yearLevel;
  final String region;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardLabel(icon: Icons.person_outline_rounded, label: 'ABOUT'),
          const SizedBox(height: 12),
          if (school.isNotEmpty)
            _AboutRow(
              icon: Icons.school_outlined,
              label: 'School',
              value: school,
              color: AppColors.secondary,
            ),
          if (course.isNotEmpty)
            _AboutRow(
              icon: Icons.menu_book_outlined,
              label: 'Course',
              value: course,
              color: AppColors.tertiary,
            ),
          if (yearLevel.isNotEmpty)
            _AboutRow(
              icon: Icons.grade_outlined,
              label: 'Year Level',
              value: yearLevel,
              color: AppColors.primary,
            ),
          if (region.isNotEmpty)
            _AboutRow(
              icon: Icons.location_on_outlined,
              label: 'Region',
              value: region,
              color: AppColors.onSurfaceVariant,
            ),
        ],
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
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
// LIBRARY STATS CARD
//
// 3-cell grid: Decks | Cards | Shared.  Drafts intentionally excluded.
// Design mirrors profile_screen._LibraryCard (gradient container, same tokens).
// ─────────────────────────────────────────────────────────────────────────────

class _LibraryStatsCard extends StatelessWidget {
  const _LibraryStatsCard({required this.stats});

  final PublicLibraryStats stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryContainer.withValues(alpha: 0.22),
            AppColors.secondaryContainer.withValues(alpha: 0.18),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.12),
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
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardLabel(icon: Icons.bar_chart_rounded, label: 'LIBRARY'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatCell(
                  value: '${stats.deckCount}',
                  label: 'Decks',
                  icon: Icons.layers_outlined,
                  color: AppColors.primary,
                ),
              ),
              _StatDivider(),
              Expanded(
                child: _StatCell(
                  value: '${stats.cardCount}',
                  label: 'Cards',
                  icon: Icons.style_outlined,
                  color: AppColors.secondary,
                ),
              ),
              _StatDivider(),
              Expanded(
                child: _StatCell(
                  value: '${stats.sharedDeckCount}',
                  label: 'Shared',
                  icon: Icons.public_outlined,
                  color: AppColors.tertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 17, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
            height: 1,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 52,
      color: AppColors.outlineVariant.withValues(alpha: 0.35),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY DECKS STATE
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyDecksState extends StatelessWidget {
  const _EmptyDecksState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 40),
      child: Column(
        children: [
          Icon(
            Icons.layers_outlined,
            size: 64,
            color: AppColors.outline.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            "This user hasn't shared any decks yet.",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GENERIC ERROR STATE  (network / not-found errors with retry)
// ─────────────────────────────────────────────────────────────────────────────

class _GenericErrorState extends StatelessWidget {
  const _GenericErrorState({required this.message, required this.onRetry});

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
              Icons.person_off_rounded,
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
// SHARED DESIGN PRIMITIVES  (mirrors profile_screen equivalents)
// ─────────────────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withValues(alpha: 0.035),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CardLabel extends StatelessWidget {
  const _CardLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: AppColors.primary,
          ),
        ),
      ],
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
