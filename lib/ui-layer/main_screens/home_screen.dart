import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../landing_page/app_theme.dart';
import '../../main.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HOME SCREEN  —  route: /home
// The main dashboard shown after a successful login.
// Fetches user's displayName and username from Firestore, just like
// profile_screen.dart does.
// ─────────────────────────────────────────────────────────────────────────────

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _HomeScaffold();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCAFFOLD
// ─────────────────────────────────────────────────────────────────────────────

class _HomeScaffold extends StatefulWidget {
  const _HomeScaffold();

  @override
  State<_HomeScaffold> createState() => _HomeScaffoldState();
}

class _HomeScaffoldState extends State<_HomeScaffold> {
  bool _loading = true;
  String _fullName = '';
  String _username = '';
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }

    final authUser = FirebaseAuth.instance.currentUser!;
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data() ?? {};

    if (mounted) {
      setState(() {
        _fullName = data['fullName'] as String? ?? '';
        _username = data['username'] as String? ?? '';
        _photoUrl = authUser.photoURL ?? data['photoUrl'] as String?;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: Stack(
        children: [
          // ── Decorative blobs ───────────────────────────────────────────────
          Positioned(
            top: -60,
            left: -80,
            child: _Blob(
                size: 340,
                color: AppColors.secondaryFixedDim.withOpacity(0.20)),
          ),
          Positioned(
            bottom: 180,
            right: -100,
            child: _Blob(
                size: 300,
                color: AppColors.tertiaryContainer.withOpacity(0.22)),
          ),

          // ── Main content ──────────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _HomeTopBar(photoUrl: _photoUrl),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 2,
                          ),
                        )
                      : _HomeBody(
                          fullName: _fullName,
                          username: _username,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const _HomeBottomNavBar(activeIndex: 0),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOP BAR
// ─────────────────────────────────────────────────────────────────────────────

class _HomeTopBar extends StatelessWidget {
  const _HomeTopBar({this.photoUrl});
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
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
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryFixedDim],
                ).createShader(b),
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

              // Avatar → navigates to Profile
              GestureDetector(
                onTap: () => Navigator.of(context)
                    .pushReplacementNamed(AppRoutes.profile),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: AppColors.primaryContainer, width: 2),
                    color: AppColors.primaryContainer.withOpacity(0.25),
                    image: photoUrl != null
                        ? DecorationImage(
                            image: NetworkImage(photoUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: photoUrl == null
                      ? const Icon(Icons.person_rounded,
                          color: AppColors.primary, size: 20)
                      : null,
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
// BODY
// ─────────────────────────────────────────────────────────────────────────────

class _HomeBody extends StatelessWidget {
  const _HomeBody({required this.fullName, required this.username});
  final String fullName;
  final String username;

  // Derive first name for the greeting
  String get _firstName {
    if (fullName.trim().isEmpty) return 'there';
    return fullName.trim().split(' ').first;
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // ── Welcome ────────────────────────────────────────────────────
              _WelcomeSection(firstName: _firstName),
              const SizedBox(height: 24),

              // ── Streak card ────────────────────────────────────────────────
              const _StreakCard(),
              const SizedBox(height: 28),

              // ── Continue Studying ──────────────────────────────────────────
              _SectionHeader(
                title: 'Continue Studying',
                actionLabel: 'View all',
                onAction: () =>
                    Navigator.of(context).pushReplacementNamed(AppRoutes.decks),
              ),
              const SizedBox(height: 14),
              const _ContinueStudyingRow(),
              const SizedBox(height: 28),

              // ── Community Picks ────────────────────────────────────────────
              _SectionHeader(title: 'Community Picks'),
              const SizedBox(height: 14),
              const _CommunityPicksRow(),

              // ── Bottom clearance for nav bar ────────────────────────────────
              const SizedBox(height: 140),
            ]),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WELCOME SECTION
// ─────────────────────────────────────────────────────────────────────────────

class _WelcomeSection extends StatelessWidget {
  const _WelcomeSection({required this.firstName});
  final String firstName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome back, $firstName! 👋',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Ready to crush today\'s goals?',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STREAK CARD
// ─────────────────────────────────────────────────────────────────────────────

class _StreakCard extends StatelessWidget {
  const _StreakCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left: streak info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DAILY STREAK',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '14',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface,
                        letterSpacing: -2,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Days',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  "🔥 You're on fire! Keep it up.",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // Right: ring progress
          const _RingProgress(percent: 0.75, label: '75%'),
        ],
      ),
    );
  }
}

class _RingProgress extends StatelessWidget {
  const _RingProgress({required this.percent, required this.label});
  final double percent;
  final String label;

  @override
  Widget build(BuildContext context) {
    const size = 88.0;
    const stroke = 8.0;
    const radius = (size / 2) - stroke;
    final circumference = 2 * 3.14159 * radius;
    final dashOffset = circumference * (1 - percent);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: -1.5708, // -90 deg
            child: CustomPaint(
              size: const Size(size, size),
              painter: _RingPainter(
                circumference: circumference,
                dashOffset: dashOffset,
                stroke: stroke,
              ),
            ),
          ),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.circumference,
    required this.dashOffset,
    required this.stroke,
  });
  final double circumference;
  final double dashOffset;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - stroke / 2;

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = AppColors.primaryContainer.withOpacity(0.30)
        ..strokeWidth = stroke
        ..style = PaintingStyle.stroke,
    );

    // Progress arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      2 * 3.14159 * (1 - dashOffset / circumference),
      false,
      Paint()
        ..color = AppColors.primary
        ..strokeWidth = stroke
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
  });
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
            letterSpacing: -0.3,
          ),
        ),
        if (actionLabel != null && onAction != null)
          GestureDetector(
            onTap: onAction,
            child: Row(
              children: [
                Text(
                  actionLabel!,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.arrow_forward_rounded,
                    size: 15, color: AppColors.primary),
              ],
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONTINUE STUDYING ROW
// ─────────────────────────────────────────────────────────────────────────────

class _ContinueStudyingRow extends StatelessWidget {
  const _ContinueStudyingRow();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _StudyCard(
          icon: Icons.language_rounded,
          iconBg: AppColors.secondaryContainer,
          iconFg: AppColors.onSecondaryContainer,
          title: 'Spanish Verbs',
          subtitle: 'Last studied 2 hours ago',
          progress: 0.40,
          progressColor: AppColors.primary,
          cardCount: '40/100 Cards',
        ),
        const SizedBox(height: 12),
        _StudyCard(
          icon: Icons.science_rounded,
          iconBg: AppColors.tertiaryContainer,
          iconFg: AppColors.onTertiaryContainer,
          title: 'Organic Chemistry II',
          subtitle: 'Last studied yesterday',
          progress: 0.85,
          progressColor: AppColors.tertiary,
          cardCount: '170/200 Cards',
        ),
      ],
    );
  }
}

