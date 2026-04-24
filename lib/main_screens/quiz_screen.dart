import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../landing_page/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// QUIZ SCREEN  —  route: /quiz
// Focus-mode quiz interface. No bottom nav bar (intentional).
//
// 🎨 FRONTEND NOTE:
// All card data (question, hint, card index) is hardcoded as placeholders.
// _showFeedback and _isCorrect control the feedback panel visibility.
// Wire up real answer-checking logic in _checkAnswer() when backend is ready.
// The timer shows a static value — hook up a real countdown in initState().
// ─────────────────────────────────────────────────────────────────────────────

class QuizScreen extends StatelessWidget {
  const QuizScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _QuizScaffold();
  }
}

class _QuizScaffold extends StatefulWidget {
  const _QuizScaffold();

  @override
  State<_QuizScaffold> createState() => _QuizScaffoldState();
}

class _QuizScaffoldState extends State<_QuizScaffold> {
  final _answerCtrl = TextEditingController();

  // ── UI State ────────────────────────────────────────────────────────────────
  bool _showFeedback = false;
  bool _isCorrect = false; // toggled by _checkAnswer — no real logic yet
  bool _showHint = false;

  // ── Placeholder deck data ───────────────────────────────────────────────────
  static const int _totalCards = 20;
  static const int _currentCard = 5;
  static const double _masteryPct = 0.25;
  static const String _deckName = 'Organic Chemistry Basics';
  static const String _question =
      'What is the functional group name for an R–OH structure?';
  static const String _hint =
      'Think about alcohols — what element connects oxygen to hydrogen?';

  @override
  void dispose() {
    _answerCtrl.dispose();
    super.dispose();
  }

  // ── Placeholder: just toggles feedback panel for visual preview ─────────────
  void _checkAnswer() {
    if (_answerCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please type your answer first.',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.outline,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    setState(() {
      _showFeedback = true;
      _isCorrect = true; // placeholder — always "correct" for now
    });
  }

  void _nextCard() {
    setState(() {
      _showFeedback = false;
      _showHint = false;
      _answerCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Background blobs ─────────────────────────────────────────────
          Positioned(
            top: 80,
            left: -80,
            child: _Blob(
              size: 260,
              color: AppColors.secondaryContainer.withOpacity(0.35),
            ),
          ),
          Positioned(
            bottom: 80,
            right: -100,
            child: _Blob(
              size: 320,
              color: AppColors.tertiaryContainer.withOpacity(0.30),
            ),
          ),

          // ── Screen content ───────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // ── Top bar ────────────────────────────────────────────────
                _QuizTopBar(deckName: _deckName),

                // ── Scrollable body ────────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Progress header ──────────────────────────────
                        _ProgressHeader(
                          current: _currentCard,
                          total: _totalCards,
                          mastery: _masteryPct,
                        ),
                        const SizedBox(height: 24),

                        // ── Question card ────────────────────────────────
                        _QuestionCard(
                          question: _question,
                          answerCtrl: _answerCtrl,
                          showFeedback: _showFeedback,
                          isCorrect: _isCorrect,
                          showHint: _showHint,
                          hint: _hint,
                        ),
                        const SizedBox(height: 28),

                        // ── Action buttons ───────────────────────────────
                        _showFeedback
                            ? _NextCardButton(onTap: _nextCard)
                            : _CheckAnswerButton(onTap: _checkAnswer),
                        const SizedBox(height: 16),

                        // ── Hint / Skip row ──────────────────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (!_showFeedback)
                              _TextActionButton(
                                icon: Icons.lightbulb_outline_rounded,
                                label: _showHint ? 'Hide Hint' : 'Reveal Hint',
                                onTap: () =>
                                    setState(() => _showHint = !_showHint),
                              ),
                            if (!_showFeedback) const SizedBox(width: 24),
                            _TextActionButton(
                              icon: Icons.skip_next_rounded,
                              label: 'Skip Card',
                              onTap: _nextCard,
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),

                        // ── Motivational bubble ──────────────────────────
                        _MotivationalBubble(),
                      ],
                    ),
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
// QUIZ TOP BAR — focus mode: close button + deck name + timer
// ─────────────────────────────────────────────────────────────────────────────

class _QuizTopBar extends StatelessWidget {
  const _QuizTopBar({required this.deckName});
  final String deckName;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background.withOpacity(0.85),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // ── Close button ────────────────────────────────────────────────
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded,
                  color: AppColors.onSurfaceVariant, size: 22),
            ),
          ),
          const SizedBox(width: 12),

          // ── Deck name ───────────────────────────────────────────────────
          Expanded(
            child: Text(
              deckName,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
                letterSpacing: -0.2,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // ── Timer chip ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined,
                    color: AppColors.primary, size: 18),
                const SizedBox(width: 5),
                Text(
                  '12:45',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
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

// ─────────────────────────────────────────────────────────────────────────────
// PROGRESS HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.current,
    required this.total,
    required this.mastery,
  });

  final int current;
  final int total;
  final double mastery;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Card $current of $total',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                letterSpacing: 0.8,
              ),
            ),
            Text(
              '${(mastery * 100).round()}% Mastery',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: current / total,
            minHeight: 10,
            backgroundColor: AppColors.outlineVariant.withOpacity(0.25),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QUESTION CARD
// ─────────────────────────────────────────────────────────────────────────────

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.question,
    required this.answerCtrl,
    required this.showFeedback,
    required this.isCorrect,
    required this.showHint,
    required this.hint,
  });

  final String question;
  final TextEditingController answerCtrl;
  final bool showFeedback;
  final bool isCorrect;
  final bool showHint;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withOpacity(0.07),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Label ──────────────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.secondaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'QUESTION',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSecondaryContainer,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const Spacer(),
              Icon(Icons.school_rounded,
                  color: AppColors.outlineVariant, size: 22),
            ],
          ),
          const SizedBox(height: 16),

          // ── Question text ──────────────────────────────────────────────
          Text(
            question,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
              height: 1.4,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 24),

          // ── Hint panel ─────────────────────────────────────────────────
          if (showHint) ...[
            _HintPanel(hint: hint),
            const SizedBox(height: 16),
          ],

          // ── Answer input ───────────────────────────────────────────────
          if (!showFeedback) ...[
            Text(
              'YOUR ANSWER',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: AppColors.outline,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: answerCtrl,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Type the answer here...',
                hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  color: AppColors.outline.withOpacity(0.5),
                ),
                filled: true,
                fillColor: AppColors.surfaceContainerLow,
                contentPadding: const EdgeInsets.all(20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: AppColors.primary.withOpacity(0.4),
                    width: 2,
                  ),
                ),
              ),
            ),
          ],

          // ── Feedback panel ─────────────────────────────────────────────
          if (showFeedback) _FeedbackPanel(isCorrect: isCorrect),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HINT PANEL
