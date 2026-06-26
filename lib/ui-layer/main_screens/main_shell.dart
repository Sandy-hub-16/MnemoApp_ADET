import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../landing_page/app_theme.dart';
import 'home_screen.dart';
import 'deck/deck_screen.dart';
import 'progress_screen.dart';
import 'profile_screen.dart';
import '../social/deck_discovery_screen.dart';

/// MainShell wraps the 5 main screens with a persistent top bar and bottom
/// navbar. Both bars live here — outside the PageView — so neither reloads
/// or re-animates when switching tabs; only the section badge text/icon and
/// color swap to match the active screen.
class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
    _pageController.jumpToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: _PersistentTopBar(sectionIndex: _currentIndex),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: const [
                HomeScreen(),
                DeckHubScreen(),
                DeckDiscoveryScreen(),
                ProgressScreen(),
                ProfileScreen(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _PersistentBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PERSISTENT TOP BAR
// One frosted-glass bar shared by all 5 main screens. Only the section
// badge (icon + label + color) changes per tab — no bell, no connectivity
// indicator, no filter button, no avatar. This bar is purely a header now.
// ─────────────────────────────────────────────────────────────────────────────

class _PersistentTopBar extends StatelessWidget {
  const _PersistentTopBar({required this.sectionIndex});

  final int sectionIndex;

  static const _sections = [
    _TopBarSection(
        label: 'HOME', icon: Icons.home_rounded, color: AppColors.primary),
    _TopBarSection(
        label: 'LIBRARY',
        icon: Icons.layers_rounded,
        color: AppColors.tertiary),
    _TopBarSection(
        label: 'DISCOVER',
        icon: Icons.explore_rounded,
        color: AppColors.primary),
    _TopBarSection(
        label: 'PROGRESS',
        icon: Icons.analytics_rounded,
        color: AppColors.secondary),
    _TopBarSection(
        label: 'PROFILE',
        icon: Icons.person_rounded,
        color: AppColors.secondary),
  ];

  @override
  Widget build(BuildContext context) {
    final section = _sections[sectionIndex];

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          color: AppColors.background.withOpacity(0.75),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Brand
              Row(
                children: [
                  const Icon(
                    Icons.bubble_chart_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  ShaderMask(
                    shaderCallback: (b) => const LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary],
                    ).createShader(b),
                    child: Text(
                      'Mnemo',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ],
              ),

              // Unified section label — plain text + icon, deliberately
              // NOT styled like a button/chip (no fill, no border, no pill
              // shape) so it can't be mistaken for a tappable element.
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Row(
                  key: ValueKey(section.label),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(section.icon, color: section.color, size: 15),
                    const SizedBox(width: 6),
                    Text(
                      section.label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: section.color,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBarSection {
  const _TopBarSection({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}

class _PersistentBottomNavBar extends StatelessWidget {
  const _PersistentBottomNavBar({
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = [
    _NavItem(
      icon: Icons.home_outlined,
      filled: Icons.home_rounded,
      label: 'Home',
    ),
    _NavItem(
      icon: Icons.layers_outlined,
      filled: Icons.layers_rounded,
      label: 'Decks',
    ),
    _NavItem(
      icon: Icons.explore_outlined,
      filled: Icons.explore_rounded,
      label: 'Discover',
    ),
    _NavItem(
      icon: Icons.analytics_outlined,
      filled: Icons.analytics_rounded,
      label: 'Progress',
    ),
    _NavItem(
      icon: Icons.person_outline_rounded,
      filled: Icons.person_rounded,
      label: 'Profile',
    ),
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
            children: List.generate(_items.length, (index) {
              final item = _items[index];
              final active = index == currentIndex;

              return GestureDetector(
                onTap: () => onTap(index),
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
            }),
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
  });

  final IconData icon;
  final IconData filled;
  final String label;
}
