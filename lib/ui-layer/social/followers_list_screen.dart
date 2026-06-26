import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../business-layer/services/profile_service.dart';
import '../../business-layer/services/share_service.dart';
import '../../data-layer/models/social/public_profile.dart';
import '../../data-layer/route_args/social_route_args.dart';
import '../../main.dart';
import '../landing_page/app_theme.dart';
import 'widgets/follow_button.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FOLLOW LIST SCREEN  —  route: /follow-list
//
// Tabbed Followers / Following list for [targetUid]. Each tab streams the
// corresponding sub-collection (users/{targetUid}/followers or /following),
// then resolves every doc ID (a uid) into a PublicProfile so the row can show
// an avatar, full name, and @username.
//
// Tapping a row navigates to that user's PublicProfileScreen. When viewing
// your own lists, a Follow/Unfollow button also appears on each row so you
// can manage the relationship without leaving the list.
//
// Arguments: FollowListArgs (targetUid, initialTab) via settings.arguments
// ─────────────────────────────────────────────────────────────────────────────

class FollowListScreen extends StatelessWidget {
  const FollowListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final targetUid = args is FollowListArgs ? args.targetUid : '';
    final initialTab =
        args is FollowListArgs ? args.initialTab : FollowListTab.followers;

    if (targetUid.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              _TopBar(
                  title: 'People', onBack: () => Navigator.of(context).pop()),
              const Expanded(child: SizedBox()),
            ],
          ),
        ),
      );
    }

    return _FollowListBody(targetUid: targetUid, initialTab: initialTab);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BODY
// ─────────────────────────────────────────────────────────────────────────────

class _FollowListBody extends StatefulWidget {
  const _FollowListBody({required this.targetUid, required this.initialTab});

  final String targetUid;
  final FollowListTab initialTab;

  @override
  State<_FollowListBody> createState() => _FollowListBodyState();
}

class _FollowListBodyState extends State<_FollowListBody>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final String _currentUid;

  @override
  void initState() {
    super.initState();
    _currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab == FollowListTab.following ? 1 : 0,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOwnList = _currentUid == widget.targetUid;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              title: isOwnList ? 'Your Network' : 'Network',
              onBack: () => Navigator.of(context).pop(),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.onSurface.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: const EdgeInsets.all(4),
                dividerColor: Colors.transparent,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.onSurfaceVariant,
                labelStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                tabs: const [
                  Tab(text: 'Followers'),
                  Tab(text: 'Following'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _FollowSubList(
                    targetUid: widget.targetUid,
                    subcollection: 'followers',
                    isOwnList: isOwnList,
                    currentUid: _currentUid,
                    emptyIcon: Icons.people_outline_rounded,
                    emptyTitle: 'No followers yet',
                    emptyMessage: isOwnList
                        ? 'When someone follows you, they\'ll show up here.'
                        : 'This user has no followers yet.',
                  ),
                  _FollowSubList(
                    targetUid: widget.targetUid,
                    subcollection: 'following',
                    isOwnList: isOwnList,
                    currentUid: _currentUid,
                    emptyIcon: Icons.person_search_rounded,
                    emptyTitle: 'Not following anyone yet',
                    emptyMessage: isOwnList
                        ? 'Accounts you follow will show up here.'
                        : 'This user isn\'t following anyone yet.',
                  ),
                ],
              ),
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

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.onBack});

  final String title;
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
            title,
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
// SUB LIST  —  one tab's worth (either "followers" or "following")
//
// Streams users/{targetUid}/{subcollection}, then resolves each doc ID (a
// uid) into a PublicProfile via ProfileService.getProfile. Resolution runs
// once per snapshot and is cached by uid for the lifetime of this widget so
// switching tabs back and forth doesn't re-fetch profiles already seen.
// ─────────────────────────────────────────────────────────────────────────────

class _FollowSubList extends StatefulWidget {
  const _FollowSubList({
    required this.targetUid,
    required this.subcollection,
    required this.isOwnList,
    required this.currentUid,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyMessage,
  });

  final String targetUid;
  final String subcollection; // 'followers' or 'following'
  final bool isOwnList;
  final String currentUid;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyMessage;

  @override
  State<_FollowSubList> createState() => _FollowSubListState();
}

class _FollowSubListState extends State<_FollowSubList> {
  final Map<String, PublicProfile> _profileCache = {};

  // Tracks uids the current user follows, so each row's FollowButton (shown
  // only on your own lists) reflects the live state and can be toggled
  // in-place without leaving the screen.
  final Set<String> _followingUids = {};
  bool _followStateLoaded = false;
  final Set<String> _followActionInFlight = {};