// ─────────────────────────────────────────────────────────────────────────────

class _HintPanel extends StatelessWidget {
  const _HintPanel({required this.hint});
  final String hint;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.tertiaryContainer.withOpacity(0.45),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.tertiaryContainer,
            width: 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lightbulb_rounded,
                color: AppColors.tertiary, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hint,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.onTertiaryContainer,
                  height: 1.5,
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
// FEEDBACK PANEL
// ─────────────────────────────────────────────────────────────────────────────

class _FeedbackPanel extends StatelessWidget {
  const _FeedbackPanel({required this.isCorrect});
  final bool isCorrect;

  @override
  Widget build(BuildContext context) {
    final bgColor = isCorrect
        ? AppColors.primaryContainer.withOpacity(0.35)
        : AppColors.errorContainer.withOpacity(0.5);
    final borderColor =
        isCorrect ? AppColors.primaryContainer : AppColors.errorContainer;
    final icon = isCorrect ? Icons.check_circle_rounded : Icons.error_rounded;
    final iconColor = isCorrect ? AppColors.primary : AppColors.error;
    final title = isCorrect ? 'Correct! 🎉' : 'Not quite — try again!';
    final subtitle = isCorrect
        ? 'Hydroxyl groups are key components of alcohols and phenols.'
        : 'R–OH specifically indicates an oxygen atom bonded to hydrogen.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: iconColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: iconColor.withOpacity(0.75),
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

// ─────────────────────────────────────────────────────────────────────────────
// ACTION BUTTONS
// ─────────────────────────────────────────────────────────────────────────────

class _CheckAnswerButton extends StatelessWidget {
  const _CheckAnswerButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryFixedDim],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.28),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Check Answer',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.arrow_forward_rounded,
                color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}

class _NextCardButton extends StatelessWidget {
  const _NextCardButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.secondary, AppColors.secondaryFixedDim],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: AppColors.secondary.withOpacity(0.25),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Next Card',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.navigate_next_rounded,
                color: Colors.white, size: 22),
          ],
        ),
      ),
    );
  }
}

class _TextActionButton extends StatelessWidget {
  const _TextActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: AppColors.outline, size: 18),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.outline,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MOTIVATIONAL BUBBLE
// ─────────────────────────────────────────────────────────────────────────────

class _MotivationalBubble extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── AI avatar icon ────────────────────────────────────────────────
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            shape: BoxShape.circle,
            border:
                Border.all(color: AppColors.surfaceContainerLowest, width: 2),
          ),
          child: const Icon(Icons.auto_awesome_rounded,
              color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 10),

        // ── Bubble ────────────────────────────────────────────────────────
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.tertiaryContainer,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: Text(
              '"Take your time, friend. Active recall is the secret to making this knowledge stick forever!"',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.onTertiaryContainer,
                height: 1.6,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
      ],
    );
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
