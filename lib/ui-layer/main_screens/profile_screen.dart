import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../landing_page/app_theme.dart';
import '../../business-layer/services/auth_google_service.dart';
import '../../data-layer/route_args/social_route_args.dart';
import '../../main.dart';
import 'settings/settings_screen.dart' show accountPrivacyNotifier;
import '../widgets/app_spinner.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PROFILE SCREEN
//
// Layout — top to bottom:
//   1. Hero header  — gradient band · avatar (gradient ring + privacy badge) ·
//                     full name · @username · member-since · "Edit Account" btn
//   2. Bio card     — shown only when bio is non-empty
//   3. About card   — school · course · year · region as labeled rows
//   4. Library card — Decks | Cards | Drafts | Shared  (4-cell stat band)
//   5. Settings card — Settings · Notifications
//   6. Log Out
//
// Preserved from baseline zip:
//   • _bodyKey (GlobalKey<_ProfileBodyState>) in _ProfileScaffoldState
//   • _loadProfile() + all original state fields (_loading, _fullName, _bio,
//     _course, _photoUrl, _deckCount, _cardCount, _draftCount)
//   • accountPrivacyNotifier listener wired in initState/dispose
//   • _publicDeckCount field
//   • All three Navigator routes (/account-settings, /settings, /notifications)
//   • AuthService().signOut() + pushNamedAndRemoveUntil('/') logout flow
//   • extendBody:true · SafeArea(bottom:false) · scroll padding bottom:120
// ─────────────────────────────────────────────────────────────────────────────

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) => const _ProfileScaffold();
}

// ─────────────────────────────────────────────────────────────────────────────
// SCAFFOLD
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileScaffold extends StatefulWidget {
  const _ProfileScaffold();

  @override
  State<_ProfileScaffold> createState() => _ProfileScaffoldState();
}

class _ProfileScaffoldState extends State<_ProfileScaffold> {
  final _bodyKey = GlobalKey<_ProfileBodyState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: Stack(
        children: [
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
            child: _ProfileBody(key: _bodyKey),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROFILE BODY
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileBody extends StatefulWidget {
  const _ProfileBody({super.key});

  @override
  State<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<_ProfileBody> {
  // ── Original preserved fields ─────────────────────────────────────────────
  bool _loading = true;
  String _fullName = '';
  String _bio = '';
  String _course = '';
  String? _photoUrl;
  int _deckCount = 0;
  int _cardCount = 0;
  int _draftCount = 0;

  // ── Extended identity fields ──────────────────────────────────────────────
  String _username = '';
  String _school = '';
  String _yearLevel = '';
  String _region = '';
  bool _isPrivate = false;
  Timestamp? _createdAt;

  // ── Shared decks ──────────────────────────────────────────────────────────
  int _publicDeckCount = 0;

  // ── Follow graph counts ───────────────────────────────────────────────────
  int _followerCount = 0;
  int _followingCount = 0;

  // ── Current uid (kept for tapping into the followers/following list) ─────
  String _uid = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
    accountPrivacyNotifier.addListener(_onPrivacyChanged);
  }

  @override
  void dispose() {
    accountPrivacyNotifier.removeListener(_onPrivacyChanged);
    super.dispose();
  }

  void _onPrivacyChanged() {
    if (!mounted) return;
    setState(() => _isPrivate = !accountPrivacyNotifier.value);
  }

  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    final authUser = FirebaseAuth.instance.currentUser!;

    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = userDoc.data() ?? {};

    final decksSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('decks')
        .get();

    int totalCards = 0;
    int drafts = 0;
    for (final doc in decksSnap.docs) {
      final d = doc.data();
      if (d['cardCount'] is int) {
        totalCards += (d['cardCount'] as int);
      } else if (d['cards'] is List) {
        totalCards += (d['cards'] as List).length;
      }
      if (d['isDraft'] == true) drafts++;
    }

    final publicSnap = await FirebaseFirestore.instance
        .collection('public_decks')
        .where('ownerUid', isEqualTo: uid)
        .get();

    final followerAggSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('followers')
        .count()
        .get();

    final followingAggSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('following')
        .count()
        .get();

    if (mounted) {
      setState(() {
        _uid = uid;
        _fullName = data['fullName'] as String? ?? '';
        _bio = data['bio'] as String? ?? '';
        _course = data['course'] as String? ?? '';
        _photoUrl = authUser.photoURL ?? data['photoUrl'] as String?;
        _deckCount = decksSnap.size;
        _cardCount = totalCards;
        _draftCount = drafts;
        _username = data['username'] as String? ?? '';
        _school = data['school'] as String? ?? '';
        _yearLevel = data['yearLevel'] as String? ?? '';
        _region = data['region'] as String? ?? '';
        _isPrivate = data['isPrivate'] as bool? ?? false;
        _createdAt = data['createdAt'] as Timestamp?;
        accountPrivacyNotifier.value = !_isPrivate;
        _publicDeckCount = publicSnap.size;
        _followerCount = followerAggSnap.count ?? 0;
        _followingCount = followingAggSnap.count ?? 0;
        _loading = false;
      });
    }
  }

  String get _memberSince {
    if (_createdAt == null) return '';
    final dt = _createdAt!.toDate();
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: AppSpinner());
    }

    final hasAbout = _school.isNotEmpty ||
        _course.isNotEmpty ||
        _yearLevel.isNotEmpty ||
        _region.isNotEmpty;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 1. Hero header ─────────────────────────────────────────────
          _HeroHeader(
            fullName: _fullName,
            username: _username,
            photoUrl: _photoUrl,
            isPrivate: _isPrivate,
            memberSince: _memberSince,
            followerCount: _followerCount,
            followingCount: _followingCount,
            onFollowersTap: () async {
              await Navigator.of(context).pushNamed(
                AppRoutes.followList,
                arguments: FollowListArgs(
                  targetUid: _uid,
                  initialTab: FollowListTab.followers,
                ),
              );
              _loadProfile();
            },
            onFollowingTap: () async {
              await Navigator.of(context).pushNamed(
                AppRoutes.followList,
                arguments: FollowListArgs(
                  targetUid: _uid,
                  initialTab: FollowListTab.following,
                ),
              );
              _loadProfile();
            },
            onEditTap: () async {
              await Navigator.of(context).pushNamed('/account-settings');
              _loadProfile();
            },
          ),

          const SizedBox(height: 20),

          // ── 2. Bio card ────────────────────────────────────────────────
          if (_bio.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: _BioCard(bio: _bio),
            ),

          // ── 3. About card ──────────────────────────────────────────────
          if (hasAbout)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: _AboutCard(
                school: _school,
                course: _course,
                yearLevel: _yearLevel,
                region: _region,
              ),
            ),

