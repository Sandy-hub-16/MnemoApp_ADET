import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../landing_page/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// QUIZ SCREEN  —  route: /quiz
// Redesigned focus-mode quiz with:
//   • Cards fetched from Firestore and shuffled randomly every session
//   • Multiple Choice: "Reveal Choices" gate → 1-tap answer → immediate feedback
//   • Identification: type → "Check Answer" → field highlights green/red
//   • 1 attempt per card; Next/Done appears only after answering
//   • Completion overlay (score summary) → auto-navigate to /progress
//
// NAVIGATION — pass QuizArgs as route arguments:
//   Navigator.pushNamed(
//     context, AppRoutes.quiz,
//     arguments: QuizArgs(deckId: id, deckTitle: title),
//   );
//
// Or directly (e.g. from code):
//   Navigator.push(context, MaterialPageRoute(
//     builder: (_) => QuizScreen(deckId: id, deckTitle: title),
//   ));
// ─────────────────────────────────────────────────────────────────────────────

// ── Route argument bag ────────────────────────────────────────────────────────

class QuizArgs {
  const QuizArgs({
    required this.deckId,
    required this.deckTitle,
    this.ownerUid, // optional: set when quizzing a public deck owned by someone else
  });
  final String deckId;
  final String deckTitle;
  final String? ownerUid; // if null, defaults to the current user's own deck
}

// ── Card model (mirrors Firestore schema from create_deck_screen) ─────────────

class _QuizCard {
  const _QuizCard({
    required this.id,
    required this.type,
    required this.question,
    required this.answer,
    this.choices = const [],
    this.correctIndex = 0,
  });

  factory _QuizCard.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    final rawChoices = d['choices'];
    final choices = rawChoices is List
        ? rawChoices.map((e) => e.toString()).toList()
        : <String>[];
    return _QuizCard(
      id: doc.id,
      type: d['type'] as String? ?? 'identification',
      question: d['question'] as String? ?? '',
      answer: d['answer'] as String? ?? '',
      choices: choices,
      correctIndex: (d['correctIndex'] as int?) ?? 0,
    );
  }

  final String id;
  final String type; // 'multiple_choice' | 'identification'
  final String question;
  final String answer;
  final List<String> choices; // only populated for multiple_choice
  final int correctIndex;    // index into choices[] of the correct answer

  bool get isMultipleChoice => type == 'multiple_choice';
}

// ── Per-card result ───────────────────────────────────────────────────────────

