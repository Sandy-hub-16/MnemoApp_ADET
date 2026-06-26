import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../landing_page/app_theme.dart';
import 'deck_quiz_screen.dart'; // Import for QuizArgs

// ─────────────────────────────────────────────────────────────────────────────
// QUIZ RESULTS SCREEN — Streamlined summary, details on demand
//
// Design intent (redesigned):
//   The old version stacked THREE layers that all repeated the same story —
//   a hero %, a 3-card stat grid, and a full per-card list — before the user
//   could even act on the result. That's the information overload.
//
//   This version tells the story once, in order of how a user actually wants
//   to read it:
//     1. The headline number + message      (hero card)
//     2. One glance at the mix of outcomes   (single compact stat line)
//     3. The play-by-play, only if wanted    (collapsed by default)
//     4. What to do next                     (CTA buttons)
//
//   Nothing about the underlying data model changes — ProgressService still
//   receives the exact same per-card fields it always did, so the Progress
//   screen and Firestore writes are unaffected. This is a display-layer
//   redesign only.
// ─────────────────────────────────────────────────────────────────────────────

class QuizResultsArgs {
  const QuizResultsArgs({
    required this.deckId,
    required this.deckTitle,
    required this.ownerUid,
    required this.correctCount,
    required this.totalCount,
    required this.cardResults,
    this.isMasteryTest = false,
    this.isMasteryTestEligible = true,
    this.isLowScoreExit = false,
    this.clonedFromUsername,
  });

  final String deckId;
  final String deckTitle;
  final String? ownerUid;
  final int correctCount;
  final int totalCount;
  final List<CardResultData> cardResults;
  final bool isMasteryTest;
  final bool isMasteryTestEligible;
  final bool isLowScoreExit; // True when quiz ended early due to ≤20% score
  final String? clonedFromUsername;
}

class CardResultData {
  const CardResultData({
    required this.question,
    required this.correct,
    required this.repetitionsNeeded,
    required this.firstAttemptCorrect,
    required this.skipped,
  });

  final String question;
  final bool correct;
  final int repetitionsNeeded;
  final bool firstAttemptCorrect;
  final bool skipped;
}

class QuizResultsScreen extends StatelessWidget {
  const QuizResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as QuizResultsArgs?;

