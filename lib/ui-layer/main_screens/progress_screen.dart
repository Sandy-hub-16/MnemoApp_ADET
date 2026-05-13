import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../landing_page/app_theme.dart';
import '../../business-layer/services/progress_service.dart';

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
  ProgressDashboard _dashboard = ProgressDashboard.empty();
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    try {
      final dashboard = await ProgressService.loadDashboard();
      if (!mounted) return;
      setState(() {
        _dashboard = dashboard;
        _errorMessage = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dashboard = ProgressDashboard.empty();
        _errorMessage = 'Could not load progress yet.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjectStats = _subjectStats(_dashboard);
    final weakSpots = _weakSpotStats(_dashboard);
    final forgottenCards = _forgottenCardStats(_dashboard);

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
                                      'Track Your Journey',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.onSurface,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Monitor your learning progress and achievements',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    if (_errorMessage != null) ...[
                                      _ProgressErrorBanner(
                                        message: _errorMessage!,
                                        onRetry: () {
                                          setState(() => _loading = true);
                                          _loadProgress();
                                        },
                                      ),
                                      const SizedBox(height: 12),
                                    ],

                                    // ── HERO STATS (Always visible) ──────────────────────
                                    _HeroStatsSection(
                                      dashboard: _dashboard,
                                    ),

                                    // ── DETAILED BREAKDOWN (Only if has data) ────────────
                                    if (_dashboard.deckSummaries.isNotEmpty ||
                                        _dashboard.categories.isNotEmpty) ...[
                                      const SizedBox(height: 20),
                                      _DetailedBreakdownSection(
                                        dashboard: _dashboard,
                                        subjectStats: subjectStats,
                                      ),
                                    ],

                                    // ── WEAK SPOTS (Only if has data) ────────────────────
                                    if (weakSpots.isNotEmpty) ...[
                                      const SizedBox(height: 20),
                                      _WeakSpotsCard(spots: weakSpots),
                                    ],

                                    // ── FORGOTTEN CARDS (Only if has data) ───────────────
                                    if (forgottenCards.isNotEmpty) ...[
                                      const SizedBox(height: 20),
                                      _ForgottenCardsCard(cards: forgottenCards),
                                    ],

                                    // ── EMPTY STATE (Only if no data at all) ─────────────
                                    if (!_dashboard.hasAttempts) ...[
                                      _EmptyProgressState(),
                                    ],

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
    );
  }

  // ── Firestore dashboard adapters ─────────────────────────────────────────

  List<_SubjectStat> _subjectStats(ProgressDashboard dashboard) {
    return dashboard.categories.asMap().entries.map((entry) {
      final summary = entry.value;
      return _SubjectStat(
        label: summary.label,
        percent: summary.mastery,
        color: _chartColor(entry.key),
        reviewedCards: summary.answeredTotal,
        attemptCount: summary.attemptCount,
      );
    }).toList();
  }

  List<_WeakSpot> _weakSpotStats(ProgressDashboard dashboard) {
    return dashboard.weakSpots.map((spot) {
      return _WeakSpot(
        topic: spot.question,
        subject: spot.category,
        deckTitle: spot.deckTitle,
        termCount: spot.missCount,
      );
    }).toList();
  }

  List<_ForgottenCard> _forgottenCardStats(ProgressDashboard dashboard) {
    return dashboard.forgottenCards.map((card) {
      return _ForgottenCard(
        topic: card.question,
        subject: card.category,
        deckTitle: card.deckTitle,
        failureCount: card.failureCount,
      );
    }).toList();
  }

  Color _chartColor(int index) {
    const colors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.tertiary,
      AppColors.primaryFixedDim,
      Color(0xFF9B5DE5),
      Color(0xFFE85D75),
    ];
    return colors[index % colors.length];
  }
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
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                ).createShader(bounds),
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
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'PROGRESS',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          _NavIconButton(
            icon: Icons.tune_rounded,
            onTap: () => _showProgressOptions(context),
          ),
        ],
      ),
    );
  }

  void _showProgressOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ProgressOptionsSheet(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROGRESS OPTIONS SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _ProgressOptionsSheet extends StatelessWidget {
  const _ProgressOptionsSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.outlineVariant,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.settings_rounded,
                      color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Progress Options',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _ProgressOption(
            icon: Icons.refresh_rounded,
            label: 'Refresh Progress',
            subtitle: 'Reload your latest statistics',
            color: AppColors.primary,
            onTap: () {
              Navigator.pop(context);
              final scaffoldState = context.findAncestorStateOfType<_ProgressScaffoldState>();
              if (scaffoldState != null) {
                scaffoldState._loadProgress();
              }
            },
          ),
          _ProgressOption(
            icon: Icons.file_download_outlined,
            label: 'Export Progress Report',
            subtitle: 'Download your study statistics',
            color: AppColors.secondary,
            onTap: () {
              Navigator.pop(context);
              final scaffoldState = context.findAncestorStateOfType<_ProgressScaffoldState>();
              if (scaffoldState != null) {
                _showExportDialog(context, scaffoldState._dashboard);
              }
            },
          ),
          _ProgressOption(
            icon: Icons.notifications_outlined,
            label: 'Study Reminders',
            subtitle: 'Set daily study notifications',
            color: AppColors.tertiary,
            onTap: () {
              Navigator.pop(context);
              _showStudyRemindersDialog(context);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showExportDialog(BuildContext context, ProgressDashboard dashboard) {
    final report = _generateProgressReport(dashboard);
    
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: AppColors.surfaceContainerLowest,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.secondaryContainer.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.file_download_outlined, color: AppColors.secondary, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'Progress Report',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: SelectableText(
            report,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              color: AppColors.onSurface,
              height: 1.5,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _generateProgressReport(ProgressDashboard dashboard) {
    final buffer = StringBuffer();
    final now = DateTime.now();
    
    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln('       KINDRED STUDY PROGRESS REPORT');
    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln('Generated: ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}');
    buffer.writeln();
    
    buffer.writeln('OVERALL STATISTICS');
    buffer.writeln('───────────────────────────────────────');
    buffer.writeln('Mastery Score: ${(dashboard.overallMastery * 100).toStringAsFixed(1)}%');
    buffer.writeln('Correct Answers: ${dashboard.correctAnswers}/${dashboard.reviewedAnswers}');
    buffer.writeln('Total Quiz Attempts: ${dashboard.totalAttempts}');
    buffer.writeln('Current Streak: ${dashboard.currentStreakDays} days');
    buffer.writeln('Best Streak: ${dashboard.personalBestStreakDays} days');
    buffer.writeln();
    
    if (dashboard.categories.isNotEmpty) {
      buffer.writeln('CATEGORY BREAKDOWN');
      buffer.writeln('───────────────────────────────────────');
      for (final cat in dashboard.categories) {
        buffer.writeln('${cat.label}:');
        buffer.writeln('  Mastery: ${(cat.mastery * 100).toStringAsFixed(1)}%');
        buffer.writeln('  Cards Reviewed: ${cat.answeredTotal}');
        buffer.writeln('  Quiz Attempts: ${cat.attemptCount}');
        buffer.writeln();
      }
    }
    
    if (dashboard.weakSpots.isNotEmpty) {
      buffer.writeln('WEAK SPOTS (Top ${dashboard.weakSpots.length})');
      buffer.writeln('───────────────────────────────────────');
      for (var i = 0; i < dashboard.weakSpots.length; i++) {
        final spot = dashboard.weakSpots[i];
        buffer.writeln('${i + 1}. ${spot.question}');
        buffer.writeln('   ${spot.category} · ${spot.missCount} misses');
      }
      buffer.writeln();
    }
    
    if (dashboard.forgottenCards.isNotEmpty) {
      buffer.writeln('FORGOTTEN CARDS (Top ${dashboard.forgottenCards.length})');
      buffer.writeln('───────────────────────────────────────');
      for (var i = 0; i < dashboard.forgottenCards.length; i++) {
        final card = dashboard.forgottenCards[i];
        buffer.writeln('${i + 1}. ${card.question}');
        buffer.writeln('   ${card.category} · ${card.failureCount} failures');
      }
      buffer.writeln();
    }
    
    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln('End of Report');
    
    return buffer.toString();
  }

  void _showStudyRemindersDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const _StudyRemindersDialog(),
    );
  }
}

class _ProgressOption extends StatelessWidget {
  const _ProgressOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          color: AppColors.onSurfaceVariant,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STUDY REMINDERS DIALOG
// ─────────────────────────────────────────────────────────────────────────────

class _StudyRemindersDialog extends StatefulWidget {
  const _StudyRemindersDialog();

  @override
  State<_StudyRemindersDialog> createState() => _StudyRemindersDialogState();
}

class _StudyRemindersDialogState extends State<_StudyRemindersDialog> {
  bool _enabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 19, minute: 0);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: AppColors.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.tertiaryContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.notifications_outlined,
                      color: AppColors.tertiary, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Study Reminders',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onSurface,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Daily study notifications',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Enable Reminders',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Get notified to study daily',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: _enabled,
                        onChanged: (value) => setState(() => _enabled = value),
                        activeColor: AppColors.primary,
                      ),
                    ],
                  ),
                  if (_enabled) ...[
                    const SizedBox(height: 16),
                    Divider(color: AppColors.outlineVariant.withOpacity(0.3)),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: _reminderTime,
                        );
                        if (time != null) {
                          setState(() => _reminderTime = time);
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.outlineVariant),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.access_time_rounded,
                                    color: AppColors.primary, size: 20),
                                const SizedBox(width: 12),
                                Text(
                                  'Reminder Time',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.onSurface,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              _reminderTime.format(context),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.20),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check_rounded,
                                    color: Colors.white, size: 16),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _enabled
                                      ? 'Reminder set for ${_reminderTime.format(context)}'
                                      : 'Reminders disabled',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: const Color(0xFF16A34A),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      'Save Settings',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO STATS SECTION - Big, bold numbers at the top