class _StudyCard extends StatelessWidget {
  const _StudyCard({
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.progressColor,
    required this.cardCount,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String title;
  final String subtitle;
  final double progress;
  final Color progressColor;
  final String cardCount;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed(AppRoutes.quiz),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.onSurface.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: iconFg, size: 22),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    cardCount,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.primaryContainer.withOpacity(0.25),
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                minHeight: 5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMMUNITY PICKS ROW  (horizontal scroll)
// ─────────────────────────────────────────────────────────────────────────────

class _CommunityPicksRow extends StatelessWidget {
  const _CommunityPicksRow();

  static const _picks = [
    _PickData(
      title: 'Data Structures 101',
      description: 'Master the fundamentals of trees, graphs, and hash tables.',
      rating: '4.9',
      creator: 'Alex Chen',
      tagColor: Color(0xFFC2E8FF),
      tagFg: Color(0xFF004D67),
      icon: Icons.developer_board_rounded,
    ),
    _PickData(
      title: 'World History: 19th Century',
      description: 'Key events, figures, and dates from the 1800s.',
      rating: '4.8',
      creator: 'Emma L.',
      tagColor: Color(0xFFFFE087),
      tagFg: Color(0xFF574500),
      icon: Icons.public_rounded,
    ),
    _PickData(
      title: 'Calculus Essentials',
      description: 'Derivatives, integrals, and limits explained simply.',
      rating: '4.7',
      creator: 'Raj M.',
      tagColor: Color(0xFF57FDC8),
      tagFg: Color(0xFF002116),
      icon: Icons.functions_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 210,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _picks.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) => _CommunityPickCard(pick: _picks[i]),
      ),
    );
  }
}

class _PickData {
  const _PickData({
    required this.title,
    required this.description,
    required this.rating,
    required this.creator,
    required this.tagColor,
    required this.tagFg,
    required this.icon,
  });
  final String title;
  final String description;
  final String rating;
  final String creator;
  final Color tagColor;
  final Color tagFg;
  final IconData icon;
}

class _CommunityPickCard extends StatelessWidget {
  const _CommunityPickCard({required this.pick});
  final _PickData pick;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 230,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon + rating
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: pick.tagColor.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(pick.icon, color: pick.tagFg, size: 22),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.tertiaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        size: 13, color: AppColors.tertiary),
                    const SizedBox(width: 3),
                    Text(
                      pick.rating,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onTertiaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            pick.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              pick.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: AppColors.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: pick.tagColor,
                ),
                child: Icon(Icons.person_rounded, size: 13, color: pick.tagFg),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  pick.creator,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {},
                child: const Icon(Icons.bookmark_add_outlined,
                    color: AppColors.primary, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM NAV BAR  (activeIndex: 0 = Home)
// ─────────────────────────────────────────────────────────────────────────────

class _HomeBottomNavBar extends StatelessWidget {
  const _HomeBottomNavBar({required this.activeIndex});
  final int activeIndex;

  static const _items = [
    _NavItem(icon: Icons.home_outlined, label: 'Home', route: '/home'),
    _NavItem(icon: Icons.layers_outlined, label: 'Decks', route: '/decks'),
    _NavItem(
        icon: Icons.analytics_outlined, label: 'Progress', route: '/progress'),
    _NavItem(
        icon: Icons.person_outline_rounded,
        label: 'Profile',
        route: '/profile'),
  ];

  static final Map<IconData, IconData> _filledIconMap = {
    Icons.home_outlined: Icons.home_rounded,
    Icons.layers_outlined: Icons.layers_rounded,
    Icons.analytics_outlined: Icons.analytics_rounded,
    Icons.person_outline_rounded: Icons.person_rounded,
  };

  IconData _filledIcon(IconData outline) => _filledIconMap[outline] ?? outline;

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
                        active ? _filledIcon(item.icon) : item.icon,
                        size: 24,
                        color:
                            active ? AppColors.primary : AppColors.onSurfaceVariant,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color:
                              active ? AppColors.primary : AppColors.onSurfaceVariant,
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
  const _NavItem(
      {required this.icon, required this.label, required this.route});
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
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