          // ── 4. Library stats ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: _LibraryCard(
              deckCount: _deckCount,
              cardCount: _cardCount,
              draftCount: _draftCount,
              publicDeckCount: _publicDeckCount,
            ),
          ),

          // ── 5. Settings card ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: _SettingsCard(onProfileEdited: _loadProfile),
          ),

          // ── 6. Log out ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const _LogOutButton(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. HERO HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.fullName,
    required this.username,
    required this.isPrivate,
    required this.memberSince,
    required this.followerCount,
    required this.followingCount,
    required this.onFollowersTap,
    required this.onFollowingTap,
    required this.onEditTap,
    this.photoUrl,
  });

  final String fullName;
  final String username;
  final String? photoUrl;
  final bool isPrivate;
  final String memberSince;
  final int followerCount;
  final int followingCount;
  final VoidCallback onFollowersTap;
  final VoidCallback onFollowingTap;
  final VoidCallback onEditTap;

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
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        children: [
          // Edit Account button — top right
          Align(
            alignment: Alignment.centerRight,
            child: _EditAccountButton(onTap: onEditTap),
          ),

          const SizedBox(height: 16),

          // Avatar
          Stack(
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
                child: _AvatarContent(
                  photoUrl: photoUrl,
                  fullName: fullName,
                ),
              ),
              Positioned(
                bottom: 2,
                right: 2,
                child: _PrivacyBadge(isPrivate: isPrivate),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Full name
          Text(
            fullName.isNotEmpty ? fullName : 'Your Name',
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
          if (username.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '@$username',
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

          // Followers / Following — tappable, no box, matches the stat-pill
          // styling already used on PublicProfileScreen.
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
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FOLLOW STAT
//
// Tappable count + label, deliberately undecorated — no box, no border, no
// fill — so it reads as plain text that happens to be tappable, matching the
// look of _StatPill on PublicProfileScreen but adding navigation.
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
                _formatCount(count),
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

  String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

class _EditAccountButton extends StatelessWidget {
  const _EditAccountButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer.withValues(alpha: 0.40),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.20),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_outlined, size: 13, color: AppColors.primary),
            const SizedBox(width: 5),
            Text(
              'Edit Account',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRIVACY BADGE
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
// 2. BIO CARD
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
// 3. ABOUT CARD — school / course / year / region as clean labeled rows
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
    final rows = <_AboutRow>[
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
    ];

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardLabel(icon: Icons.person_outline_rounded, label: 'ABOUT'),
          const SizedBox(height: 12),
          ...rows.map((r) => _AboutRowWidget(row: r)),
        ],
      ),
    );
  }
}

