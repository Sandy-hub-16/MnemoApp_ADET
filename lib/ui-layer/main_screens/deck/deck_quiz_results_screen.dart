import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../landing_page/app_theme.dart';
import 'deck_quiz_screen.dart'; // Import for QuizArgs

// ─────────────────────────────────────────────────────────────────────────────
// QUIZ RESULTS SCREEN — Detailed per-card breakdown
// Shows mastery statistics, per-card performance, and insights
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
    
    final masteredFirstTry = args.cardResults
        .where((r) => r.firstAttemptCorrect)
        .length;
    
    final neededRepetition = args.cardResults
        .where((r) => r.repetitionsNeeded > 1 && r.correct)
        .length;
    
    final skippedCount = args.cardResults
        .where((r) => r.skipped)
        .length;

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
                    
                    // Hero score card
                    _HeroScoreCard(
                      correctCount: args.correctCount,
                      totalCount: args.totalCount,
                      percentage: pct,
                      isMasteryTest: args.isMasteryTest,
                      isLowScoreExit: args.isLowScoreExit,
                    ),
                    const SizedBox(height: 20),
                    
                    // Quick stats row
                    _QuickStatsRow(
                      masteredFirstTry: masteredFirstTry,
                      neededRepetition: neededRepetition,
                      skipped: skippedCount,
                      totalCards: args.totalCount,
                      isMasteryTest: args.isMasteryTest,
                    ),
                    const SizedBox(height: 28),
                    
                    // Section header
                    Text(
                      'CARD-BY-CARD BREAKDOWN',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.outline,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Per-card list
                    ...args.cardResults.asMap().entries.map((entry) {
                      final index = entry.key;
                      final result = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _CardResultTile(
                          cardNumber: index + 1,
                          result: result,
                        ),
                      );
                    }),
                    
                    const SizedBox(height: 32),
                    
                    // Done button
                    _DoneButton(
                      onTap: () => Navigator.of(context).pushReplacementNamed('/progress'),
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
                    if (args.clonedFromUsername != null && args.clonedFromUsername!.isNotEmpty) ...[
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
                              'Deck by @${args.clonedFromUsername}',
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.secondaryContainer.withOpacity(0.7),
            AppColors.tertiaryContainer.withOpacity(0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.secondary.withOpacity(0.4),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lightbulb_rounded,
                  color: AppColors.secondary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Take a Step Back',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Review the material first',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest.withOpacity(0.7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'This material seems new to you! That\'s completely okay — everyone starts somewhere. '
              'Take some time to review the content, understand the concepts, and come back when you feel ready. '
              'You\'ve got this! 🚀',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.onSurface,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
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
            onTap: () => Navigator.of(context).pushReplacementNamed('/progress'),
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
    final emoji = percentage >= 80 ? '🏆' : percentage >= 50 ? '💪' : '📚';
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
            Text(
              '📚',
              style: const TextStyle(fontSize: 48),
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
// QUICK STATS ROW
// ─────────────────────────────────────────────────────────────────────────────

class _QuickStatsRow extends StatelessWidget {
  const _QuickStatsRow({
    required this.masteredFirstTry,
    required this.neededRepetition,
    required this.skipped,
    required this.totalCards,
    this.isMasteryTest = false,
  });

  final int masteredFirstTry;
  final int neededRepetition;
  final int skipped;
  final int totalCards;
  final bool isMasteryTest;

  @override
  Widget build(BuildContext context) {
    final completed = masteredFirstTry + neededRepetition;
    
    // For mastery test, only show the main completion banner (no breakdown)
    if (isMasteryTest) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.tertiaryContainer.withOpacity(0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.tertiary.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.tertiary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                color: AppColors.tertiary,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$completed/$totalCards cards mastered',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.tertiary,
              ),
            ),
          ],
        ),
      );
    }
    
    // For learning mode, show full breakdown
    return Column(
      children: [
        // Completed cards banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$completed/$totalCards cards completed',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        
        // Stats breakdown
        Row(
          children: [
            Expanded(
              child: _QuickStatCard(
                icon: Icons.bolt_rounded,
                label: 'First Try',
                value: masteredFirstTry.toString(),
                color: AppColors.tertiary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickStatCard(
                icon: Icons.repeat_rounded,
                label: 'Repeated',
                value: neededRepetition.toString(),
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickStatCard(
                icon: Icons.skip_next_rounded,
                label: 'Skipped',
                value: skipped.toString(),
                color: AppColors.error,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickStatCard extends StatelessWidget {
  const _QuickStatCard({
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: color,
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
          ),
        ],
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