    if (args == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(child: Text('No results data')),
      );
    }

    final pct = args.totalCount > 0
        ? (args.correctCount / args.totalCount * 100).round()
        : 0;

    final masteredFirstTry =
        args.cardResults.where((r) => r.firstAttemptCorrect).length;

    final neededRepetition = args.cardResults
        .where((r) => r.repetitionsNeeded > 1 && r.correct)
        .length;

    final skippedCount = args.cardResults.where((r) => r.skipped).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            _TopBar(deckTitle: args.deckTitle),

            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Low score encouragement banner (only for ≤20% early exit)
                    if (args.isLowScoreExit) ...[
                      _LowScoreEncouragementBanner(),
                      const SizedBox(height: 20),
                    ],

                    // Hero score card — the one headline of the screen
                    _HeroScoreCard(
                      correctCount: args.correctCount,
                      totalCount: args.totalCount,
                      percentage: pct,
                      isMasteryTest: args.isMasteryTest,
                      isLowScoreExit: args.isLowScoreExit,
                    ),

                    // Compact stat line — a single glance at the mix of
                    // outcomes. Replaces the old completion banner + 3-card
                    // grid. Only non-zero stats are shown.
                    if (!args.isLowScoreExit) ...[
                      const SizedBox(height: 14),
                      _CompactStatLine(
                        masteredFirstTry: masteredFirstTry,
                        neededRepetition: neededRepetition,
                        skipped: skippedCount,
                        isMasteryTest: args.isMasteryTest,
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Collapsed-by-default per-card breakdown
                    _CardBreakdownSection(cardResults: args.cardResults),

                    const SizedBox(height: 28),

                    // Done button
                    _DoneButton(
                      onTap: () => Navigator.of(context)
                          .pushReplacementNamed('/progress'),
                    ),

                    // Test Your Mastery button (only show after learning mode AND if eligible)
                    if (!args.isMasteryTest && args.isMasteryTestEligible) ...[
                      const SizedBox(height: 12),
                      _TestMasteryButton(
                        deckId: args.deckId,
                        deckTitle: args.deckTitle,
                        ownerUid: args.ownerUid,
                      ),
                    ],

                    // Creator credit (only for cloned decks)
                    if (args.clonedFromUsername != null &&
                        args.clonedFromUsername!.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person_outline_rounded,
                              size: 12,
                              color: AppColors.outline,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Deck by ${args.clonedFromUsername}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: AppColors.outline,
                                fontWeight: FontWeight.w600,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOW SCORE ENCOURAGEMENT BANNER
// ─────────────────────────────────────────────────────────────────────────────

class _LowScoreEncouragementBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.secondaryContainer.withOpacity(0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.secondary.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lightbulb_rounded,
              color: AppColors.secondary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'New material — review it first, then try again. You\'ve got this 🚀',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOP BAR
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.deckTitle});
  final String deckTitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () =>
                Navigator.of(context).pushReplacementNamed('/progress'),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                color: AppColors.onSurfaceVariant,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quiz Results',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  deckTitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                    letterSpacing: -0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
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
// HERO SCORE CARD
// ─────────────────────────────────────────────────────────────────────────────

class _HeroScoreCard extends StatelessWidget {
  const _HeroScoreCard({
    required this.correctCount,
    required this.totalCount,
    required this.percentage,
    this.isMasteryTest = false,
    this.isLowScoreExit = false,
  });

  final int correctCount;
  final int totalCount;
  final int percentage;
  final bool isMasteryTest;
  final bool isLowScoreExit;

  @override
  Widget build(BuildContext context) {
    final emoji = percentage >= 80
        ? '🏆'
        : percentage >= 50
            ? '💪'
            : '📚';
    final message = percentage >= 80
        ? 'Outstanding!'
        : percentage >= 50
            ? 'Good effort!'
            : 'Keep practicing!';

    // Low score exit messaging
    if (isLowScoreExit) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.secondaryContainer.withOpacity(0.6),
              AppColors.tertiaryContainer.withOpacity(0.4),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.secondary.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            const Text(
              '📚',
              style: TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 12),
            Text(
              '$percentage%',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 56,
                fontWeight: FontWeight.w800,
                color: AppColors.secondary,
                letterSpacing: -2,
                height: 1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Time to Review!',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$correctCount of $totalCount cards completed',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    // Mastery test messaging
    String masteryHeadline;
    if (isMasteryTest) {
      if (percentage == 100) {
        masteryHeadline = 'Perfect Mastery! 🏆';
      } else if (percentage >= 80) {
        masteryHeadline = 'Strong Retention!';
      } else if (percentage >= 50) {
        masteryHeadline = 'Partial Mastery';
      } else {
        masteryHeadline = 'Needs More Practice';
      }
    } else {
      masteryHeadline = message;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            isMasteryTest
                ? AppColors.tertiaryContainer.withOpacity(0.6)
                : AppColors.primaryContainer.withOpacity(0.6),
            AppColors.secondaryContainer.withOpacity(0.4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isMasteryTest
              ? AppColors.tertiary.withOpacity(0.3)
              : AppColors.primary.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          if (isMasteryTest)
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.tertiaryContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                color: AppColors.tertiary,
                size: 32,
              ),
            )
          else
            Text(
              emoji,
              style: const TextStyle(fontSize: 48),
            ),
          const SizedBox(height: 12),
          Text(
            '$percentage%',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 56,
              fontWeight: FontWeight.w800,
              color: isMasteryTest ? AppColors.tertiary : AppColors.primary,
              letterSpacing: -2,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            masteryHeadline,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isMasteryTest ? AppColors.tertiary : AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isMasteryTest
                ? (percentage == 100
                    ? 'All $totalCount cards mastered!'
                    : 'Mastered $correctCount of $totalCount cards')
                : '$correctCount of $totalCount cards completed',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPACT STAT LINE
//
// Replaces the old "completed" banner + 3-card stat grid with a single
// inline row. Each entry only appears if its count is non-zero, so a clean
// run (no repeats, nothing skipped) shows just one chip instead of three
// boxes with two zeroes in them.
// ─────────────────────────────────────────────────────────────────────────────

class _CompactStatLine extends StatelessWidget {
  const _CompactStatLine({
    required this.masteredFirstTry,
    required this.neededRepetition,
    required this.skipped,
    this.isMasteryTest = false,
  });

  final int masteredFirstTry;
  final int neededRepetition;
  final int skipped;
  final bool isMasteryTest;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    void addChip(IconData icon, int value, String label, Color color) {
      if (value <= 0) return;
      if (chips.isNotEmpty) {
        chips.add(const SizedBox(width: 8));
      }
      chips
          .add(_StatChip(icon: icon, value: value, label: label, color: color));
    }

    addChip(
        Icons.bolt_rounded, masteredFirstTry, 'first try', AppColors.tertiary);
    addChip(Icons.repeat_rounded, neededRepetition, 'repeated',
        AppColors.secondary);
    addChip(Icons.skip_next_rounded, skipped, 'skipped', AppColors.error);

    if (chips.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(children: chips),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            '$value $label',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD BREAKDOWN SECTION — collapsed by default
//
// The full per-card list is real signal, but showing all of it unconditionally
// is what made the old screen feel heavy. This wraps the existing per-card
// tiles behind a single tappable summary row, so a user who just wants their
// score can stop reading right after the stat line, while anyone who wants
// the play-by-play can still get it in one tap.
// ─────────────────────────────────────────────────────────────────────────────

class _CardBreakdownSection extends StatefulWidget {
  const _CardBreakdownSection({required this.cardResults});
  final List<CardResultData> cardResults;

  @override
  State<_CardBreakdownSection> createState() => _CardBreakdownSectionState();
}

class _CardBreakdownSectionState extends State<_CardBreakdownSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final wrongCount = widget.cardResults.where((r) => !r.correct).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ExpandToggleRow(
          expanded: _expanded,
          totalCount: widget.cardResults.length,
          wrongCount: wrongCount,
          onTap: () => setState(() => _expanded = !_expanded),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _expanded
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    children: widget.cardResults.asMap().entries.map((entry) {
                      final index = entry.key;
                      final result = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _CardResultTile(
                          cardNumber: index + 1,
                          result: result,
                        ),
                      );
                    }).toList(),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _ExpandToggleRow extends StatelessWidget {
  const _ExpandToggleRow({
    required this.expanded,
    required this.totalCount,
    required this.wrongCount,
    required this.onTap,
  });

  final bool expanded;
  final int totalCount;
  final int wrongCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = wrongCount > 0
        ? '$wrongCount of $totalCount need another look'
        : 'Every card went well';

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.outline.withOpacity(0.15),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'See how each card went',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedRotation(
              turns: expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 220),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.onSurfaceVariant,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD RESULT TILE
// ─────────────────────────────────────────────────────────────────────────────

class _CardResultTile extends StatelessWidget {
  const _CardResultTile({
    required this.cardNumber,
    required this.result,
  });

  final int cardNumber;
  final CardResultData result;

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (result.skipped) {
      statusColor = AppColors.error;
      statusIcon = Icons.skip_next_rounded;
      statusText = 'Skipped';
    } else if (result.correct) {
      if (result.firstAttemptCorrect) {
        statusColor = AppColors.tertiary;
        statusIcon = Icons.bolt_rounded;
        statusText = 'First Try ⚡';
      } else {
        statusColor = AppColors.secondary;
        statusIcon = Icons.repeat_rounded;
        statusText = '${result.repetitionsNeeded}x attempts';
      }
    } else {
      statusColor = AppColors.error;
      statusIcon = Icons.cancel_rounded;
      statusText = 'Wrong';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card number badge
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$cardNumber',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: statusColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Question and status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.question,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(statusIcon, color: statusColor, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
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
// DONE BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _DoneButton extends StatelessWidget {
  const _DoneButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryFixedDim],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.26),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'View Progress Dashboard',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            const Icon(
              Icons.arrow_forward_rounded,
              color: Colors.white,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TEST YOUR MASTERY BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _TestMasteryButton extends StatelessWidget {
  const _TestMasteryButton({
    required this.deckId,
    required this.deckTitle,
    required this.ownerUid,
  });

  final String deckId;
  final String deckTitle;
  final String? ownerUid;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Navigate back to quiz in mastery test mode
        Navigator.of(context).pushReplacementNamed(
          '/quiz',
          arguments: QuizArgs(
            deckId: deckId,
            deckTitle: deckTitle,
            ownerUid: ownerUid,
            isMasteryTest: true,
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.tertiary, Color(0xFFEBC23E)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: AppColors.tertiary.withOpacity(0.26),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.emoji_events_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              'Test Your Mastery',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