// ─────────────────────────────────────────────────────────────────────────────

class _HeroStatsSection extends StatelessWidget {
  const _HeroStatsSection({required this.dashboard});
  final ProgressDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final accuracyRate = dashboard.reviewedAnswers == 0
        ? 0.0
        : dashboard.correctAnswers / dashboard.reviewedAnswers;
    
    // Calculate overall first try accuracy
    final totalFirstTryCards = dashboard.deckSummaries.fold<double>(
      0.0,
      (sum, deck) => sum + ((deck.firstTryAccuracy ?? 0.0) * deck.answeredTotal),
    );
    final overallFirstTryAccuracy = dashboard.reviewedAnswers == 0
        ? 0.0
        : totalFirstTryCards / dashboard.reviewedAnswers;
    
    // Calculate overall average repetitions
    final totalRepetitions = dashboard.deckSummaries.fold<double>(
      0.0,
      (sum, deck) => sum + ((deck.averageRepetitions ?? 0.0) * deck.answeredTotal),
    );
    final overallAvgRepetitions = dashboard.reviewedAnswers == 0
        ? 0.0
        : totalRepetitions / dashboard.reviewedAnswers;
    
    // Calculate total skipped cards
    final totalSkipped = dashboard.deckSummaries.fold<int>(
      0,
      (sum, deck) => sum + (deck.totalSkipped ?? 0),
    );
    
