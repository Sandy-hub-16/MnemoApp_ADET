import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../landing_page/app_theme.dart';
import '../../data-layer/social/public_profile.dart';
import '../../data-layer/social/public_deck_summary.dart';
import '../../data-layer/social/social_route_args.dart';
import '../../business-layer/services/profile_service.dart';
import '../../business-layer/services/share_service.dart';
import 'widgets/public_deck_card.dart';
import 'widgets/follow_button.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PUBLIC PROFILE SCREEN  —  route: /public-profile
//
// Displays another user's public identity (avatar, name, username), their
// follower / following counts, and a list of their shared decks.
//
// The current user can follow or unfollow the profile owner from this screen.
//
// Arguments: PublicProfileArgs (targetUid) via settings.arguments
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
      // Navigated without args (e.g. direct URL or missing fromUid)
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              Container(
                color: AppColors.background.withValues(alpha: 0.80),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
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
              ),
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
    return _PublicProfileBody(targetUid: args.targetUid);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BODY
// ─────────────────────────────────────────────────────────────────────────────

class _PublicProfileBody extends StatefulWidget {
  const _PublicProfileBody({required this.targetUid});

  final String targetUid;

  @override
  State<_PublicProfileBody> createState() => _PublicProfileBodyState();
}

class _PublicProfileBodyState extends State<_PublicProfileBody> {
  // ── State ─────────────────────────────────────────────────────────────────

  bool _isLoadingProfile = true;
  bool _isFollowLoading = false;

  PublicProfile? _profile;
  bool _isFollowing = false;
  int _followerCount = 0;
  int _followingCount = 0;

  String? _errorMessage;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
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