class _AboutRow {
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
}

class _AboutRowWidget extends StatelessWidget {
  const _AboutRowWidget({required this.row});
  final _AboutRow row;

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
              color: row.color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(row.icon, size: 16, color: row.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.label.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  row.value,
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
// 4. LIBRARY CARD — 4-cell stat grid
// ─────────────────────────────────────────────────────────────────────────────

class _LibraryCard extends StatelessWidget {
  const _LibraryCard({
    required this.deckCount,
    required this.cardCount,
    required this.draftCount,
    required this.publicDeckCount,
  });

  final int deckCount;
  final int cardCount;
  final int draftCount;
  final int publicDeckCount;

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
          _CardLabel(icon: Icons.bar_chart_rounded, label: 'YOUR LIBRARY'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatCell(
                  value: '$deckCount',
                  label: 'Decks',
                  icon: Icons.layers_outlined,
                  color: AppColors.primary,
                ),
              ),
              _StatDivider(),
              Expanded(
                child: _StatCell(
                  value: '$cardCount',
                  label: 'Cards',
                  icon: Icons.style_outlined,
                  color: AppColors.secondary,
                ),
              ),
              _StatDivider(),
              Expanded(
                child: _StatCell(
                  value: '$draftCount',
                  label: 'Drafts',
                  icon: Icons.drafts_outlined,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              _StatDivider(),
              Expanded(
                child: _StatCell(
                  value: '$publicDeckCount',
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
// 5. SETTINGS CARD — Settings · Notifications
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.onProfileEdited});
  final VoidCallback onProfileEdited;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CardLabel(
          icon: Icons.tune_rounded,
          label: 'SETTINGS & PREFERENCES',
          padding: const EdgeInsets.fromLTRB(4, 0, 0, 12),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.28),
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
          child: Column(
            children: [
              _SettingsTile(
                icon: Icons.settings_outlined,
                iconBg: AppColors.primaryContainer.withValues(alpha: 0.45),
                iconColor: AppColors.primary,
                label: 'Settings',
                isFirst: true,
                onTap: () => Navigator.of(context).pushNamed('/settings'),
              ),
              _TileDivider(),
              _SettingsTile(
                icon: Icons.notifications_outlined,
                iconBg: AppColors.tertiaryContainer.withValues(alpha: 0.5),
                iconColor: AppColors.onTertiaryContainer,
                label: 'Notifications',
                isLast: true,
                onTap: () => Navigator.of(context).pushNamed('/notifications'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SETTINGS TILE
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.isFirst = false,
    this.isLast = false,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.vertical(
            top: isFirst ? const Radius.circular(20) : Radius.zero,
            bottom: isLast ? const Radius.circular(20) : Radius.zero,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: iconColor, size: 21),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.55),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TileDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 72),
      child: Container(
        height: 1,
        color: AppColors.outlineVariant.withValues(alpha: 0.22),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 6. LOG OUT BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _LogOutButton extends StatelessWidget {
  const _LogOutButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.18),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.error.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showLogoutConfirmation(context),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      Icons.logout_rounded,
                      color: AppColors.error,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Log Out',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.error.withValues(alpha: 0.45),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showLogoutConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: AppColors.surfaceContainerLowest,
        title: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child:
                  Icon(Icons.logout_rounded, color: AppColors.error, size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              'Log Out?',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to log out of your account?',
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
          ElevatedButton(
            onPressed: () => Navigator.pop(_, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Log Out',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await AuthService().signOut();
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AVATAR CONTENT
// ─────────────────────────────────────────────────────────────────────────────

class _AvatarContent extends StatelessWidget {
  const _AvatarContent({
    required this.photoUrl,
    required this.fullName,
  });

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
// SHARED DESIGN PRIMITIVES
// ─────────────────────────────────────────────────────────────────────────────

/// A uniform card container used by BioCard, AboutCard, etc.
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

/// Small all-caps label with a leading icon — used consistently above each
/// section to build visual hierarchy without heavy headers.
class _CardLabel extends StatelessWidget {
  const _CardLabel({
    required this.icon,
    required this.label,
    this.padding,
  });

  final IconData icon;
  final String label;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Row(
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
      ),
    );
  }
}

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
