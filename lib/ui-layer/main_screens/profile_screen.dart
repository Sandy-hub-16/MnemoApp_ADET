import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../landing_page/app_theme.dart';
import '../../business-layer/services/auth_google_service.dart';
import '../../business-layer/services/profile_service.dart';
import '../../data-layer/models/social/public_deck_summary.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PROFILE SCREEN  (redesigned)
//
// Visual layout — top to bottom:
//   1. Identity hero   — avatar (gradient ring) · full name · @username ·
//                        privacy badge · member-since · bio block ·
//                        education/region chips
//   2. Library stats   — Total Decks | Total Cards | Drafts | Shared
//   3. Shared decks    — live stream via ProfileService.userDecksStream()
//   4. Settings group  — Personal Information · Settings · Notifications
//   5. Log Out
//
// ⚠ PRESERVATION RULES (do not change):
//   • _ProfileScaffoldState keeps _bodyKey (GlobalKey<_ProfileBodyState>)
//   • _ProfileBodyState keeps _loadProfile(), _loading,
//     _fullName, _bio, _course, _deckCount, _cardCount, _draftCount
//   • All three Navigator.pushNamed routes are unchanged
//   • _LogOutButton uses AuthService().signOut() then pushNamedAndRemoveUntil
//   • Scaffold has extendBody:true; scroll padding bottom:120 for nav bar
//   • No top-bar title rendered here — handled by _PersistentTopBar in
//     main_shell.dart
// ─────────────────────────────────────────────────────────────────────────────

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ProfileScaffold();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCAFFOLD  (unchanged structure from original)
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileScaffold extends StatefulWidget {
  const _ProfileScaffold();

  @override
  State<_ProfileScaffold> createState() => _ProfileScaffoldState();
}