    // Calculate mastery test stats
    final decksWithMastery = dashboard.deckSummaries
        .where((d) => d.masteryScore != null && d.masteryScore! > 0)
        .toList();
    final avgMasteryScore = decksWithMastery.isEmpty
        ? 0.0
        : decksWithMastery.fold<int>(0, (sum, d) => sum + d.masteryScore!) / decksWithMastery.length;

    return Column(
      children: [
        // ── HERO: Mastery + Streak ──────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: _cardDecoration(),
          child: Column(
            children: [
              Row(
                children: [
                  // Mastery Ring
                  SizedBox(
                    width: 90,
                    height: 90,
                    child: CustomPaint(
                      painter: _MasteryRingPainter(dashboard.overallMastery),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${(dashboard.overallMastery * 100).round()}%',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: AppColors.onSurface,
                                height: 1,
                              ),
                            ),
                            const SizedBox(height: 2),
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
                  const SizedBox(width: 20),
                  // Stats column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dashboard.hasAttempts ? 'Keep Going!' : 'Start Learning',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onSurface,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (dashboard.hasAttempts) ...[
                          _CompactStatRow(
                            icon: Icons.check_circle_rounded,
                            label: '${dashboard.correctAnswers}/${dashboard.reviewedAnswers} correct',
                            color: AppColors.primary,
                          ),
                          const SizedBox(height: 4),
                          _CompactStatRow(
                            icon: Icons.local_fire_department_rounded,
                            label: '${dashboard.currentStreakDays} day streak',
                            color: AppColors.tertiary,
                          ),
                        ] else ...[
                          Text(
                            'Complete your first quiz to start tracking progress',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: AppColors.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (dashboard.hasAttempts) ...[
                const SizedBox(height: 16),
                Divider(color: AppColors.outlineVariant.withOpacity(0.3), height: 1),
                const SizedBox(height: 16),
                // Quick stats row
                Row(
                  children: [
                    Expanded(
                      child: _InlineStatItem(
                        icon: Icons.quiz_rounded,
                        value: '${dashboard.totalAttempts}',
                        label: 'Quizzes',
                        color: AppColors.primary,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 32,
                      color: AppColors.outlineVariant.withOpacity(0.3),
                    ),
                    Expanded(
                      child: _InlineStatItem(
                        icon: Icons.percent_rounded,
                        value: '${(accuracyRate * 100).round()}%',
                        label: 'Accuracy',
                        color: AppColors.secondary,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 32,
                      color: AppColors.outlineVariant.withOpacity(0.3),
                    ),
                    Expanded(
                      child: _InlineStatItem(
                        icon: Icons.layers_rounded,
                        value: '${dashboard.deckSummaries.length}',
                        label: 'Decks',
                        color: AppColors.tertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        
        // ── LEARNING INSIGHTS ────────────────────────────────────────────
        if (dashboard.hasAttempts) ...[
          const SizedBox(height: 16),
          _SectionHeader(
            icon: Icons.insights_rounded,
            title: 'Learning Insights',
            subtitle: 'Your strengths and areas to improve',
          ),
          const SizedBox(height: 10),
          _InsightsCard(
            stats: [
              _InsightStat(
                icon: Icons.bolt_rounded,
                label: 'First Try Success',
                value: '${(overallFirstTryAccuracy * 100).round()}%',
                color: AppColors.tertiary,
                insight: overallFirstTryAccuracy >= 0.7 ? 'Strong!' : 'Room to grow',
              ),
              _InsightStat(
                icon: Icons.repeat_rounded,
                label: 'Avg. Repetitions',
                value: overallAvgRepetitions.toStringAsFixed(1),
                color: AppColors.secondary,
                insight: overallAvgRepetitions <= 2.0 ? 'Efficient' : 'Keep practicing',
              ),
              _InsightStat(
                icon: Icons.skip_next_rounded,
                label: 'Cards Skipped',
                value: '$totalSkipped',
                color: AppColors.error,
                insight: totalSkipped == 0 ? 'Perfect!' : 'Try not to skip',
              ),
            ],
          ),
        ],
        
        // ── MASTERY TEST PERFORMANCE ─────────────────────────────────────
        if (decksWithMastery.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SectionHeader(
            icon: Icons.emoji_events_rounded,
            title: 'Mastery Tests',
            subtitle: 'Your achievement showcase',
          ),
          const SizedBox(height: 10),
          _MasteryTestCard(
            avgScore: avgMasteryScore,
            decksTested: decksWithMastery.length,
            perfectScores: decksWithMastery.where((d) => d.masteryScore == 100).length,
          ),
        ],
      ],
    );
  }
}

class _CompactStatRow extends StatelessWidget {
  const _CompactStatRow({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INLINE STAT ITEM - For divider-separated stats
// ─────────────────────────────────────────────────────────────────────────────

class _InlineStatItem extends StatelessWidget {
  const _InlineStatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
            height: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION HEADER - For major sections
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INSIGHTS CARD - Learning insights with actionable feedback
// ─────────────────────────────────────────────────────────────────────────────

class _InsightsCard extends StatelessWidget {
  const _InsightsCard({required this.stats});
  final List<_InsightStat> stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        children: stats.asMap().entries.map((entry) {
          final index = entry.key;
          final stat = entry.value;
          return Column(
            children: [
              if (index > 0) ...[
                const SizedBox(height: 12),
                Divider(color: AppColors.outlineVariant.withOpacity(0.3), height: 1),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: stat.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(stat.icon, color: stat.color, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stat.label,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          stat.insight,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    stat.value,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: stat.color,
                    ),
                  ),
                ],
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _InsightStat {
  const _InsightStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.insight,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String insight;
}

// ─────────────────────────────────────────────────────────────────────────────
// MASTERY TEST CARD - Achievement showcase
// ─────────────────────────────────────────────────────────────────────────────

class _MasteryTestCard extends StatelessWidget {
  const _MasteryTestCard({
    required this.avgScore,
    required this.decksTested,
    required this.perfectScores,
  });

  final double avgScore;
  final int decksTested;
  final int perfectScores;

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
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.tertiary.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.emoji_events_rounded,
              color: AppColors.tertiary,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${avgScore.round()}% Average',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.onSurface,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$decksTested deck${decksTested == 1 ? '' : 's'} tested · $perfectScores perfect score${perfectScores == 1 ? '' : 's'}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceVariant,
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

class _EmptyProgressState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_graph_rounded,
              size: 48,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Start Your Learning Journey',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete your first quiz to see detailed progress statistics and track your learning journey.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: AppColors.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pushReplacementNamed('/decks'),
            icon: const Icon(Icons.play_arrow_rounded, size: 20),
            label: Text(
              'Browse Decks',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DETAILED BREAKDOWN SECTION (Tabbed: By Deck / By Category)
// ─────────────────────────────────────────────────────────────────────────────

class _DetailedBreakdownSection extends StatefulWidget {
  const _DetailedBreakdownSection({
    required this.dashboard,
    required this.subjectStats,
  });

  final ProgressDashboard dashboard;
  final List<_SubjectStat> subjectStats;

  @override
  State<_DetailedBreakdownSection> createState() =>
      _DetailedBreakdownSectionState();
}

class _DetailedBreakdownSectionState
    extends State<_DetailedBreakdownSection> {
  int _selectedTab = 0;
  String _sortBy = 'lowest'; // Default: lowest score first
  String _viewMode = 'current'; // 'current', 'best', 'average'

  List<DeckProgressSummary> _sortDecks(List<DeckProgressSummary> decks) {
    final sorted = List<DeckProgressSummary>.from(decks);
    switch (_sortBy) {
      case 'lowest':
        sorted.sort((a, b) => a.getMetricByViewMode(_viewMode).compareTo(b.getMetricByViewMode(_viewMode)));
        break;
      case 'highest':
        sorted.sort((a, b) => b.getMetricByViewMode(_viewMode).compareTo(a.getMetricByViewMode(_viewMode)));
        break;
      case 'recent':
        sorted.sort((a, b) {
          final aDate = a.lastStudiedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = b.lastStudiedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        });
        break;
      case 'quizzes':
        sorted.sort((a, b) => b.attemptCount.compareTo(a.attemptCount));
        break;
      case 'alphabetical':
        sorted.sort((a, b) => a.deckTitle.toLowerCase().compareTo(b.deckTitle.toLowerCase()));
        break;
    }
    return sorted;
  }

  List<_SubjectStat> _sortSubjects(List<_SubjectStat> subjects) {
    final sorted = List<_SubjectStat>.from(subjects);
    switch (_sortBy) {
      case 'lowest':
        sorted.sort((a, b) => a.percent.compareTo(b.percent));
        break;
      case 'highest':
        sorted.sort((a, b) => b.percent.compareTo(a.percent));
        break;
      case 'recent':
      case 'quizzes':
        sorted.sort((a, b) => b.attemptCount.compareTo(a.attemptCount));
        break;
      case 'alphabetical':
        sorted.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
        break;
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.bar_chart_rounded, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detailed Breakdown',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      'Performance by deck and category',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                children: [
                  // View mode dropdown
                  PopupMenuButton<String>(
                    initialValue: _viewMode,
                    onSelected: (value) => setState(() => _viewMode = value),
                    offset: const Offset(0, 40),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    color: AppColors.surfaceContainerLowest,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryContainer.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.secondary.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.visibility_rounded, color: AppColors.secondary, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            _getViewModeLabel(),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    itemBuilder: (context) => [
                      _buildViewModeMenuItem('current', 'Current Mastery', Icons.trending_up_rounded),
                      _buildViewModeMenuItem('best', 'Best Performance', Icons.emoji_events_rounded),
                      _buildViewModeMenuItem('average', 'Average (Last 5)', Icons.analytics_rounded),
                    ],
                  ),
                  const SizedBox(width: 8),
                  // Sort dropdown
                  PopupMenuButton<String>(
                    initialValue: _sortBy,
                    onSelected: (value) => setState(() => _sortBy = value),
                    offset: const Offset(0, 40),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    color: AppColors.surfaceContainerLowest,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.sort_rounded, color: AppColors.primary, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            _getSortLabel(),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    itemBuilder: (context) => [
                      _buildSortMenuItem('lowest', 'Lowest Score First', Icons.arrow_downward_rounded),
                      _buildSortMenuItem('highest', 'Highest Score First', Icons.arrow_upward_rounded),
                      _buildSortMenuItem('recent', 'Recently Studied', Icons.schedule_rounded),
                      _buildSortMenuItem('quizzes', 'Most Quizzes', Icons.quiz_rounded),
                      _buildSortMenuItem('alphabetical', 'Alphabetical', Icons.sort_by_alpha_rounded),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _TabButton(
                    label: 'By Deck',
                    isSelected: _selectedTab == 0,
                    onTap: () => setState(() => _selectedTab = 0),
                  ),
                ),
                Expanded(
                  child: _TabButton(
                    label: 'By Category',
                    isSelected: _selectedTab == 1,
                    onTap: () => setState(() => _selectedTab = 1),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (_selectedTab == 0)
            _DeckBreakdownContent(
              decks: _sortDecks(widget.dashboard.deckSummaries),
              viewMode: _viewMode,
            )
          else
            _CategoryBreakdownContent(
              subjects: _sortSubjects(widget.subjectStats),
              totalDecks: widget.dashboard.deckSummaries.length,
              decks: widget.dashboard.deckSummaries,
              viewMode: _viewMode,
            ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildSortMenuItem(String value, String label, IconData icon) {
    final isSelected = _sortBy == value;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
            size: 18,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? AppColors.primary : AppColors.onSurface,
            ),
          ),
          if (isSelected) ...[
            const Spacer(),
            Icon(Icons.check_rounded, color: AppColors.primary, size: 18),
          ],
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildViewModeMenuItem(String value, String label, IconData icon) {
    final isSelected = _viewMode == value;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            color: isSelected ? AppColors.secondary : AppColors.onSurfaceVariant,
            size: 18,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? AppColors.secondary : AppColors.onSurface,
            ),
          ),
          if (isSelected) ...[
            const Spacer(),
            Icon(Icons.check_rounded, color: AppColors.secondary, size: 18),
          ],
        ],
      ),
    );
  }

  String _getSortLabel() {
    switch (_sortBy) {
      case 'lowest':
        return 'Lowest';
      case 'highest':
        return 'Highest';
      case 'recent':
        return 'Recent';
      case 'quizzes':
        return 'Quizzes';
      case 'alphabetical':
        return 'A-Z';
      default:
        return 'Sort';
    }
  }

  String _getViewModeLabel() {
    switch (_viewMode) {
      case 'current':
        return 'Current';
      case 'best':
        return 'Best';
      case 'average':
        return 'Average';
      default:
        return 'View';
    }
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.surfaceContainerLowest
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.onSurface.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected
                ? AppColors.primary
                : AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _DeckBreakdownContent extends StatelessWidget {
  const _DeckBreakdownContent({required this.decks, required this.viewMode});
  final List<DeckProgressSummary> decks;
  final String viewMode;

  @override
  Widget build(BuildContext context) {
    if (decks.isEmpty) {
      return const _EmptyProgressMessage(
        icon: Icons.layers_outlined,
        title: 'No deck progress yet',
        message: 'Complete quizzes to see individual deck progress here.',
      );
    }

    return Column(
      children: decks.map((deck) => _DeckProgressRow(deck: deck, viewMode: viewMode)).toList(),
    );
  }
}

class _DeckProgressRow extends StatelessWidget {
  const _DeckProgressRow({required this.deck, required this.viewMode});
  final DeckProgressSummary deck;
  final String viewMode;

  Color _categoryColor(String category) {
    const colors = {
      'Science': AppColors.tertiary,
      'Math': AppColors.primary,
      'Language': AppColors.secondary,
      'History': Color(0xFFE85D75),
      'Technology': Color(0xFF9B5DE5),
    };
    return colors[category] ?? AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final displayMetric = deck.getMetricByViewMode(viewMode);
    final masteryPercent = (displayMetric * 100).round();
    final color = _getPerformanceColor(displayMetric);

    return GestureDetector(
      onTap: () => _showDeckProgressSheet(context, deck),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.book_rounded, color: color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        deck.deckTitle,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${deck.category} · ${deck.attemptCount} quiz${deck.attemptCount == 1 ? '' : 'zes'}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$masteryPercent%',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.outline,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: displayMetric,
                minHeight: 8,
                backgroundColor: AppColors.outlineVariant.withOpacity(0.25),
                valueColor: AlwaysStoppedAnimation<Color>(_getPerformanceColor(displayMetric)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeckProgressSheet(BuildContext context, DeckProgressSummary deck) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DeckProgressSheet(deck: deck),
    );
  }
}

class _CategoryBreakdownContent extends StatelessWidget {
  const _CategoryBreakdownContent({
    required this.subjects,
    required this.totalDecks,
    required this.decks,
    required this.viewMode,
  });

  final List<_SubjectStat> subjects;
  final int totalDecks;
  final List<DeckProgressSummary> decks;
  final String viewMode;

  @override
  Widget build(BuildContext context) {
    if (subjects.isEmpty) {
      return const _EmptyProgressMessage(
        icon: Icons.category_outlined,
        title: 'No categories yet',
        message: 'Quiz results will appear here by deck category.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$totalDecks deck${totalDecks == 1 ? '' : 's'} with quiz history',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: AppColors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        ...subjects.map((s) => _SubjectRow(stat: s, decks: decks, viewMode: viewMode)),
      ],
    );
  }
}

class _SubjectRow extends StatelessWidget {
  const _SubjectRow({required this.stat, required this.decks, required this.viewMode});
  final _SubjectStat stat;
  final List<DeckProgressSummary> decks;
  final String viewMode;

  @override
  Widget build(BuildContext context) {
    final categoryDecks = decks.where((d) => d.category == stat.label).toList();
    final displayMetric = categoryDecks.isEmpty
        ? stat.percent
        : categoryDecks.map((d) => d.getMetricByViewMode(viewMode)).reduce((a, b) => a + b) / categoryDecks.length;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stat.label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${stat.reviewedCards} reviewed cards across ${stat.attemptCount} quiz${stat.attemptCount == 1 ? '' : 'zes'}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.outline,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${(displayMetric * 100).round()}%',
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
              value: displayMetric,
              minHeight: 10,
              backgroundColor: AppColors.outlineVariant.withOpacity(0.25),
              valueColor: AlwaysStoppedAnimation<Color>(_getPerformanceColor(displayMetric)),
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
          if (spots.isEmpty)
            const _EmptyProgressMessage(
              icon: Icons.check_circle_outline_rounded,
              title: 'No weak spots yet',
              message: 'Missed cards from future quizzes will collect here.',
            )
          else
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
// FORGOTTEN CARDS CARD
// ─────────────────────────────────────────────────────────────────────────────

class _ForgottenCardsCard extends StatelessWidget {
  const _ForgottenCardsCard({required this.cards});
  final List<_ForgottenCard> cards;

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
              Icon(Icons.history_rounded,
                  color: AppColors.tertiary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Forgotten Cards',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Cards you knew in your best session but forgot later',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          if (cards.isEmpty)
            const _EmptyProgressMessage(
              icon: Icons.celebration_outlined,
              title: 'No forgotten cards',
              message: 'You haven\'t forgotten anything you once knew!',
            )
          else
            ...cards.map((c) => _ForgottenCardTile(card: c)),
        ],
      ),
    );
  }
}

class _ForgottenCardTile extends StatelessWidget {
  const _ForgottenCardTile({required this.card});
  final _ForgottenCard card;

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
                color: AppColors.tertiary.withOpacity(0.3),
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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.tertiaryContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.refresh_rounded,
                    color: AppColors.tertiary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.topic,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${card.subject} · Failed ${card.failureCount}x after mastering',
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

class _EmptyProgressMessage extends StatelessWidget {
  const _EmptyProgressMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.outline, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
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
    );
  }
}

class _ProgressErrorBanner extends StatelessWidget {
  const _ProgressErrorBanner({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.errorContainer.withOpacity(0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withOpacity(0.20)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.error,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(
              'Retry',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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

    // Progress arc with performance color
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // start at top
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      Paint()
        ..color = _getPerformanceColor(progress)
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
    required this.reviewedCards,
    required this.attemptCount,
  });
  final String label;
  final double percent;
  final Color color;
  final int reviewedCards;
  final int attemptCount;
}

class _WeakSpot {
  const _WeakSpot({
    required this.topic,
    required this.subject,
    required this.deckTitle,
    required this.termCount,
  });
  final String topic;
  final String subject;
  final String deckTitle;
  final int termCount;
}

class _ForgottenCard {
  const _ForgottenCard({
    required this.topic,
    required this.subject,
    required this.deckTitle,
    required this.failureCount,
  });
  final String topic;
  final String subject;
  final String deckTitle;
  final int failureCount;
}



// ─────────────────────────────────────────────────────────────────────────────
// SHARED HELPERS
// ─────────────────────────────────────────────────────────────────────────────

/// Returns color based on performance: green (high ≥70%), yellow (mid 40-69%), red (low <40%)
Color _getPerformanceColor(double percent) {
  if (percent >= 0.7) return const Color(0xFF16A34A); // Green
  if (percent >= 0.4) return const Color(0xFFF59E0B); // Amber/Yellow
  return const Color(0xFFDC2626); // Red
}

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
          color: AppColors.primaryContainer.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.primary, size: 22),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DECK PROGRESS SHEET - Bottom sheet for individual deck actions
// ─────────────────────────────────────────────────────────────────────────────

class _DeckProgressSheet extends StatelessWidget {
  const _DeckProgressSheet({required this.deck});
  final DeckProgressSummary deck;

  Color _categoryColor(String category) {
    const colors = {
      'Science': AppColors.tertiary,
      'Math': AppColors.primary,
      'Language': AppColors.secondary,
      'History': Color(0xFFE85D75),
      'Technology': Color(0xFF9B5DE5),
    };
    return colors[category] ?? AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final masteryPercent = (deck.mastery * 100).round();
    final color = _categoryColor(deck.category);

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.outlineVariant,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 16),

          // ── Deck Header ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.book_rounded, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        deck.deckTitle,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onSurface,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          deck.category.toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: color,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Stats Summary ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _DeckStatItem(
                      icon: Icons.emoji_events_rounded,
                      label: 'Mastery',
                      value: '$masteryPercent%',
                      color: color,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: AppColors.outlineVariant.withOpacity(0.3),
                  ),
                  Expanded(
                    child: _DeckStatItem(
                      icon: Icons.quiz_rounded,
                      label: 'Quizzes',
                      value: '${deck.attemptCount}',
                      color: AppColors.secondary,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: AppColors.outlineVariant.withOpacity(0.3),
                  ),
                  Expanded(
                    child: _DeckStatItem(
                      icon: Icons.style_rounded,
                      label: 'Cards',
                      value: '${deck.answeredTotal}',
                      color: AppColors.tertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ── Primary Action: Study ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.of(context).pushNamed(
                    '/quiz',
                    arguments: {'deckId': deck.deckId, 'deckTitle': deck.deckTitle},
                  );
                },
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: Text(
                  'Study This Deck',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _DeckStatItem extends StatelessWidget {
  const _DeckStatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
            height: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