  Stream<QuerySnapshot<Map<String, dynamic>>> get _stream =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(widget.targetUid)
          .collection(widget.subcollection)
          .orderBy('createdAt', descending: true)
          .snapshots();

  @override
  void initState() {
    super.initState();
    if (widget.isOwnList) _loadOwnFollowingState();
  }

  /// Loads which uids the current user already follows, so the per-row
  /// Follow/Unfollow button (only shown on your own Followers/Following
  /// lists) reflects accurate state immediately.
  Future<void> _loadOwnFollowingState() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUid)
          .collection('following')
          .get();
      if (!mounted) return;
      setState(() {
        _followingUids.addAll(snap.docs.map((d) => d.id));
        _followStateLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _followStateLoaded = true);
    }
  }

  Future<PublicProfile?> _resolve(String uid) async {
    final cached = _profileCache[uid];
    if (cached != null) return cached;
    try {
      final profile = await ProfileService.getProfile(uid);
      _profileCache[uid] = profile;
      return profile;
    } catch (_) {
      return null; // skip rows whose profile doc is missing/deleted
    }
  }

  Future<void> _toggleFollow(String targetUid) async {
    if (_followActionInFlight.contains(targetUid)) return;
    setState(() => _followActionInFlight.add(targetUid));

    final wasFollowing = _followingUids.contains(targetUid);
    try {
      if (wasFollowing) {
        await ShareService.unfollow(
          followerUid: widget.currentUid,
          followeeUid: targetUid,
        );
        if (mounted) setState(() => _followingUids.remove(targetUid));
      } else {
        await ShareService.follow(
          followerUid: widget.currentUid,
          followeeUid: targetUid,
        );
        if (mounted) setState(() => _followingUids.add(targetUid));
      }
    } catch (_) {
      // Silently ignore — row simply keeps its previous state on failure.
    } finally {
      if (mounted) {
        setState(() => _followActionInFlight.remove(targetUid));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        if (snapshot.hasError) {
          return _MessageState(
            icon: Icons.error_outline_rounded,
            iconColor: AppColors.error,
            title: 'Something went wrong',
            message: 'Unable to load this list. Please try again later.',
          );
        }

        final uids = snapshot.data?.docs.map((d) => d.id).toList() ?? [];

        if (uids.isEmpty) {
          return _MessageState(
            icon: widget.emptyIcon,
            iconColor: AppColors.primary,
            title: widget.emptyTitle,
            message: widget.emptyMessage,
          );
        }

        return FutureBuilder<List<PublicProfile?>>(
          // Keyed by the joined uid list so this only re-runs when the
          // actual set of uids changes, not on every rebuild.
          future: Future.wait(uids.map(_resolve)),
          builder: (context, profileSnapshot) {
            if (!profileSnapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            final profiles =
                profileSnapshot.data!.whereType<PublicProfile>().toList();

            if (profiles.isEmpty) {
              return _MessageState(
                icon: widget.emptyIcon,
                iconColor: AppColors.primary,
                title: widget.emptyTitle,
                message: widget.emptyMessage,
              );
            }

            return ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
              itemCount: profiles.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final profile = profiles[index];
                final isSelf = profile.uid == widget.currentUid;
                return _PersonTile(
                  profile: profile,
                  onTap: () => Navigator.of(context).pushNamed(
                    AppRoutes.publicProfile,
                    arguments: PublicProfileArgs(targetUid: profile.uid),
                  ),
                  // Follow button only makes sense on your own lists, and
                  // never on your own row.
                  trailing: widget.isOwnList && !isSelf && _followStateLoaded
                      ? FollowButton(
                          isFollowing: _followingUids.contains(profile.uid),
                          isLoading:
                              _followActionInFlight.contains(profile.uid),
                          onPressed: () => _toggleFollow(profile.uid),
                        )
                      : null,
                );
              },
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PERSON TILE
// ─────────────────────────────────────────────────────────────────────────────

class _PersonTile extends StatelessWidget {
  const _PersonTile({
    required this.profile,
    required this.onTap,
    this.trailing,
  });

  final PublicProfile profile;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.onSurface.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryContainer,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child:
                      profile.photoUrl != null && profile.photoUrl!.isNotEmpty
                          ? Image.network(
                              profile.photoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.person_rounded,
                                color: AppColors.primary,
                                size: 22,
                              ),
                            )
                          : const Icon(
                              Icons.person_rounded,
                              color: AppColors.primary,
                              size: 22,
                            ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.fullName.isNotEmpty
                          ? profile.fullName
                          : '@${profile.username}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (profile.username.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        '@${profile.username}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.outline,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY / ERROR STATE
// ─────────────────────────────────────────────────────────────────────────────

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: 0.35),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 38, color: iconColor),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w400,
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