class _ProfileScaffoldState extends State<_ProfileScaffold> {
  // Kept from original — referenced by _ProfileBodyState consumers.
  final _bodyKey = GlobalKey<_ProfileBodyState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: Stack(
        children: [
          // ── Decorative blobs (original positions preserved) ────────────
          Positioned(
            top: -80,
            left: -60,
            child: _Blob(
              size: 340,
              color: AppColors.secondaryContainer.withValues(alpha: 0.20),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).size.height * 0.4,
            right: -100,
            child: _Blob(
              size: 300,
              color: AppColors.tertiaryContainer.withValues(alpha: 0.15),
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
// PROFILE BODY  — stateful, owns all data.
//
// All original state fields are kept verbatim; additional fields are additive.
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileBody extends StatefulWidget {
  const _ProfileBody({super.key});

  @override
  State<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<_ProfileBody> {
  // ── Original fields (must not be removed) ────────────────────────────────
  bool _loading = true;
  String _fullName = '';
  String _bio = '';
  String _course = '';
  String? _photoUrl;

  int _deckCount = 0;
  int _cardCount = 0;
  int _draftCount = 0;

  // ── Additional identity fields ────────────────────────────────────────────
  String _username = '';
  String _school = '';
  String _yearLevel = '';
  String _region = '';
  bool _isPrivate = false;
  Timestamp? _createdAt;

  // ── Shared-decks counters + live stream ───────────────────────────────────
  int _publicDeckCount = 0;
  Stream<List<PublicDeckSummary>>? _publicDecksStream;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // ── _loadProfile (original logic preserved; new fields read additively) ───
  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }

    final authUser = FirebaseAuth.instance.currentUser!;

    // ── Firestore user doc ────────────────────────────────────────────────
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = userDoc.data() ?? {};

    // ── Decks subcollection (original logic unchanged) ────────────────────
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

    // ── Public decks count (one-shot) ────────────────────────────────────
    final publicSnap = await FirebaseFirestore.instance
        .collection('public_decks')
        .where('ownerUid', isEqualTo: uid)
        .get();

    // ── Live public-decks stream via ProfileService ───────────────────────
    final stream = ProfileService.userDecksStream(uid);

    if (mounted) {
      setState(() {
        // Original fields
        _fullName = data['fullName'] as String? ?? '';
        _bio = data['bio'] as String? ?? '';
        _course = data['course'] as String? ?? '';
        _photoUrl = authUser.photoURL ?? data['photoUrl'] as String?;
        _deckCount = decksSnap.size;
        _cardCount = totalCards;
        _draftCount = drafts;

        // Additional identity fields
        _username = data['username'] as String? ?? '';
        _school = data['school'] as String? ?? '';
        _yearLevel = data['yearLevel'] as String? ?? '';
        _region = data['region'] as String? ?? '';
        _isPrivate = data['isPrivate'] as bool? ?? false;
        _createdAt = data['createdAt'] as Timestamp?;

        // Shared decks
        _publicDeckCount = publicSnap.size;
        _publicDecksStream = stream;

        _loading = false;
      });
    }
  }

  // ── "Member since" helper ─────────────────────────────────────────────────
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
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 2,
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. Identity hero ───────────────────────────────────────────
          _IdentityHero(
            fullName: _fullName,
            username: _username,
            bio: _bio,
            school: _school,
            course: _course,
            yearLevel: _yearLevel,
            region: _region,
            photoUrl: _photoUrl,
            isPrivate: _isPrivate,
            memberSince: _memberSince,
            onEditTap: () async {
              await Navigator.of(context).pushNamed('/account-settings');
              _loadProfile();
            },
          ),

          const SizedBox(height: 24),

          // ── 2. Library stats ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _LibraryStats(
              deckCount: _deckCount,
              cardCount: _cardCount,
              draftCount: _draftCount,
              publicDeckCount: _publicDeckCount,
            ),
          ),

          const SizedBox(height: 24),

          // ── 3. Shared decks ────────────────────────────────────────────
          if (_publicDecksStream != null)
            _SharedDecksSection(stream: _publicDecksStream!),

          const SizedBox(height: 24),

          // ── 4. Settings section header ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 20, 12),
            child: Row(
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 16,
                  color: AppColors.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  'SETTINGS & PREFERENCES',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurfaceVariant,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),

          // ── 4. Settings card ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.outlineVariant.withValues(alpha: 0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.onSurface.withValues(alpha: 0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.manage_accounts_outlined,
                    iconBg: AppColors.secondaryContainer.withValues(alpha: 0.5),
                    iconColor: AppColors.onSecondaryContainer,
                    label: 'Personal Information',
                    isFirst: true,
                    onTap: () async {
                      await Navigator.of(context)
                          .pushNamed('/account-settings');
                      _loadProfile();
                    },
                  ),
                  _SettingsDivider(),
                  _SettingsTile(
                    icon: Icons.settings_outlined,
                    iconBg: AppColors.primaryContainer.withValues(alpha: 0.5),
                    iconColor: AppColors.primary,
                    label: 'Settings',
                    onTap: () => Navigator.of(context).pushNamed('/settings'),
                  ),
                  _SettingsDivider(),
                  _SettingsTile(
                    icon: Icons.notifications_outlined,
                    iconBg: AppColors.tertiaryContainer.withValues(alpha: 0.5),
                    iconColor: AppColors.onTertiaryContainer,
                    label: 'Notifications',
                    isLast: true,
                    onTap: () =>
                        Navigator.of(context).pushNamed('/notifications'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── 5. Log Out ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _LogOutButton(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. IDENTITY HERO
//    Full-width gradient band: avatar · name · @username · privacy badge ·
//    member-since · bio · education/region chips · edit-profile button
// ─────────────────────────────────────────────────────────────────────────────

class _IdentityHero extends StatelessWidget {
  const _IdentityHero({
    required this.fullName,
    required this.username,
    required this.bio,
    required this.school,
    required this.course,
    required this.yearLevel,
    required this.region,
    required this.isPrivate,
    required this.memberSince,
    required this.onEditTap,
    this.photoUrl,
  });

  final String fullName;
  final String username;
  final String bio;
  final String school;
  final String course;
  final String yearLevel;
  final String region;
  final String? photoUrl;
  final bool isPrivate;
  final String memberSince;
  final VoidCallback onEditTap;

  @override
  Widget build(BuildContext context) {
    // Build identity chips — only show chips that have a value
    final chips = <_ChipData>[
      if (school.isNotEmpty)
        _ChipData(
          icon: Icons.school_outlined,
          label: school,
          bgColor: AppColors.secondaryContainer.withValues(alpha: 0.5),
          iconColor: AppColors.onSecondaryContainer,
        ),
      if (course.isNotEmpty)
        _ChipData(
          icon: Icons.menu_book_outlined,
          label: course,
          bgColor: AppColors.tertiaryContainer.withValues(alpha: 0.5),
          iconColor: AppColors.onTertiaryContainer,
        ),
      if (yearLevel.isNotEmpty)
        _ChipData(
          icon: Icons.grade_outlined,
          label: yearLevel,
          bgColor: AppColors.primaryContainer.withValues(alpha: 0.45),
          iconColor: AppColors.primary,
        ),
      if (region.isNotEmpty)
        _ChipData(
          icon: Icons.location_on_outlined,
          label: region,
          bgColor: AppColors.surfaceContainerLow,
          iconColor: AppColors.onSurfaceVariant,
        ),
    ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.10),
            AppColors.secondaryContainer.withValues(alpha: 0.16),
            AppColors.background,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.50, 1.0],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Edit profile button (top-right) ──────────────────────────
          Align(
            alignment: Alignment.centerRight,
            child: _EditProfileButton(onTap: onEditTap),
          ),

          const SizedBox(height: 12),

          // ── Avatar with privacy badge ─────────────────────────────────
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Gradient ring
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.35),
                      AppColors.secondary.withValues(alpha: 0.25),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.20),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(4),
                child: _AvatarContent(
                  photoUrl: photoUrl,
                  fullName: fullName,
                  uploading: false,
                ),
              ),
              // Privacy badge — bottom-right corner of avatar
              Positioned(
                bottom: 2,
                right: 2,
                child: _PrivacyBadge(isPrivate: isPrivate),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Full name ─────────────────────────────────────────────────
          Text(
            fullName.isNotEmpty ? fullName : 'Your Name',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: AppColors.onSurface,
              height: 1.1,
            ),
            textAlign: TextAlign.center,
          ),

          // ── @username ─────────────────────────────────────────────────
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

          // ── Member since ──────────────────────────────────────────────
          if (memberSince.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 11,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.65),
                ),
                const SizedBox(width: 5),
                Text(
                  memberSince,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ],

          // ── Bio ───────────────────────────────────────────────────────
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.outlineVariant.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.format_quote_rounded,
                        size: 13,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'BIO',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    bio,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.onSurface,
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Education / region chips ──────────────────────────────────
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: chips.map((c) => _InfoChip(data: c)).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EDIT PROFILE BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _EditProfileButton extends StatelessWidget {
  const _EditProfileButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.22),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_outlined, size: 13, color: AppColors.primary),
            const SizedBox(width: 5),
            Text(
              'Edit Profile',
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
// PRIVACY BADGE  — small pill overlaid on avatar corner
// ─────────────────────────────────────────────────────────────────────────────

class _PrivacyBadge extends StatelessWidget {
  const _PrivacyBadge({required this.isPrivate});
  final bool isPrivate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isPrivate
            ? AppColors.onSurface.withValues(alpha: 0.82)
            : AppColors.primary.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: AppColors.background,
          width: 2,
        ),
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
// INFO CHIP  — school / course / year / region tag
// ─────────────────────────────────────────────────────────────────────────────

class _ChipData {
  const _ChipData({
    required this.icon,
    required this.label,
    required this.bgColor,
    required this.iconColor,
  });
  final IconData icon;
  final String label;
  final Color bgColor;
  final Color iconColor;
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.data});
  final _ChipData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: data.bgColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: data.iconColor.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(data.icon, size: 12, color: data.iconColor),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              data.label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. LIBRARY STATS  — 4-cell gradient card
// ─────────────────────────────────────────────────────────────────────────────

class _LibraryStats extends StatelessWidget {
  const _LibraryStats({
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
      padding: const EdgeInsets.fromLTRB(8, 20, 8, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryContainer.withValues(alpha: 0.28),
            AppColors.secondaryContainer.withValues(alpha: 0.20),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.28),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Section label
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 16),
            child: Row(
              children: [
                Icon(Icons.bar_chart_rounded,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 7),
                Text(
                  'YOUR LIBRARY',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.3,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          // 4 stat cells
          Row(
            children: [
              Expanded(
                child: _StatCell(
                  value: '$deckCount',
                  label: 'Total Decks',
                  icon: Icons.layers_outlined,
                  color: AppColors.primary,
                ),
              ),
              _VertDivider(),
              Expanded(
                child: _StatCell(
                  value: '$cardCount',
                  label: 'Total Cards',
                  icon: Icons.style_outlined,
                  color: AppColors.secondary,
                ),
              ),
              _VertDivider(),
              Expanded(
                child: _StatCell(
                  value: '$draftCount',
                  label: 'Drafts',
                  icon: Icons.drafts_outlined,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              _VertDivider(),
              Expanded(
                child: _StatCell(
                  value: '$publicDeckCount',
                  label: 'Shared',
                  icon: Icons.public_outlined,
                  color: AppColors.onTertiaryContainer,
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
          child: Icon(icon, size: 18, color: color),
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
        const SizedBox(height: 4),
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

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 56,
      color: AppColors.outlineVariant.withValues(alpha: 0.28),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. SHARED DECKS SECTION
//    Uses ProfileService.userDecksStream() — same stream the public profile
//    screen uses; no duplicate Firestore logic.
// ─────────────────────────────────────────────────────────────────────────────

class _SharedDecksSection extends StatelessWidget {
  const _SharedDecksSection({required this.stream});
  final Stream<List<PublicDeckSummary>> stream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PublicDeckSummary>>(
      stream: stream,
      builder: (context, snapshot) {
        final decks = snapshot.data ?? [];

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section header
              Row(
                children: [
                  Icon(Icons.public_rounded,
                      size: 14, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    'SHARED DECKS',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  if (decks.isNotEmpty)
                    Text(
                      '${decks.length} ${decks.length == 1 ? 'deck' : 'decks'}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color:
                            AppColors.onSurfaceVariant.withValues(alpha: 0.55),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              if (snapshot.connectionState == ConnectionState.waiting)
                Container(
                  height: 80,
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2,
                  ),
                )
              else if (decks.isEmpty)
                _EmptySharedDecks()
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: decks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _SharedDeckRow(deck: decks[i]),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SharedDeckRow extends StatelessWidget {
  const _SharedDeckRow({required this.deck});
  final PublicDeckSummary deck;

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 365) {
      final y = (diff.inDays / 365).floor();
      return '$y ${y == 1 ? 'year' : 'years'} ago';
    }
    if (diff.inDays >= 30) {
      final mo = (diff.inDays / 30).floor();
      return '$mo ${mo == 1 ? 'month' : 'months'} ago';
    }
    if (diff.inDays >= 1) {
      return '${diff.inDays} ${diff.inDays == 1 ? 'day' : 'days'} ago';
    }
    if (diff.inHours >= 1) {
      return '${diff.inHours} ${diff.inHours == 1 ? 'hour' : 'hours'} ago';
    }
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Deck icon
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryContainer.withValues(alpha: 0.6),
                  AppColors.secondaryContainer.withValues(alpha: 0.5),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.layers_rounded,
              size: 22,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),

          // Title + meta
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deck.title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    // Tag pill
                    if (deck.tag.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryContainer
                              .withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          deck.tag.toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onSecondaryContainer,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    if (deck.tag.isNotEmpty) const SizedBox(width: 6),
                    Text(
                      '${deck.cardCount} ${deck.cardCount == 1 ? 'card' : 'cards'}'
                      ' · ${_timeAgo(deck.sharedAt)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Clone count
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(
                Icons.copy_rounded,
                size: 12,
                color: AppColors.secondary.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 2),
              Text(
                '${deck.cloneCount}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptySharedDecks extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.public_off_rounded,
              size: 24,
              color: AppColors.primary.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'No shared decks yet',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Share a deck to make it visible on your profile',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
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
// AVATAR CONTENT  — photo → initial letter → default icon (unchanged logic)
// ─────────────────────────────────────────────────────────────────────────────

class _AvatarContent extends StatelessWidget {
  const _AvatarContent({
    required this.photoUrl,
    required this.fullName,
    this.uploading = false,
  });

  final String? photoUrl;
  final String fullName;
  final bool uploading;

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          photoUrl!,
          width: 112,
          height: 112,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: 112,
              height: 112,
              color: AppColors.primaryContainer.withValues(alpha: 0.2),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) =>
              _FallbackAvatar(fullName: fullName),
        ),
      );
    }
    return _FallbackAvatar(fullName: fullName);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FALLBACK AVATAR  — initial letter OR person icon (unchanged logic)
// ─────────────────────────────────────────────────────────────────────────────

class _FallbackAvatar extends StatelessWidget {
  const _FallbackAvatar({required this.fullName});
  final String fullName;

  @override
  Widget build(BuildContext context) {
    if (fullName.isNotEmpty) {
      return Container(
        width: 112,
        height: 112,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              AppColors.primaryContainer,
              AppColors.secondaryContainer,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Text(
            fullName[0].toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ),
      );
    }

    return Container(
      width: 112,
      height: 112,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primaryContainer.withValues(alpha: 0.3),
      ),
      child: Icon(
        Icons.person_rounded,
        size: 60,
        color: AppColors.primary.withValues(alpha: 0.5),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SETTINGS TILE  — rounded card row with icon, label, chevron (unchanged)
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
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
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
                  color: AppColors.onSurfaceVariant,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 76),
      child: Container(
        height: 1,
        color: AppColors.outlineVariant.withValues(alpha: 0.2),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOG OUT BUTTON  — unchanged logic and structure
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
          color: AppColors.error.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.error.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
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
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.logout_rounded,
                        color: AppColors.error, size: 22),
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
                    color: AppColors.error.withValues(alpha: 0.6),
                    size: 22,
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
                color: AppColors.error.withValues(alpha: 0.15),
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
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Log Out',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
              ),
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
