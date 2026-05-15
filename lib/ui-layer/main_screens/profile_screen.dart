import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../landing_page/app_theme.dart';
import '../../business-layer/services/auth_google_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PROFILE SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ProfileScaffold();
  }
}

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
          // ── Decorative blobs ──────────────────────────────────────────────
          Positioned(
            top: -80,
            left: -60,
            child: _Blob(
              size: 340,
              color: AppColors.secondaryContainer.withOpacity(0.20),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).size.height * 0.4,
            right: -100,
            child: _Blob(
              size: 300,
              color: AppColors.tertiaryContainer.withOpacity(0.15),
            ),
          ),

          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const _ProfileTopBar(),
                Expanded(
                  child: _ProfileBody(key: _bodyKey),
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
// TOP APP BAR  — glassmorphic pill, "Mnemo" centred italic, avatar on right
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileTopBar extends StatelessWidget {
  const _ProfileTopBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryFixedDim],
            ).createShader(bounds),
            child: Text(
              'Mnemo',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                fontStyle: FontStyle.italic,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.secondary.withOpacity(0.15),
                  AppColors.tertiary.withOpacity(0.10),
                ],
              ),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppColors.secondary.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.person_rounded,
                  color: AppColors.secondary,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  'PROFILE',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.secondary,
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
// PROFILE BODY  — stateful, owns all data + photo upload logic
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileBody extends StatefulWidget {
  const _ProfileBody({super.key});

  @override
  State<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<_ProfileBody> {
  bool _loading = true;
  bool _uploadingPhoto = false;

  // ── Profile fields ────────────────────────────────────────────────────────
  String _fullName = '';
  String _bio = '';
  String _course = '';
  String? _photoUrl;

  // ── Stats ─────────────────────────────────────────────────────────────────
  int _deckCount = 0;
  int _cardCount = 0;
  int _draftCount = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

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

    // ── Decks subcollection ───────────────────────────────────────────────
    final decksSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('decks')
        .get();

    int totalCards = 0;
    int drafts = 0;

    for (final doc in decksSnap.docs) {
      final d = doc.data();
      // Count total cards (field name may vary; try cardCount or cards list)
      if (d['cardCount'] is int) {
        totalCards += (d['cardCount'] as int);
      } else if (d['cards'] is List) {
        totalCards += (d['cards'] as List).length;
      }
      // Count drafts
      if (d['isDraft'] == true) drafts++;
    }

    if (mounted) {
      setState(() {
        _fullName = data['fullName'] as String? ?? '';
        _bio = data['bio'] as String? ?? '';
        _course = data['course'] as String? ?? '';
        _photoUrl = authUser.photoURL ?? data['photoUrl'] as String?;
        _deckCount = decksSnap.size;
        _cardCount = totalCards;
        _draftCount = drafts;
        _loading = false;
      });
    }
  }

  // ── Photo picker & uploader moved to profile-personal-info_screen.dart ──

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

    // Build the bio/subtitle line (course + bio combined if both present)
    final String subtitleLine = [
      if (_course.isNotEmpty) _course,
      if (_bio.isNotEmpty) _bio,
    ].join(' • ');

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
      child: Column(
        children: [
          // ── Profile Header (centered) ──────────────────────────────────
          _ProfileHeader(
            fullName: _fullName,
            subtitle: subtitleLine,
            photoUrl: _photoUrl,
            uploadingPhoto: _uploadingPhoto,
          ),
          const SizedBox(height: 32),

          // ── Stats Card ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryContainer.withOpacity(0.3),
                  AppColors.secondaryContainer.withOpacity(0.2),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.outlineVariant.withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.onSurface.withOpacity(0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.bar_chart_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'YOUR LIBRARY',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _StatsRow(
                  deckCount: _deckCount,
                  cardCount: _cardCount,
                  draftCount: _draftCount,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Settings Section Header ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
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

          // ── Settings Card ──────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.outlineVariant.withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.onSurface.withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.manage_accounts_outlined,
                  iconBg: AppColors.secondaryContainer.withOpacity(0.5),
                  iconColor: AppColors.onSecondaryContainer,
                  label: 'Personal Information',
                  isFirst: true,
                  onTap: () async {
                    await Navigator.of(context).pushNamed('/account-settings');
                    _loadProfile();
                  },
                ),
                _SettingsDivider(),
                _SettingsTile(
                  icon: Icons.settings_outlined,
                  iconBg: AppColors.primaryContainer.withOpacity(0.5),
                  iconColor: AppColors.primary,
                  label: 'Settings',
                  onTap: () => Navigator.of(context).pushNamed('/settings'),
                ),
                _SettingsDivider(),
                _SettingsTile(
                  icon: Icons.notifications_outlined,
                  iconBg: AppColors.tertiaryContainer.withOpacity(0.5),
                  iconColor: AppColors.onTertiaryContainer,
                  label: 'Notifications',
                  onTap: () {},
                ),
                _SettingsDivider(),
                _SettingsTile(
                  icon: Icons.palette_outlined,
                  iconBg: AppColors.primaryContainer.withOpacity(0.3),
                  iconColor: AppColors.primary,
                  label: 'Appearance',
                  isLast: true,
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Log Out ────────────────────────────────────────────────────
          _LogOutButton(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROFILE HEADER  — avatar with edit pen, name, subtitle/bio
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.fullName,
    required this.subtitle,
    this.photoUrl,
    this.uploadingPhoto = false,
  });

  final String fullName;
  final String subtitle;
  final String? photoUrl;
  final bool uploadingPhoto;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Avatar (centered) ─────────────────────────────────────────────
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.2),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.3),
                      AppColors.secondary.withOpacity(0.2),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.all(4),
                child: _AvatarContent(
                  photoUrl: photoUrl,
                  fullName: fullName,
                  uploading: uploadingPhoto,
                ),
              ),
            ),
            if (uploadingPhoto)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.5),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),

        // ── Name + subtitle (centered) ────────────────────────────────────
        Text(
          fullName,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: AppColors.onSurface,
            height: 1.1,
          ),
          textAlign: TextAlign.center,
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppColors.outlineVariant.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Text(
              subtitle,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.4,
                color: AppColors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AVATAR CONTENT  — photo → initial letter → default icon
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
              color: AppColors.primaryContainer.withOpacity(0.2),
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
// FALLBACK AVATAR  — initial letter  OR  person icon
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
        color: AppColors.primaryContainer.withOpacity(0.3),
      ),
      child: Icon(
        Icons.person_rounded,
        size: 60,
        color: AppColors.primary.withOpacity(0.5),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATS ROW  — horizontal stats display
// ─────────────────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.deckCount,
    required this.cardCount,
    required this.draftCount,
  });

  final int deckCount;
  final int cardCount;
  final int draftCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatItem(
            value: '$deckCount',
            label: 'Decks',
          ),
        ),
        Container(
          width: 1,
          height: 40,
          color: AppColors.outlineVariant.withOpacity(0.3),
        ),
        Expanded(
          child: _StatItem(
            value: '$cardCount',
            label: 'Cards',
          ),
        ),
        Container(
          width: 1,
          height: 40,
          color: AppColors.outlineVariant.withOpacity(0.3),
        ),
        Expanded(
          child: _StatItem(
            value: '$draftCount',
            label: 'Drafts',
          ),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
            height: 1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SETTINGS TILE  — rounded card row with icon, label, chevron
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
        color: AppColors.outlineVariant.withOpacity(0.2),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOG OUT BUTTON
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
          color: AppColors.error.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.error.withOpacity(0.08),
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
                      color: AppColors.error.withOpacity(0.15),
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
                    color: AppColors.error.withOpacity(0.6),
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
                color: AppColors.error.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.logout_rounded,
                  color: AppColors.error, size: 22),
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