class _CardResult {
  const _CardResult({required this.correct});
  final bool correct;
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

enum _QuizPhase { loading, quiz, completed }

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, this.deckId, this.deckTitle});

  /// Prefer passing via constructor; falls back to route arguments (QuizArgs).
  final String? deckId;
  final String? deckTitle;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> with TickerProviderStateMixin {
  // ── Core state ────────────────────────────────────────────────────────────────
  _QuizPhase _phase = _QuizPhase.loading;
  List<_QuizCard> _cards = [];
  int _currentIndex = 0;
  final List<_CardResult> _results = [];

  // ── Per-card transient state ──────────────────────────────────────────────────
  bool _answered = false;
  bool _isCorrect = false;

  // MC-specific
  bool _choicesRevealed = false;
  int? _selectedShuffledIndex;    // which shuffled slot the user tapped
  List<String> _shuffledChoices = [];
  List<int> _shuffleMap = [];     // shuffleMap[shuffledPos] = originalIndex

  // Identification-specific
  final TextEditingController _answerCtrl = TextEditingController();
  String _correctAnswerReveal = ''; // shown only on wrong identification

  // ── Animation controllers ─────────────────────────────────────────────────────
  late AnimationController _cardSlideCtrl;
  late Animation<Offset> _cardSlideAnim;
  late Animation<double> _cardFadeAnim;
  late AnimationController _completionCtrl;
  late Animation<double> _completionFadeAnim;
  late Animation<double> _completionScaleAnim;

  // ── Route args helpers ────────────────────────────────────────────────────────
  String get _deckId {
    if (widget.deckId != null && widget.deckId!.isNotEmpty) return widget.deckId!;
    final args = ModalRoute.of(context)?.settings.arguments;
    return (args is QuizArgs) ? args.deckId : '';
  }

  String get _deckTitle {
    if (widget.deckTitle != null && widget.deckTitle!.isNotEmpty) {
      return widget.deckTitle!;
    }
    final args = ModalRoute.of(context)?.settings.arguments;
    return (args is QuizArgs) ? args.deckTitle : 'Quiz';
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // LIFECYCLE
  // ─────────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    // Card slide-in animation
    _cardSlideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _cardSlideAnim = Tween<Offset>(
      begin: const Offset(0.08, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _cardSlideCtrl, curve: Curves.easeOutCubic));
    _cardFadeAnim = CurvedAnimation(parent: _cardSlideCtrl, curve: Curves.easeOutCubic);

    // Completion entrance animation
    _completionCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _completionFadeAnim = CurvedAnimation(parent: _completionCtrl, curve: Curves.easeOut);
    _completionScaleAnim = Tween<double>(begin: 0.90, end: 1.0)
        .animate(CurvedAnimation(parent: _completionCtrl, curve: Curves.easeOutBack));

    // Load after first frame so ModalRoute.of(context) is available
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCards());
  }

  @override
  void dispose() {
    _cardSlideCtrl.dispose();
    _completionCtrl.dispose();
    _answerCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // DATA LOADING
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> _loadCards() async {
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final id = _deckId;

      if (currentUid == null || id.isEmpty) {
        setState(() => _phase = _QuizPhase.quiz);
        return;
      }

      // Use ownerUid from args if provided (public deck owned by someone else),
      // otherwise fall back to the current user's own deck.
      final args = ModalRoute.of(context)?.settings.arguments;
      final ownerUid = (args is QuizArgs && args.ownerUid != null)
          ? args.ownerUid!
          : currentUid;

      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(ownerUid)
          .collection('decks')
          .doc(id)
          .collection('cards')
          .get();

      final loaded = snap.docs.map(_QuizCard.fromDoc).toList();

      // 🔀 Shuffle card order — different every session
      loaded.shuffle(Random());

      if (!mounted) return;
      setState(() {
        _cards = loaded;
        _phase = _QuizPhase.quiz;
        _currentIndex = 0;
      });
      _setupCard(0);
      _cardSlideCtrl.forward();
    } catch (e) {
      debugPrint('❌ QuizScreen._loadCards error: $e');
      if (!mounted) return;
      setState(() => _phase = _QuizPhase.quiz);
      _cardSlideCtrl.forward();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // CARD SETUP  — called whenever we move to a new card
  // ─────────────────────────────────────────────────────────────────────────────

  void _setupCard(int index) {
    _answered = false;
    _isCorrect = false;
    _choicesRevealed = false;
    _selectedShuffledIndex = null;
    _correctAnswerReveal = '';
    _answerCtrl.clear();

    if (index < _cards.length && _cards[index].isMultipleChoice) {
      final card = _cards[index];
      // 🔀 Shuffle the order choices appear in — different every card visit
      final positions = List<int>.generate(card.choices.length, (i) => i);
      positions.shuffle(Random());
      _shuffleMap = positions;
      _shuffledChoices = positions.map((i) => card.choices[i]).toList();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // ANSWER LOGIC
  // ─────────────────────────────────────────────────────────────────────────────

  /// Called when user taps a multiple-choice option.
  /// Immediate evaluation — no "Next" required to confirm.
  void _onChoiceTapped(int shuffledPos) {
    if (_answered) return; // 1 chance only
    final card = _cards[_currentIndex];
    final originalIdx = _shuffleMap[shuffledPos];
    final correct = originalIdx == card.correctIndex;
    setState(() {
      _answered = true;
      _isCorrect = correct;
      _selectedShuffledIndex = shuffledPos;
    });
    _results.add(_CardResult(correct: correct));
  }

  /// Called when user taps "Check Answer" for identification cards.
  void _onCheckIdentification() {
    if (_answered) return;
    final typed = _answerCtrl.text.trim();
    if (typed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please type your answer first.',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.outline,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
      return;
    }
    final card = _cards[_currentIndex];
    final correct = typed.toLowerCase() == card.answer.trim().toLowerCase();
    setState(() {
      _answered = true;
      _isCorrect = correct;
      if (!correct) _correctAnswerReveal = card.answer;
    });
    _results.add(_CardResult(correct: correct));
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // NAVIGATION
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> _advance() async {
    final isLast = _currentIndex >= _cards.length - 1;
    if (isLast) {
      await _finishQuiz();
      return;
    }

    // Animate current card out, then bring in the next
    await _cardSlideCtrl.reverse();
    setState(() {
      _currentIndex++;
      _setupCard(_currentIndex);
    });
    _cardSlideCtrl.forward();
  }

  Future<void> _finishQuiz() async {
    setState(() => _phase = _QuizPhase.completed);
    _completionCtrl.forward();

    // Brief pause so the user can read their score
    await Future.delayed(const Duration(milliseconds: 2800));
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/progress');
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // BUILD ROOT
  // ─────────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Ambient background blobs ─────────────────────────────────────────
          Positioned(
            top: 60,
            left: -90,
            child: _Blob(
              size: 300,
              color: AppColors.secondaryContainer.withOpacity(0.28),
            ),
          ),
          Positioned(
            bottom: 40,
            right: -110,
            child: _Blob(
              size: 360,
              color: AppColors.tertiaryContainer.withOpacity(0.22),
            ),
          ),

          // ── Phase content ────────────────────────────────────────────────────
          if (_phase == _QuizPhase.loading) _buildLoading(),
          if (_phase == _QuizPhase.quiz) _buildQuiz(),
          if (_phase == _QuizPhase.completed) _buildCompletion(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // LOADING STATE
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3),
          SizedBox(height: 20),
          Text(
            'Preparing your cards...',
            style: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // QUIZ STATE
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildQuiz() {
    if (_cards.isEmpty) return _buildEmptyDeck();

    final card = _cards[_currentIndex];
    final isLast = _currentIndex >= _cards.length - 1;

    return SafeArea(
      child: Column(
        children: [
          // Top bar (fixed)
          _QuizTopBar(deckTitle: _deckTitle),

          // Scrollable body
          Expanded(
            child: FadeTransition(
              opacity: _cardFadeAnim,
              child: SlideTransition(
                position: _cardSlideAnim,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Progress ──────────────────────────────────────────
                      _ProgressHeader(
                        current: _currentIndex + 1,
                        total: _cards.length,
                      ),
                      const SizedBox(height: 24),

                      // ── Question card ────────────────────────────────────
                      _QuestionCard(question: card.question),
                      const SizedBox(height: 20),

                      // ── Card-type-specific answer area ───────────────────
                      if (card.isMultipleChoice)
                        _buildMCSection(card)
                      else
                        _buildIdentificationSection(),

                      const SizedBox(height: 28),

                      // ── Next / Done button — only appears after answering
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        child: _answered
                            ? _NextDoneButton(isLast: isLast, onTap: _advance)
                            : const SizedBox.shrink(),
                      ),

                      const SizedBox(height: 40),
                      _MotivationalBubble(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // MULTIPLE CHOICE SECTION
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildMCSection(_QuizCard card) {
    if (!_choicesRevealed) {
      // ── Phase 1: Think-first gate ──────────────────────────────────────────
      return Column(
        children: [
          _ThinkFirstBanner(),
          const SizedBox(height: 20),
          _RevealChoicesButton(
            onTap: () => setState(() => _choicesRevealed = true),
          ),
        ],
      );
    }

    // ── Phase 2: Choices visible ─────────────────────────────────────────────
    return Column(
      children: List.generate(_shuffledChoices.length, (i) {
        final originalIdx = _shuffleMap[i];
        final isCorrectOption = originalIdx == card.correctIndex;
        final isUserChoice = _selectedShuffledIndex == i;

        // Determine visual state
        _ChoiceState state = _ChoiceState.idle;
        if (_answered) {
          if (isCorrectOption) {
            state = _ChoiceState.correct;
          } else if (isUserChoice) {
            state = _ChoiceState.wrong;
          } else {
            state = _ChoiceState.dimmed;
          }
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _ChoiceTile(
            label: _shuffledChoices[i],
            state: state,
            onTap: _answered ? null : () => _onChoiceTapped(i),
          ),
        );
      }),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // IDENTIFICATION SECTION
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildIdentificationSection() {
    final fieldColor = _answered
        ? (_isCorrect
            ? AppColors.primaryContainer.withOpacity(0.30)
            : AppColors.errorContainer.withOpacity(0.40))
        : AppColors.surfaceContainerLow;

    final borderSide = _answered
        ? BorderSide(
            color: _isCorrect ? AppColors.primary : AppColors.error,
            width: 2,
          )
        : BorderSide.none;

    final textColor = _answered
        ? (_isCorrect ? AppColors.primary : AppColors.error)
        : AppColors.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── YOUR ANSWER label ───────────────────────────────────────────────
        Text(
          'YOUR ANSWER',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.outline,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),

        // ── Text field ──────────────────────────────────────────────────────
        TextField(
          controller: _answerCtrl,
          enabled: !_answered,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
          decoration: InputDecoration(
            hintText: 'Type your answer here...',
            hintStyle: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              color: AppColors.outline.withOpacity(0.5),
            ),
            filled: true,
            fillColor: fieldColor,
            contentPadding: const EdgeInsets.all(20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: borderSide,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: borderSide,
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: borderSide,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: AppColors.primary.withOpacity(0.5),
                width: 2,
              ),
            ),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (!_answered) _onCheckIdentification();
          },
        ),

        // ── Feedback after checking ─────────────────────────────────────────
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          child: _answered
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 14),
                    if (_isCorrect)
                      _IdentificationFeedback(
                        correct: true,
                        correctAnswer: '',
                      )
                    else
                      _IdentificationFeedback(
                        correct: false,
                        correctAnswer: _correctAnswerReveal,
                      ),
                  ],
                )
              : const SizedBox.shrink(),
        ),

        // ── Check Answer button (disappears after answering) ─────────────────
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          child: !_answered
              ? Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: _CheckAnswerButton(onTap: _onCheckIdentification),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // EMPTY DECK FALLBACK
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildEmptyDeck() {
    return SafeArea(
      child: Column(
        children: [
          _QuizTopBar(deckTitle: _deckTitle),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.layers_outlined,
                          color: AppColors.outline, size: 38),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No cards in this deck yet.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add some cards and come back to study!',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: AppColors.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Go Back',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // COMPLETION STATE
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildCompletion() {
    final correct = _results.where((r) => r.correct).length;
    final total = _results.length;
    final pct = total > 0 ? (correct / total * 100).round() : 0;

    final emoji = pct >= 80
        ? '🏆'
        : pct >= 50
            ? '💪'
            : '📚';
    final headline = pct >= 80
        ? 'Outstanding!'
        : pct >= 50
            ? 'Good effort!'
            : 'Keep at it!';

    return FadeTransition(
      opacity: _completionFadeAnim,
      child: ScaleTransition(
        scale: _completionScaleAnim,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Trophy icon ──────────────────────────────────────────────
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.22),
                        blurRadius: 32,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.emoji_events_rounded,
                      color: AppColors.primary, size: 56),
                ),
                const SizedBox(height: 28),

                // ── Headline ─────────────────────────────────────────────────
                Text(
                  '$emoji Quiz Complete!',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurface,
                    letterSpacing: -0.6,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  headline,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 28),

                // ── Score card ───────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 36, vertical: 24),
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
                  child: Column(
                    children: [
                      Text(
                        '$pct%',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 52,
                          fontWeight: FontWeight.w800,
                          color: pct >= 80
                              ? AppColors.primary
                              : pct >= 50
                                  ? AppColors.secondary
                                  : AppColors.error,
                          letterSpacing: -1,
                        ),
                      ),
                      Text(
                        '$correct of $total cards correct',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),

                // ── Redirecting indicator ────────────────────────────────────
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Taking you to your Progress...',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: AppColors.outline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QUIZ TOP BAR
// ─────────────────────────────────────────────────────────────────────────────

class _QuizTopBar extends StatelessWidget {
  const _QuizTopBar({required this.deckTitle});
  final String deckTitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background.withOpacity(0.88),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Close button
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
                  color: AppColors.onSurfaceVariant, size: 20),
            ),
          ),
          const SizedBox(width: 12),

          // Deck name
          Expanded(
            child: Text(
              deckTitle,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
                letterSpacing: -0.2,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Focus mode badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withOpacity(0.5),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                const Icon(Icons.center_focus_strong_rounded,
                    color: AppColors.primary, size: 14),
                const SizedBox(width: 5),
                Text(
                  'FOCUS',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    letterSpacing: 1,
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
  const _ProgressHeader({required this.current, required this.total});
  final int current;
  final int total;

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
              '${((current / total) * 100).round()}% done',
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
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: current / total),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            builder: (_, value, __) => LinearProgressIndicator(
              value: value,
              minHeight: 10,
              backgroundColor: AppColors.outlineVariant.withOpacity(0.22),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
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
  const _QuestionCard({required this.question});
  final String question;

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
            color: AppColors.onSurface.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── QUESTION label + school icon ──────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
              const Icon(Icons.school_rounded,
                  color: AppColors.outlineVariant, size: 20),
            ],
          ),
          const SizedBox(height: 16),

          // ── Question text ─────────────────────────────────────────────────
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
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// THINK FIRST BANNER  (MC pre-reveal)
// ─────────────────────────────────────────────────────────────────────────────

class _ThinkFirstBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.tertiaryContainer.withOpacity(0.50),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.tertiaryContainer,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.tertiaryContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.psychology_rounded,
                color: AppColors.onTertiaryContainer, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Think before you reveal!',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onTertiaryContainer,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Try to recall the answer on your own first. It builds stronger memory.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppColors.onTertiaryContainer.withOpacity(0.75),
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
// REVEAL CHOICES BUTTON  (MC pre-reveal)
// ─────────────────────────────────────────────────────────────────────────────

class _RevealChoicesButton extends StatelessWidget {
  const _RevealChoicesButton({required this.onTap});
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
              color: AppColors.primary.withOpacity(0.26),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.visibility_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              'Reveal Choices',
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

// ─────────────────────────────────────────────────────────────────────────────
// CHOICE TILE  (MC post-reveal)
// ─────────────────────────────────────────────────────────────────────────────

enum _ChoiceState { idle, correct, wrong, dimmed }

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.label,
    required this.state,
    required this.onTap,
  });

  final String label;
  final _ChoiceState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;
    Color textColor;
    Widget? trailingIcon;

    switch (state) {
      case _ChoiceState.correct:
        bg = AppColors.primaryContainer.withOpacity(0.42);
        border = AppColors.primary;
        textColor = AppColors.primary;
        trailingIcon = const Icon(Icons.check_circle_rounded,
            color: AppColors.primary, size: 22);
        break;
      case _ChoiceState.wrong:
        bg = AppColors.errorContainer.withOpacity(0.50);
        border = AppColors.error;
        textColor = AppColors.error;
        trailingIcon = const Icon(Icons.cancel_rounded,
            color: AppColors.error, size: 22);
        break;
      case _ChoiceState.dimmed:
        bg = AppColors.surfaceContainerLowest;
        border = AppColors.outlineVariant.withOpacity(0.30);
        textColor = AppColors.onSurfaceVariant.withOpacity(0.50);
        trailingIcon = null;
        break;
      case _ChoiceState.idle:
        bg = AppColors.surfaceContainerLowest;
        border = Colors.transparent;
        textColor = AppColors.onSurface;
        trailingIcon = null;
        break;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border, width: 1.8),
          boxShadow: state == _ChoiceState.idle
              ? [
                  BoxShadow(
                    color: AppColors.onSurface.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: state == _ChoiceState.idle
                      ? FontWeight.w600
                      : FontWeight.w700,
                  color: textColor,
                  height: 1.4,
                ),
              ),
            ),
            if (trailingIcon != null) ...[
              const SizedBox(width: 12),
              trailingIcon,
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// IDENTIFICATION FEEDBACK PANEL
// ─────────────────────────────────────────────────────────────────────────────

class _IdentificationFeedback extends StatelessWidget {
  const _IdentificationFeedback({
    required this.correct,
    required this.correctAnswer,
  });

  final bool correct;
  final String correctAnswer;

  @override
  Widget build(BuildContext context) {
    if (correct) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer.withOpacity(0.30),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withOpacity(0.40), width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: AppColors.primary, size: 22),
            const SizedBox(width: 12),
            Text(
              'Correct! Great memory! 🎉',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      );
    }

    // Wrong — show correct answer highlighted in green
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.errorContainer.withOpacity(0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.error.withOpacity(0.35), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_rounded, color: AppColors.error, size: 20),
              const SizedBox(width: 8),
              Text(
                'Not quite — here\'s the correct answer:',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withOpacity(0.40),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.35), width: 1.5),
            ),
            child: Text(
              correctAnswer,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CHECK ANSWER BUTTON  (Identification)
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

// ─────────────────────────────────────────────────────────────────────────────
// NEXT / DONE BUTTON  (appears after answering any card type)
// ─────────────────────────────────────────────────────────────────────────────

class _NextDoneButton extends StatelessWidget {
  const _NextDoneButton({required this.isLast, required this.onTap});
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isLast
                ? [AppColors.tertiary, const Color(0xFFEBC23E)]
                : [AppColors.secondary, AppColors.secondaryFixedDim],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: (isLast ? AppColors.tertiary : AppColors.secondary)
                  .withOpacity(0.25),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isLast ? 'Finish Quiz' : 'Next Card',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              isLast ? Icons.flag_rounded : Icons.navigate_next_rounded,
              color: Colors.white,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MOTIVATIONAL BUBBLE
// ─────────────────────────────────────────────────────────────────────────────

class _MotivationalBubble extends StatelessWidget {
  static const _messages = [
    '"Active recall is the single most effective study technique. You\'ve got this!"',
    '"Each card you review today saves you hours of cramming tomorrow."',
    '"Struggle a little — that\'s your brain building new pathways!"',
    '"Consistency beats intensity. Keep going, one card at a time."',
  ];

  @override
  Widget build(BuildContext context) {
    final msg = _messages[DateTime.now().millisecond % _messages.length];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            shape: BoxShape.circle,
            border: Border.all(
                color: AppColors.surfaceContainerLowest, width: 2),
          ),
          child: const Icon(Icons.auto_awesome_rounded,
              color: AppColors.primary, size: 17),
        ),
        const SizedBox(width: 10),

        // Bubble
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
              msg,
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