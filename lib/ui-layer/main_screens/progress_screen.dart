import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../landing_page/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PROGRESS SCREEN  —  route: /progress
// Displays mastery overview, study streak, subject breakdown & weak spots.
//
// 🎨 FRONTEND NOTE:
// All stats (mastery %, streak, subject scores, weak spots) are hardcoded
// placeholders. Replace with Firestore reads in _ProgressBodyState when
// the backend is ready. Each data class (_SubjectStat, _WeakSpot) is
// intentionally thin so you can swap in Firestore models without touching
// the widget tree.
// ─────────────────────────────────────────────────────────────────────────────

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ProgressScaffold();
  }
}

class _ProgressScaffold extends StatefulWidget {
  const _ProgressScaffold();

  @override
  State<_ProgressScaffold> createState() => _ProgressScaffoldState();
}

class _ProgressScaffoldState extends State<_ProgressScaffold> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    // Simulate brief loading delay for content initialization
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: Stack(
        children: [
          // ── Decorative blobs ────────────────────────────────────────────────
          Positioned(
            top: -40,
            right: -80,
            child: _Blob(
              size: 340,
              color: AppColors.secondaryContainer.withOpacity(0.22),
            ),
          ),
          Positioned(
            bottom: 200,
            left: -100,
            child: _Blob(
              size: 280,
              color: AppColors.tertiaryContainer.withOpacity(0.25),
            ),
          ),

          // ── Main content ──────────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _ProgressTopBar(),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 2,
                          ),
                        )
                      : CustomScrollView(
                          physics: const BouncingScrollPhysics(),
                          slivers: [
                              SliverPadding(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 24, 20, 0),
                                sliver: SliverList(
                                  delegate: SliverChildListDelegate([
                                    // ── Section heading ──────────────────────────────
                                    Text(
                                      'Your Progress',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.onSurface,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 20),

                                    // ── Row 1: Mastery + Streak ───────────────────────
                                    IntrinsicHeight(
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Expanded(
                                            flex: 6,
                                            child: _MasteryCard(
                                              masteryPercent: 0.72,
                                              masteredTerms: 342,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            flex: 4,
                                            child: _StreakCard(
                                              streakDays: 14,
                                              personalBest: 21,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                    // ── Row 2: Subject Breakdown + Weak Spots ─────────
                                    _SubjectBreakdownCard(
                                        subjects: _placeholderSubjects),
                                    const SizedBox(height: 12),
                                    _WeakSpotsCard(
                                        spots: _placeholderWeakSpots),

                                    // ── Bottom padding for nav ────────────────────────
                                    const SizedBox(height: 140),
                                  ]),
                                ),
                              ),
                            ]),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const _ProgressBottomNavBar(activeIndex: 3),
    );
  }

  // ── Placeholder data — replace with real Firestore models ────────────────

  static const _placeholderSubjects = [
    _SubjectStat(label: 'Biology', percent: 0.85, color: AppColors.primary),
    _SubjectStat(label: 'History', percent: 0.65, color: AppColors.secondary),
    _SubjectStat(label: 'Physics', percent: 0.40, color: AppColors.tertiary),
    _SubjectStat(
        label: 'Spanish', percent: 0.92, color: AppColors.primaryFixedDim),
  ];

  static const _placeholderWeakSpots = [
    _WeakSpot(
      topic: 'Thermodynamics',
      subject: 'Physics',
      termCount: 12,
    ),
    _WeakSpot(
      topic: 'Cellular Respiration',
      subject: 'Biology',
      termCount: 5,
    ),
    _WeakSpot(
      topic: 'Irregular Verbs (Preterite)',
      subject: 'Spanish',
      termCount: 8,
    ),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// TOP BAR
// ─────────────────────────────────────────────────────────────────────────────

class _ProgressTopBar extends StatelessWidget {
  const _ProgressTopBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background.withOpacity(0.75),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.bubble_chart_rounded,
                color: AppColors.primary,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'Kindred Study',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          _NavIconButton(
            icon: Icons.tune_rounded,
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MASTERY CARD  —  circular chart + CTA
// ─────────────────────────────────────────────────────────────────────────────

class _MasteryCard extends StatelessWidget {
  const _MasteryCard({
    required this.masteryPercent,
    required this.masteredTerms,
  });

  final double masteryPercent; // 0.0 – 1.0
  final int masteredTerms;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Ring + text row ─────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Circular mastery chart
              SizedBox(
                width: 100,
                height: 100,
                child: CustomPaint(
                  painter: _MasteryRingPainter(masteryPercent),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(masteryPercent * 100).round()}%',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onSurface,
                            height: 1,
                          ),
                        ),
                        Text(
                          'MASTERY',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurfaceVariant,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Keep it up!',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'You\'ve mastered $masteredTerms terms across all your decks.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // CTA button
          GestureDetector(
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryContainer],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Text(
                'Review Weak Spots',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STREAK CARD
// ─────────────────────────────────────────────────────────────────────────────

class _StreakCard extends StatelessWidget {
  const _StreakCard({
    required this.streakDays,
    required this.personalBest,
  });

  final int streakDays;
  final int personalBest;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.tertiaryContainer.withOpacity(0.3),
            AppColors.background,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            color: AppColors.tertiary,
            size: 42,
          ),
          const SizedBox(height: 4),
          Text(
            '$streakDays',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              color: AppColors.onSurface,
              height: 1,
            ),
          ),
          Text(
            'Day Streak',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Best: $personalBest days',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.outline,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUBJECT BREAKDOWN CARD
// ─────────────────────────────────────────────────────────────────────────────

class _SubjectBreakdownCard extends StatelessWidget {
  const _SubjectBreakdownCard({required this.subjects});
  final List<_SubjectStat> subjects;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Subject Breakdown',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.onSurface,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 18),
          ...subjects.map((s) => _SubjectRow(stat: s)),
        ],
      ),
    );
  }
}

class _SubjectRow extends StatelessWidget {
  const _SubjectRow({required this.stat});
  final _SubjectStat stat;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                stat.label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
              Text(
                '${(stat.percent * 100).round()}%',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: stat.percent,
              minHeight: 10,
              backgroundColor: AppColors.outlineVariant.withOpacity(0.25),
              valueColor: AlwaysStoppedAnimation<Color>(stat.color),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WEAK SPOTS CARD
// ─────────────────────────────────────────────────────────────────────────────

class _WeakSpotsCard extends StatelessWidget {
  const _WeakSpotsCard({required this.spots});
  final List<_WeakSpot> spots;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(color: AppColors.surfaceContainerLow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline_rounded,
                  color: AppColors.error, size: 20),
              const SizedBox(width: 8),
              Text(
                'Weak Spots',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...spots.map((s) => _WeakSpotTile(spot: s)),
        ],
      ),
    );
  }
}

class _WeakSpotTile extends StatelessWidget {
  const _WeakSpotTile({required this.spot});
  final _WeakSpot spot;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.outlineVariant.withOpacity(0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.onSurface.withOpacity(0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        spot.topic,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${spot.subject} · ${spot.termCount} terms struggling',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: AppColors.outline, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MASTERY RING  —  CustomPainter arc
// ─────────────────────────────────────────────────────────────────────────────

class _MasteryRingPainter extends CustomPainter {
  const _MasteryRingPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 6;
    const strokeW = 9.0;

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = AppColors.outlineVariant.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW,
    );

    // Progress arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // start at top
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_MasteryRingPainter old) => old.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODELS  (plain, const-friendly, easy to swap with Firestore)
// ─────────────────────────────────────────────────────────────────────────────

class _SubjectStat {
  const _SubjectStat({
    required this.label,
    required this.percent,
    required this.color,
  });
  final String label;
  final double percent;
  final Color color;
}

class _WeakSpot {
  const _WeakSpot({
    required this.topic,
    required this.subject,
    required this.termCount,
  });
  final String topic;
  final String subject;
  final int termCount;
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM NAV BAR  —  shared tab bar (Progress is activeIndex 2)
// ─────────────────────────────────────────────────────────────────────────────

class _ProgressBottomNavBar extends StatelessWidget {
  const _ProgressBottomNavBar({required this.activeIndex});
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

BoxDecoration _cardDecoration({Color? color, Gradient? gradient}) {
  return BoxDecoration(
    color: color ?? AppColors.surfaceContainerLowest,
    gradient: gradient,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: AppColors.onSurface.withOpacity(0.04),
        blurRadius: 24,
        offset: const Offset(0, 8),
      ),
    ],
  );
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