      // Fetch profile, follow state, and sub-collection counts in parallel
      final results = await Future.wait([
        ProfileService.getProfile(widget.targetUid),
        db
            .collection('users')
            .doc(widget.targetUid)
            .collection('followers')
            .doc(currentUid)
            .get(),
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

      // If the profile is private and the viewer is not the owner, show lock screen
      if (profile.isPrivate && currentUid != widget.targetUid) {
        setState(() {
          _isLoadingProfile = false;
          _errorMessage = 'This account is private.';
        });
        return;
      }

      // Send a "profile viewed" notification to the owner (fire-and-forget)
      // Only when viewing someone else's public profile
      if (currentUid.isNotEmpty && currentUid != widget.targetUid && !profile.isPrivate) {
        _sendProfileViewedNotification(
          viewerUid: currentUid,
          ownerUid: widget.targetUid,
          ownerUsername: profile.username,
        );
      }

      setState(() {
        _profile = profile;
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

  /// Writes a "profile_viewed" notification to the profile owner so they know
  /// someone visited their public profile. Fire-and-forget; errors are silent.
  Future<void> _sendProfileViewedNotification({
    required String viewerUid,
    required String ownerUid,
    required String ownerUsername,
  }) async {
    try {
      // Get the viewer's username for the notification message
      final viewerSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(viewerUid)
          .get();
      final viewerUsername =
          viewerSnap.data()?['username'] as String? ?? 'Someone';

      await FirebaseFirestore.instance
          .collection('users')
          .doc(ownerUid)
          .collection('notifications')
          .add({
        'type': 'profile_viewed',
        'fromUid': viewerUid,
        'fromUsername': viewerUsername,
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
          _followerCount = (_followerCount - 1).clamp(0, double.maxFinite.toInt());
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
    } catch (_) {
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
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isOwnProfile = currentUid == widget.targetUid;

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
                _ProfileTopBar(
                  onBack: () => Navigator.of(context).pop(),
                ),

                // ── Content ───────────────────────────────────────────────
                Expanded(
                  child: _isLoadingProfile
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        )
                      : _errorMessage != null
                          ? _ErrorState(
                              message: _errorMessage!,
                              onRetry: _loadProfile,
                            )
                          : _profile == null
                              ? const SizedBox.shrink()
                              : _ProfileContent(
                                  profile: _profile!,
                                  targetUid: widget.targetUid,
                                  isOwnProfile: isOwnProfile,
                                  isFollowing: _isFollowing,
                                  isFollowLoading: _isFollowLoading,
                                  followerCount: _followerCount,
                                  followingCount: _followingCount,
                                  onFollowToggle: _toggleFollow,
                                  onDeckTap: _openDeckDetail,
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

class _ProfileTopBar extends StatelessWidget {
  const _ProfileTopBar({required this.onBack});

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
// PROFILE CONTENT
//
// Renders the profile header (avatar, name, stats, follow button) and the
// real-time list of the user's public decks via StreamBuilder.
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({
    required this.profile,
    required this.targetUid,
    required this.isOwnProfile,
    required this.isFollowing,
    required this.isFollowLoading,
    required this.followerCount,
    required this.followingCount,
    required this.onFollowToggle,
    required this.onDeckTap,
  });

  final PublicProfile profile;
  final String targetUid;
  final bool isOwnProfile;
  final bool isFollowing;
  final bool isFollowLoading;
  final int followerCount;
  final int followingCount;
  final VoidCallback onFollowToggle;
  final void Function(PublicDeckSummary) onDeckTap;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── Profile header ───────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: _ProfileHeader(
              profile: profile,
              isOwnProfile: isOwnProfile,
              isFollowing: isFollowing,
              isFollowLoading: isFollowLoading,
              followerCount: followerCount,
              followingCount: followingCount,
              onFollowToggle: onFollowToggle,
            ),
          ),
        ),

        // ── Decks section header ─────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
            child: Text(
              'Shared Decks',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ),

        // ── Decks list (real-time) ───────────────────────────────────────
        StreamBuilder<List<PublicDeckSummary>>(
          stream: ProfileService.userDecksStream(targetUid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
              );
            }

            final decks = snapshot.data ?? [];

            if (decks.isEmpty) {
              return const SliverToBoxAdapter(
                child: _EmptyDecksState(),
              );
            }

            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
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
// PROFILE HEADER
//
// Avatar, full name, username, follower/following counts, and follow button.
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.profile,
    required this.isOwnProfile,
    required this.isFollowing,
    required this.isFollowLoading,
    required this.followerCount,
    required this.followingCount,
    required this.onFollowToggle,
  });

  final PublicProfile profile;
  final bool isOwnProfile;
  final bool isFollowing;
  final bool isFollowLoading;
  final int followerCount;
  final int followingCount;
  final VoidCallback onFollowToggle;

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
        children: [
          // ── Avatar ────────────────────────────────────────────────────
          _ProfileAvatar(photoUrl: profile.photoUrl, size: 80),
          const SizedBox(height: 14),

          // ── Full name ─────────────────────────────────────────────────
          Text(
            profile.fullName,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.onSurface,
              letterSpacing: -0.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),

          // ── Username ──────────────────────────────────────────────────
          Text(
            '@${profile.username}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.outline,
            ),
          ),
          const SizedBox(height: 20),

          // ── Follower / following counts ───────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StatPill(count: followerCount, label: 'Followers'),
              Container(
                width: 1,
                height: 28,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                color: AppColors.outlineVariant.withValues(alpha: 0.5),
              ),
              _StatPill(count: followingCount, label: 'Following'),
            ],
          ),

          // ── Follow button (hidden on own profile) ─────────────────────
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
// PROFILE AVATAR
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.photoUrl, required this.size});

  final String? photoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primaryContainer,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25),
          width: 3,
        ),
      ),
      child: ClipOval(
        child: photoUrl != null && photoUrl!.isNotEmpty
            ? Image.network(
                photoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.person_rounded,
                  color: AppColors.primary,
                  size: 40,
                ),
              )
            : const Icon(
                Icons.person_rounded,
                color: AppColors.primary,
                size: 40,
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STAT PILL
//
// Displays a numeric count with a label below it (e.g. "42 / Followers").
// ─────────────────────────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  const _StatPill({required this.count, required this.label});

  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          _formatCount(count),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.outline,
          ),
        ),
      ],
    );
  }

  String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
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
// ERROR STATE
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final isPrivate = message == 'This account is private.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPrivate ? Icons.lock_outline_rounded : Icons.person_off_rounded,
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
            if (!isPrivate) ...[
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
