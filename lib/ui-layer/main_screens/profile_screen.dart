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

  Future<void> _goToSettings() async {
    await Navigator.of(context).pushNamed('/account-settings');
    _bodyKey.currentState?._loadProfile();
  }

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
                _ProfileTopBar(onSettingsTap: _goToSettings),
                Expanded(
                  child: _ProfileBody(key: _bodyKey),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const _BottomNavBar(activeIndex: 4),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOP APP BAR  — glassmorphic pill, "Mnemo" centred italic, avatar on right
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileTopBar extends StatelessWidget {
  const _ProfileTopBar({required this.onSettingsTap});
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.75),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Menu button
          _NavIconButton(icon: Icons.menu_rounded, onTap: () {}),

          // "Mnemo" title — centred
          Expanded(
            child: Center(
              child: Text(
                'Mnemo',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  color: AppColors.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),

          // Settings button
          _NavIconButton(icon: Icons.settings_outlined, onTap: onSettingsTap),
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
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Profile Header ─────────────────────────────────────────────
          _ProfileHeader(
            fullName: _fullName,
            subtitle: subtitleLine,
            photoUrl: _photoUrl,
            uploadingPhoto: _uploadingPhoto,
          ),
          const SizedBox(height: 32),

          // ── Stats Bento ────────────────────────────────────────────────
          _StatsBento(
            deckCount: _deckCount,
            cardCount: _cardCount,
            draftCount: _draftCount,
          ),
          const SizedBox(height: 32),

          // ── Settings label ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'Account Settings',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurfaceVariant,
                letterSpacing: 1.4,
              ),
            ),
          ),

          // ── Settings List ──────────────────────────────────────────────
          _SettingsTile(
            icon: Icons.manage_accounts_outlined,
            iconBg: AppColors.secondaryContainer.withOpacity(0.5),
            iconColor: AppColors.onSecondaryContainer,
            label: 'Personal Information',
            onTap: () async {
              await Navigator.of(context).pushNamed('/account-settings');
              _loadProfile();
            },
          ),
          const SizedBox(height: 10),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            iconBg: AppColors.tertiaryContainer.withOpacity(0.5),
            iconColor: AppColors.onTertiaryContainer,
            label: 'Notifications',
            onTap: () {},
          ),
          const SizedBox(height: 10),
          _SettingsTile(
            icon: Icons.palette_outlined,
            iconBg: AppColors.primaryContainer.withOpacity(0.3),
            iconColor: AppColors.primary,
            label: 'Appearance',
            onTap: () {},
          ),
          const SizedBox(height: 24),

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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── Avatar (display only — edit is in Personal Information) ──────
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.25),
                    AppColors.primaryContainer.withOpacity(0.40),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.all(3),
              child: _AvatarContent(
                photoUrl: photoUrl,
                fullName: fullName,
                uploading: uploadingPhoto,
              ),
            ),
            if (uploadingPhoto)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.4),
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

        const SizedBox(width: 20),

        // ── Name + subtitle ───────────────────────────────────────────────
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fullName,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: AppColors.onSurface,
                  height: 1.1,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    height: 1.55,
                    color: AppColors.onSurfaceVariant,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
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
// STATS BENTO  — container wrapping the 3 stat cards
// ─────────────────────────────────────────────────────────────────────────────

class _StatsBento extends StatelessWidget {
  const _StatsBento({
    required this.deckCount,
    required this.cardCount,
    required this.draftCount,
  });

  final int deckCount;
  final int cardCount;
  final int draftCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
            child: Text(
              'Learning Stats',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurfaceVariant,
                letterSpacing: 1.4,
              ),
            ),
          ),

          // Top card — Decks Built (wider, accent blob)
          _DecksBuiltCard(count: deckCount),
          const SizedBox(height: 10),

          // Bottom row — Cards Saved + Drafts
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.bookmark_rounded,
                  iconColor: AppColors.secondary,
                  value: '$cardCount',
                  label: 'Cards Saved',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  icon: Icons.note_rounded,
                  iconColor: AppColors.tertiary,
                  value: '$draftCount',
                  label: 'Drafts',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DecksBuiltCard extends StatelessWidget {
  const _DecksBuiltCard({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Accent blob in top-right
          Positioned(
            top: -16,
            right: -16,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withOpacity(0.30),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.layers_rounded,
                color: AppColors.primary,
                size: 28,
              ),
              const SizedBox(height: 12),
              Text(
                '$count',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: AppColors.onSurface,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Decks Built',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
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

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 26),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: AppColors.onSurface,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
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
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 21),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOG OUT BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _LogOutButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () async {
          await AuthService().signOut();
          if (context.mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            color: AppColors.errorContainer.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: AppColors.errorContainer.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.logout_rounded,
                    color: AppColors.error, size: 21),
              ),
              const SizedBox(width: 16),
              Text(
                'Log Out',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
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
// BOTTOM NAV BAR
// ─────────────────────────────────────────────────────────────────────────────

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({required this.activeIndex});
  final int activeIndex;

  static const _items = [
    _NavItem(
        icon: Icons.home_outlined,
        filled: Icons.home_rounded,
        label: 'Home',
        route: '/home'),
    _NavItem(
        icon: Icons.layers_outlined,
        filled: Icons.layers_rounded,
        label: 'Decks',
        route: '/decks'),
    _NavItem(
        icon: Icons.explore_outlined,
        filled: Icons.explore_rounded,
        label: 'Discover',
        route: '/discover'),
    _NavItem(
        icon: Icons.analytics_outlined,
        filled: Icons.analytics_rounded,
        label: 'Progress',
        route: '/progress'),
    _NavItem(
        icon: Icons.person_outline_rounded,
        filled: Icons.person_rounded,
        label: 'Profile',
        route: '/profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withOpacity(0.06),
            blurRadius: 32,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
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
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.primaryContainer.withOpacity(0.45)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        active ? item.filled : item.icon,
                        size: 24,
                        color: active
                            ? AppColors.primary
                            : AppColors.onSurfaceVariant,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
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
  const _NavItem({
    required this.icon,
    required this.filled,
    required this.label,
    required this.route,
  });
  final IconData icon;
  final IconData filled;
  final String label;
  final String route;
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

class _NavIconButton extends StatelessWidget {
  const _NavIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primaryContainer.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.primary, size: 22),
      ),
    );
  }
}
