import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../landing_page/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PROFILE SCREEN
// Displays the logged-in user's profile, deck stats, and navigation actions.
//
// ✏️  BACKEND NOTE:
// Static placeholder values are used throughout this screen.
// When you're ready to wire up real data:
//   • Replace the placeholder strings in _ProfileBody with a StreamBuilder
//     (or FutureBuilder) that reads from your Firestore 'users' collection.
//   • Implement _LogOutButton's onTap with AuthService().signOut() followed
//     by Navigator.pushNamedAndRemoveUntil(context, '/sign-in', …).
//   • The _StatsGrid card values ('12', '45', '3') should come from your
//     decks collection queries.
// ─────────────────────────────────────────────────────────────────────────────

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ProfileScaffold();
  }
}

class _ProfileScaffold extends StatelessWidget {
  const _ProfileScaffold();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: Stack(
        children: [
          // ── Decorative blobs ─────────────────────────────────────────────
          Positioned(
            top: 80,
            right: -80,
            child: _Blob(
              size: 320,
              color: AppColors.primaryContainer.withOpacity(0.35),
            ),
          ),
          Positioned(
            bottom: 120,
            left: -100,
            child: _Blob(
              size: 280,
              color: AppColors.secondaryContainer.withOpacity(0.28),
            ),
          ),

          // ── Main content ──────────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _ProfileTopBar(),
                const Expanded(
                  child: _ProfileBody(),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const _BottomNavBar(activeIndex: 3),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOP BAR
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileTopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background.withOpacity(0.75),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _NavIconButton(
            icon: Icons.menu_rounded,
            onTap: () {}, // Hook up drawer if needed
          ),
          Text(
            'Buddy Profile',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              letterSpacing: -0.2,
            ),
          ),
          _NavIconButton(
            icon: Icons.settings_outlined,
            onTap: () => Navigator.of(context).pushNamed('/account-settings'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROFILE BODY — uses placeholder data until backend wires up Firestore.
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileBody extends StatelessWidget {
  const _ProfileBody();

  @override
  Widget build(BuildContext context) {
    // ✏️  BACKEND: Replace these with values from your Firestore snapshot.
    const String fullName = 'Mnemo User';
    const String username = 'mnemo_user';
    const String bio = '';
    const String? photoUrl = null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Avatar + name ───────────────────────────────────────────
          const _ProfileHeader(
            fullName: fullName,
            username: username,
            bio: bio,
            photoUrl: photoUrl,
          ),
          const SizedBox(height: 32),

          // ── Deck stats grid ─────────────────────────────────────────
          _SectionLabel(
            left: 'Deck Statistics',
            right: 'LIFETIME IMPACT',
          ),
          const SizedBox(height: 12),
          const _StatsGrid(),
          const SizedBox(height: 32),

          // ── Action list ─────────────────────────────────────────────
          _ActionList(context: context),
          const SizedBox(height: 20),

          // ── Log out button ──────────────────────────────────────────
          const _LogOutButton(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROFILE HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.fullName,
    required this.username,
    required this.bio,
    this.photoUrl,
  });

  final String fullName;
  final String username;
  final String bio;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Avatar
        Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.25),
                    AppColors.primaryContainer.withOpacity(0.35),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.all(3),
              child: CircleAvatar(
                radius: 56,
                backgroundColor: AppColors.surfaceContainerLowest,
                backgroundImage:
                    photoUrl != null ? NetworkImage(photoUrl!) : null,
                child: photoUrl == null
                    ? Text(
                        fullName.isNotEmpty
                            ? fullName[0].toUpperCase()
                            : 'M',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      )
                    : null,
              ),
            ),
            // Edit button — navigates to Account Settings
            Positioned(
              bottom: 2,
              right: 2,
              child: GestureDetector(
                onTap: () =>
                    Navigator.of(context).pushNamed('/account-settings'),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.surfaceContainerLowest,
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Name
        Text(
          fullName,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 4),

        // Username
        Text(
          '@$username',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
            letterSpacing: 1.2,
          ),
        ),

        // Bio (only shown if set)
        if (bio.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            bio,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              height: 1.6,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATS GRID
// ✏️  BACKEND: Replace the hard-coded values with real counts from your
// decks collection (built, saved, drafts queries).
// ─────────────────────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  const _StatsGrid();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            value: '12',
            label: 'Built',
            accentColor: AppColors.primaryContainer,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            value: '45',
            label: 'Saved',
            accentColor: AppColors.secondaryContainer,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            value: '3',
            label: 'Drafts',
            accentColor: AppColors.tertiaryContainer,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.accentColor,
  });

  final String value;
  final String label;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          bottom: BorderSide(color: accentColor, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: AppColors.onSurface,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.outline,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTION LIST
// ─────────────────────────────────────────────────────────────────────────────

class _ActionList extends StatelessWidget {
  const _ActionList({required this.context});
  final BuildContext context;

  @override
  Widget build(BuildContext outerContext) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          _ActionTile(
            icon: Icons.person_outline_rounded,
            iconBg: AppColors.primaryContainer.withOpacity(0.3),
            iconColor: AppColors.primary,
            label: 'Account Settings',
            onTap: () =>
                Navigator.of(outerContext).pushNamed('/account-settings'),
          ),
          _ActionTile(
            icon: Icons.notifications_active_outlined,
            iconBg: AppColors.secondaryContainer.withOpacity(0.3),
            iconColor: AppColors.secondary,
            label: 'Notification Preferences',
            onTap: () {}, // ✏️  BACKEND: Add route when screen is built
          ),
          _ActionTile(
            icon: Icons.quiz_outlined,
            iconBg: AppColors.tertiaryContainer.withOpacity(0.3),
            iconColor: AppColors.tertiary,
            label: 'Help & Support',
            onTap: () {}, // ✏️  BACKEND: Add route when screen is built
            showDivider: false,
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.showDivider = true,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: iconBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: iconColor, size: 22),
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
                    color: AppColors.outline,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 72,
            endIndent: 16,
            color: AppColors.outlineVariant.withOpacity(0.3),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOG OUT BUTTON
// ✏️  BACKEND: Replace the onTap body with:
//   await AuthService().signOut();
//   Navigator.of(context).pushNamedAndRemoveUntil('/sign-in', (r) => false);
// ─────────────────────────────────────────────────────────────────────────────

class _LogOutButton extends StatelessWidget {
  const _LogOutButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // ✏️  BACKEND: wire up sign-out logic here
        },
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: AppColors.errorContainer.withOpacity(0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.errorContainer.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
              const SizedBox(width: 10),
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
// Shared across Profile + Account Settings screens.
// activeIndex: 0=Home, 1=Decks, 2=Quiz, 3=Stats (Profile uses 3 for now)
//
// ✏️  FUTURE HOMEPAGE NOTE:
// When your HomeScreen is ready, update ProfileScreen's bottomNavigationBar
// to set activeIndex: 0 (or whichever tab Profile should live under).
// ─────────────────────────────────────────────────────────────────────────────

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({required this.activeIndex});
  final int activeIndex;

  static const _items = [
    _NavItem(icon: Icons.home_outlined, label: 'Home', route: '/home'),
    _NavItem(icon: Icons.layers_outlined, label: 'Decks', route: '/decks'),
    _NavItem(icon: Icons.quiz_outlined, label: 'Quiz', route: '/quiz'),
    _NavItem(icon: Icons.analytics_outlined, label: 'Stats', route: '/stats'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.88),
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
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
                        active ? _filledIcon(item.icon) : item.icon,
                        size: 24,
                        color: active
                            ? AppColors.primary
                            : Colors.grey.shade400,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: active
                              ? AppColors.primary
                              : Colors.grey.shade400,
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

  static final Map<IconData, IconData> _filledIconMap = {
    Icons.home_outlined: Icons.home_rounded,
    Icons.layers_outlined: Icons.layers_rounded,
    Icons.quiz_outlined: Icons.quiz_rounded,
    Icons.analytics_outlined: Icons.analytics_rounded,
  };

  IconData _filledIcon(IconData outline) => _filledIconMap[outline] ?? outline;
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
  });
  final IconData icon;
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
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.left, required this.right});
  final String left;
  final String right;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          left,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        Text(
          right,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.outline,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}