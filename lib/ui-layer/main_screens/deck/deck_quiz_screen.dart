import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../landing_page/app_theme.dart';
import '../../../business-layer/services/progress_service.dart';
import 'deck_quiz_results_screen.dart';
import '../settings/settings_screen.dart'
    show kQuizTimerEnabledKey, kShuffleCardsKey;

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
    this.isMasteryTest =
        false, // true = mastery test mode, false = learning mode
  });
  final String deckId;
  final String deckTitle;
  final String? ownerUid; // if null, defaults to the current user's own deck
  final bool isMasteryTest; // Determines quiz behavior
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
  final int correctIndex; // index into choices[] of the correct answer

  bool get isMultipleChoice => type == 'multiple_choice';
}

// ── Per-card result with repetition tracking ─────────────────────────────────

class _CardResult {
  _CardResult({
    required this.cardId,
    required this.question,
    required this.correct,
    int? repetitionsNeeded,
    bool? firstAttemptCorrect,
    bool? skipped,
    int? correctStreak,
    bool? mastered,
    int? wrongAttempts,
  })  : repetitionsNeeded = repetitionsNeeded ?? 1,
        firstAttemptCorrect = firstAttemptCorrect ?? true,
        skipped = skipped ?? false,
        correctStreak = correctStreak ?? 0,
        mastered = mastered ?? false,
        wrongAttempts = wrongAttempts ?? 0;

  final String cardId;
  final String question;
  bool correct;
  int repetitionsNeeded;
  bool firstAttemptCorrect;
  bool skipped;
  int correctStreak;
  bool mastered;
  int wrongAttempts;
}

// ── Per-card transient UI state ──────────────────────────────────────────────
// Everything here is scoped to "however the current card looks right now" —
// answered/not, which choice was tapped, etc. It's bundled into one object and
// replaced wholesale by _setupCard() instead of being reset field-by-field, so
// a new per-card field can't be left out of a reset by accident.
class _CardSessionState {
  _CardSessionState({
    required this.canSkip,
    this.shuffledChoices = const [],
    this.shuffleMap = const [],
    this.showThinkFirstGate = false,
  });

  bool answered = false;
  bool isCorrect = false;
  final bool canSkip; // Shows skip button after 2 failed attempts

  // MC-specific
  bool choicesRevealed = false;
  int? selectedShuffledIndex; // which shuffled slot the user tapped
  final List<String> shuffledChoices;
  final List<int> shuffleMap; // shuffleMap[shuffledPos] = originalIndex
  final bool
      showThinkFirstGate; // true only if in this session's ~25% subset AND first showing

  // Identification-specific
  String correctAnswerReveal = ''; // shown only on wrong identification
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

enum _QuizPhase { loading, quiz, completed }

class QuizScreen extends StatefulWidget {
  const QuizScreen(
      {super.key, this.deckId, this.deckTitle, this.isMasteryTest = false});

  /// Prefer passing via constructor; falls back to route arguments (QuizArgs).
  final String? deckId;
  final String? deckTitle;
  final bool isMasteryTest;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> with TickerProviderStateMixin {
  // ── Core state ────────────────────────────────────────────────────────────────
  _QuizPhase _phase = _QuizPhase.loading;
  List<_QuizCard> _cards = []; // All cards in deck (original)
  List<_QuizCard> _cardQueue = []; // Active queue of cards to study
  int _currentQueueIndex = 0;
  final Map<String, _CardResult> _cardResults = {}; // cardId -> result
  final Map<String, int> _cardAttempts = {}; // cardId -> attempt count
  int _totalCardsInDeck = 0;
  String _deckCategory = 'Other';
  String? _quizOwnerUid;
  String? _clonedFromUsername;
  bool _attemptSaved = false;

  // ~25% of this deck's cards, re-shuffled every session, eligible to show
  // the "think first" gate on their first encounter (see _loadCards).
  Set<String> _thinkFirstCardIds = {};

  // ── Progress tracking (new system) ────────────────────────────────────────────
  int _cardsSeenCount = 0; // How many unique cards have been seen (1-10)
  final Set<String> _seenCardIds = {}; // Track which cards have been seen
  int get _cardsNeedingReview =>
      _cardQueue.where((c) => _seenCardIds.contains(c.id)).length;

  // Track whether we've already logged this session to Recent Activity
  bool _sessionTracked = false;

  // ── Per-card transient state ──────────────────────────────────────────────────
  // Bundled into _CardSessionState (defined above) and replaced wholesale by
  // _setupCard() each time we move to a new card.
  late _CardSessionState _cardSession;

  // Identification-specific — kept separate since it's a controller, not a
  // value we reset; we just clear its text in _setupCard().
  final TextEditingController _answerCtrl = TextEditingController();

  // Motivational bubble message — rotates every few cards rather than on
  // every rebuild, so it doesn't change mid-interaction or feel like noise.
  String _motivationalMessage = _motivationalMessages.first;
  int _cardsSinceMotivationalChange = 0;
  static const int _motivationalMessageInterval = 3; // cards between changes

  // ── Quiz timer (optional, controlled by Settings > Quiz Timer toggle) ─────────
  static const int _timerDuration = 15; // seconds per card
  bool _timerEnabled = false; // loaded from SharedPreferences on init
  int _timerSecondsLeft = _timerDuration;
  Timer? _countdownTimer;

  // ── Animation controllers ─────────────────────────────────────────────────────
  late AnimationController _cardSlideCtrl;
  late Animation<Offset> _cardSlideAnim;
  late Animation<double> _cardFadeAnim;
  late AnimationController _completionCtrl;
  late Animation<double> _completionFadeAnim;
  late Animation<double> _completionScaleAnim;

  // ── Route args helpers ────────────────────────────────────────────────────────
  String get _deckId {
    if (widget.deckId != null && widget.deckId!.isNotEmpty)
      return widget.deckId!;
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

  String? get _routeOwnerUid {
    final args = ModalRoute.of(context)?.settings.arguments;
    return (args is QuizArgs) ? args.ownerUid : null;
  }

  bool get _isMasteryTest {
    if (widget.isMasteryTest) return true;
    final args = ModalRoute.of(context)?.settings.arguments;
    return (args is QuizArgs) ? args.isMasteryTest : false;
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
    ).animate(
        CurvedAnimation(parent: _cardSlideCtrl, curve: Curves.easeOutCubic));
    _cardFadeAnim =
        CurvedAnimation(parent: _cardSlideCtrl, curve: Curves.easeOutCubic);

    // Completion entrance animation
    _completionCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _completionFadeAnim =
        CurvedAnimation(parent: _completionCtrl, curve: Curves.easeOut);
    _completionScaleAnim = Tween<double>(begin: 0.90, end: 1.0).animate(
        CurvedAnimation(parent: _completionCtrl, curve: Curves.easeOutBack));

    // Load after first frame so ModalRoute.of(context) is available
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        _timerEnabled = prefs.getBool(kQuizTimerEnabledKey) ?? false;
      }
      _loadCards();
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
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
      final ownerUid = _routeOwnerUid ?? currentUid;
      _quizOwnerUid = ownerUid;

      final deckRef = FirebaseFirestore.instance
          .collection('users')
          .doc(ownerUid)
          .collection('decks')
          .doc(id);

      final deckSnap = await deckRef.get();
      final deckData = deckSnap.data();
      final rawTag = deckData?['tag'] as String?;
      final category =
          rawTag == null || rawTag.trim().isEmpty ? 'Other' : rawTag.trim();
      _clonedFromUsername = deckData?['clonedFromUsername'] as String?;

      final prefs = await SharedPreferences.getInstance();
      final shuffleEnabled = prefs.getBool(kShuffleCardsKey) ?? true;

      // Fetch cards: ordered by creation time when shuffle is off,
      // unordered (Firestore default) when shuffle is on.
      final cardsQuery = shuffleEnabled
          ? deckRef.collection('cards').get()
          : deckRef.collection('cards').orderBy('createdAt').get();

      final snap = await cardsQuery;

      final loaded = snap.docs.map(_QuizCard.fromDoc).toList();

      // 🔀 Shuffle card order only when the setting is enabled
      if (shuffleEnabled) {
        loaded.shuffle(Random());
      }

      // 🔀 Independently shuffle + pick ~25% of the deck to get the
      // "think first" gate this session — re-rolled every time, so it's
      // not always the same cards, and it's a fixed share of the deck
      // rather than an independent coin-flip per card.
      final shuffledIdsForGate = loaded.map((c) => c.id).toList()
        ..shuffle(Random());
      final gateCount = (loaded.length * 0.25).round();
      final thinkFirstIds = shuffledIdsForGate.take(gateCount).toSet();

      if (!mounted) return;
      setState(() {
        _cards = loaded;
        _cardQueue = List.from(loaded); // Initialize queue with all cards
        _totalCardsInDeck = loaded.length;
        _deckCategory = category;
        _phase = _QuizPhase.quiz;
        _currentQueueIndex = 0;
        _thinkFirstCardIds = thinkFirstIds;
      });
      _setupCard();
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

  void _setupCard() {
    if (_currentQueueIndex >= _cardQueue.length) return;

    final card = _cardQueue[_currentQueueIndex];
    final attempts = _cardAttempts[card.id] ?? 0;

    _answerCtrl.clear();

    // 🔀 Shuffle the order choices appear in — different every card visit
    List<int> shuffleMap = const [];
    List<String> shuffledChoices = const [];
    if (card.isMultipleChoice) {
      final positions = List<int>.generate(card.choices.length, (i) => i);
      positions.shuffle(Random());
      shuffleMap = positions;
      shuffledChoices = positions.map((i) => card.choices[i]).toList();
    }

    // Replace the whole per-card state at once. Any future per-card field
    // lives on _CardSessionState, so there's nothing extra to remember here.
    // Think-first gate: only for cards in this session's ~25% subset
    // (_thinkFirstCardIds), and only on their true first showing —
    // _seenCardIds only gains an id once we've advanced past that card, so a
    // card being requeued after a wrong answer won't re-trigger the gate.
    _cardSession = _CardSessionState(
      canSkip: attempts >= 2, // Show skip after 2 failed attempts
      shuffleMap: shuffleMap,
      shuffledChoices: shuffledChoices,
      showThinkFirstGate: card.isMultipleChoice &&
          _thinkFirstCardIds.contains(card.id) &&
          !_seenCardIds.contains(card.id),
    );

    // Rotate the motivational message every few cards instead of on every
    // single card, so it reads as occasional variety rather than flicker.
    _cardsSinceMotivationalChange++;
    if (_cardsSinceMotivationalChange >= _motivationalMessageInterval) {
      _motivationalMessage =
          _motivationalMessages[Random().nextInt(_motivationalMessages.length)];
      _cardsSinceMotivationalChange = 0;
    }

    // Start countdown — but hold off if the think-first gate is showing;
    // _startTimer() will be called instead when the user taps "Reveal Choices".
    if (!_cardSession.showThinkFirstGate) {
      _startTimer();
    } else {
      _stopTimer(); // ensure no leftover timer from previous card
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // QUIZ TIMER  — 15 s countdown; fires _onTimerExpired when it reaches 0.
  // Only active when _timerEnabled is true and the current card is unanswered.
  // ─────────────────────────────────────────────────────────────────────────────

  void _startTimer() {
    _countdownTimer?.cancel();
    if (!_timerEnabled) return;
    setState(() => _timerSecondsLeft = _timerDuration);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_cardSession.answered) {
        t.cancel();
        return;
      }
      setState(() => _timerSecondsLeft--);
      if (_timerSecondsLeft <= 0) {
        t.cancel();
        _onTimerExpired();
      }
    });
  }

  void _stopTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  /// Called when the 15-second timer runs out.
  /// Marks the current card as wrong (empty answer) and auto-advances.
  void _onTimerExpired() {
    if (_cardSession.answered) return;

    final card = _cardQueue[_currentQueueIndex];

    // Track attempts
    _cardAttempts[card.id] = (_cardAttempts[card.id] ?? 0) + 1;

    // Record a wrong result (time out = wrong)
    final result = _cardResults.putIfAbsent(
      card.id,
      () => _CardResult(
        cardId: card.id,
        question: card.question,
        correct: false,
        firstAttemptCorrect: false,
      ),
    );
    result.repetitionsNeeded = _cardAttempts[card.id]!;
    result.wrongAttempts++;
    result.correct = false;
    result.mastered = false;

    // For identification cards, fill in the reveal so the user can see the answer
    if (!card.isMultipleChoice) {
      setState(() {
        _cardSession.answered = true;
        _cardSession.isCorrect = false;
        _cardSession.correctAnswerReveal = card.answer;
      });
    } else {
      // For MC, mark answered but don't select any choice (none highlighted as "user choice")
      setState(() {
        _cardSession.answered = true;
        _cardSession.isCorrect = false;
      });
    }

    // Track session on first time-out (same as a normal submit)
    if (!_sessionTracked) {
      _sessionTracked = true;
      _trackDeckStarted();
    }

    // Auto-advance after a brief pause so the user sees the result
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted && _cardSession.answered) _advance();
    });
  }

  /// Called when user taps a multiple-choice option.
  /// Immediate evaluation — no "Next" required to confirm.
  void _onChoiceTapped(int shuffledPos) {
    if (_cardSession.answered) return;
    _stopTimer(); // user answered — cancel any running countdown

    final card = _cardQueue[_currentQueueIndex];
    final originalIdx = _cardSession.shuffleMap[shuffledPos];
    final correct = originalIdx == card.correctIndex;

    // Track attempts
    _cardAttempts[card.id] = (_cardAttempts[card.id] ?? 0) + 1;

    // Get or create result
    final result = _cardResults.putIfAbsent(
      card.id,
      () => _CardResult(
        cardId: card.id,
        question: card.question,
        correct: false,
        firstAttemptCorrect: correct,
      ),
    );

    result.repetitionsNeeded = _cardAttempts[card.id]!;

    // Track wrong attempts
    if (!correct) {
      result.wrongAttempts++;
    }

    setState(() {
      _cardSession.answered = true;
      _cardSession.isCorrect = correct;
      _cardSession.selectedShuffledIndex = shuffledPos;
    });

    // Track session on first submitted answer (fire-and-forget).
    // Fires the instant a choice is tapped — before Next is ever pressed —
    // so the deck appears in Recent Activity even if the user exits early.
    if (!_sessionTracked) {
      _sessionTracked = true;
      _trackDeckStarted();
    }

    if (correct) {
      result.correct = true;
      result.mastered = true;
    } else {
      result.correct = false;
      result.mastered = false;
    }
  }

  /// Called when user taps "Check Answer" for identification cards.
  void _onCheckIdentification() {
    if (_cardSession.answered) return;
    _stopTimer(); // user answered — cancel any running countdown
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
      return;
    }

    final card = _cardQueue[_currentQueueIndex];
    final correct = typed.toLowerCase() == card.answer.trim().toLowerCase();

    // Track attempts
    _cardAttempts[card.id] = (_cardAttempts[card.id] ?? 0) + 1;

    // Get or create result
    final result = _cardResults.putIfAbsent(
      card.id,
      () => _CardResult(
        cardId: card.id,
        question: card.question,
        correct: false,
        firstAttemptCorrect: correct,
      ),
    );

    result.repetitionsNeeded = _cardAttempts[card.id]!;

    // Track wrong attempts
    if (!correct) {
      result.wrongAttempts++;
    }

    setState(() {
      _cardSession.answered = true;
      _cardSession.isCorrect = correct;
      if (!correct) _cardSession.correctAnswerReveal = card.answer;
    });

    // Track session on first submitted answer (fire-and-forget).
    // Fires the instant "Check Answer" is tapped — before Next is ever pressed —
    // so the deck appears in Recent Activity even if the user exits early.
    if (!_sessionTracked) {
      _sessionTracked = true;
      _trackDeckStarted();
    }

    if (correct) {
      result.correct = true;
      result.mastered = true;
    } else {
      result.correct = false;
      result.mastered = false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // NAVIGATION
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> _advance() async {
    final card = _cardQueue[_currentQueueIndex];
    final result = _cardResults[card.id]!;

    // Track if this is the first time seeing this card
    final isFirstTimeSeeingCard = !_seenCardIds.contains(card.id);
    if (isFirstTimeSeeingCard) {
      _seenCardIds.add(card.id);
      _cardsSeenCount++;
    }

    // LEARNING MODE: Loop wrong answers until correct
    // MASTERY TEST: Fail-fast - end immediately on wrong answer
    if (_isMasteryTest) {
      // Mastery test - fail immediately on wrong answer
      if (!result.correct) {
        // Wrong answer = test ends immediately
        await _finishQuiz();
        return;
      }

      // Correct - move to next card
      _cardQueue.removeAt(_currentQueueIndex);

      if (_cardQueue.isEmpty) {
        await _finishQuiz();
        return;
      }

      if (_currentQueueIndex >= _cardQueue.length) {
        _currentQueueIndex = 0;
      }
    } else {
      // Learning mode - loop wrong answers
      if (result.correct) {
        // Correct - remove from queue
        _cardQueue.removeAt(_currentQueueIndex);

        if (_cardQueue.isEmpty) {
          await _finishQuiz();
          return;
        }

        if (_currentQueueIndex >= _cardQueue.length) {
          _currentQueueIndex = 0;
        }
      } else {
        // Wrong - move to end of queue for review
        _cardQueue.removeAt(_currentQueueIndex);
        _cardQueue.add(card);

        if (_currentQueueIndex >= _cardQueue.length) {
          _currentQueueIndex = 0;
        }

        // 🚨 NEW LOGIC: Check if user has seen all cards and scored ≤20%
        // If so, end the quiz early with encouragement to review
        if (_cardsSeenCount >= _totalCardsInDeck) {
          final correctCount =
              _cardResults.values.where((r) => r.correct).length;
          final scorePercent = _totalCardsInDeck > 0
              ? (correctCount / _totalCardsInDeck * 100)
              : 0;

          if (scorePercent <= 20) {
            // Score too low - end quiz and encourage review
            await _finishQuiz();
            return;
          }
        }
      }
    }

    // Animate to next card
    await _cardSlideCtrl.reverse();
    setState(() {
      _setupCard();
    });
    _cardSlideCtrl.forward();
  }

  void _onSkipCard() {
    final card = _cardQueue[_currentQueueIndex];

    // Track if this is the first time seeing this card
    final isFirstTimeSeeingCard = !_seenCardIds.contains(card.id);
    if (isFirstTimeSeeingCard) {
      _seenCardIds.add(card.id);
      _cardsSeenCount++;
    }

    // Mark as skipped
    final result = _cardResults[card.id]!;
    result.skipped = true;
    result.correct = false; // Counts as wrong

    // Remove from queue
    _cardQueue.removeAt(_currentQueueIndex);

    if (_cardQueue.isEmpty) {
      _finishQuiz();
      return;
    }

    if (_currentQueueIndex >= _cardQueue.length) {
      _currentQueueIndex = 0;
    }

    _advance();
  }

  Future<void> _finishQuiz() async {
    if (_attemptSaved) return;
    _attemptSaved = true;

    await _saveQuizAttempt();

    // Update mastery score if this was a mastery test
    if (_isMasteryTest) {
      await _updateMasteryScore();
    }

    // Calculate mastery test eligibility
    final isMasteryTestEligible = _isMasteryTestEligible;

    // Check if this was a low-score early exit (≤20%)
    final correctCount = _cardResults.values.where((r) => r.correct).length;
    final scorePercent =
        _totalCardsInDeck > 0 ? (correctCount / _totalCardsInDeck * 100) : 0;
    final isLowScoreExit = !_isMasteryTest &&
        _cardsSeenCount >= _totalCardsInDeck &&
        scorePercent <= 20;

    // Navigate to results screen with detailed breakdown
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(
      '/quiz-results',
      arguments: QuizResultsArgs(
        deckId: _deckId,
        deckTitle: _deckTitle,
        ownerUid: _quizOwnerUid,
        correctCount: correctCount,
        totalCount: _totalCardsInDeck,
        isMasteryTest: _isMasteryTest,
        isMasteryTestEligible: isMasteryTestEligible,
        isLowScoreExit: isLowScoreExit,
        clonedFromUsername: _clonedFromUsername,
        cardResults: _cardResults.values
            .map((r) => CardResultData(
                  question: r.question,
                  correct: r.correct,
                  repetitionsNeeded: r.repetitionsNeeded,
                  firstAttemptCorrect: r.firstAttemptCorrect,
                  skipped: r.skipped,
                ))
            .toList(),
      ),
    );
  }

  // Helper method to check mastery test eligibility
  bool get _isMasteryTestEligible {
    final hasSkippedCards = _cardResults.values.any((r) => r.skipped);
    final hasCardsWithThreePlusWrongAttempts =
        _cardResults.values.any((r) => r.wrongAttempts >= 3);
    return !hasSkippedCards && !hasCardsWithThreePlusWrongAttempts;
  }

  // ── Exit confirmation dialog ────────────────────────────────────────────────
  Future<void> _showExitConfirmation() async {
    final allCardsRevealed = _cardsSeenCount >= _totalCardsInDeck;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: AppColors.surfaceContainerLowest,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: allCardsRevealed
                    ? AppColors.primaryContainer.withOpacity(0.5)
                    : AppColors.errorContainer.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                allCardsRevealed ? Icons.save_rounded : Icons.warning_rounded,
                color: allCardsRevealed ? AppColors.primary : AppColors.error,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                allCardsRevealed
                    ? 'End Quiz & Save Progress?'
                    : 'Exit Without Saving?',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              allCardsRevealed
                  ? 'You\'ve revealed all cards in this deck! Your current progress will be saved. You can continue improving your score by studying more, or end the quiz now.'
                  : 'You haven\'t revealed all cards in this deck yet. Your progress will NOT be saved if you exit now.\n\nTo save your progress, you must reveal the entire deck at least once.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: AppColors.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            if (!allCardsRevealed) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Cards revealed: $_cardsSeenCount/$_totalCardsInDeck',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Keep Studying',
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  allCardsRevealed ? AppColors.primary : AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              allCardsRevealed ? 'Save & Exit' : 'Exit Anyway',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (result == true) {
      if (allCardsRevealed) {
        // Save progress and exit
        await _finishQuiz();
      } else {
        // Exit without saving
        if (!mounted) return;
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _saveQuizAttempt() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    if (currentUid == null || _deckId.isEmpty || _cardResults.isEmpty) {
      return;
    }

    final correct =
        _cardResults.values.where((result) => result.correct).length;
    final allCardsRevealed = _cardsSeenCount >= _totalCardsInDeck;

    try {
      await ProgressService.saveQuizAttempt(
        QuizAttemptInput(
          deckId: _deckId,
          deckTitle: _deckTitle,
          ownerUid: _quizOwnerUid ?? currentUid,
          category: _deckCategory,
          correctCount: correct,
          totalCount: _totalCardsInDeck,
          isComplete: allCardsRevealed,
          answers: _cardResults.values
              .map((result) => QuizCardAnswer(
                    cardId: result.cardId,
                    question: result.question,
                    correct: result.correct,
                    repetitionsNeeded: result.repetitionsNeeded,
                    firstAttemptCorrect: result.firstAttemptCorrect,
                    skipped: result.skipped,
                  ))
              .toList(),
        ),
      );
    } catch (e, st) {
      debugPrint('❌ [QuizScreen] failed to save progress: $e\n$st');
    }
  }

  // ── Track deck session start — fires immediately when any deck is opened ────
  // Writes / updates users/{uid}/recentSessions/{deckId}.
  // Uses merge: true so replaying the same deck just bumps lastPlayedAt
  // rather than creating a second document.
  Future<void> _trackDeckStarted() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _deckId.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('recentSessions')
          .doc(_deckId)
          .set({
        'deckId': _deckId,
        'deckTitle': _deckTitle,
        'category': _deckCategory,
        'lastPlayedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('✅ Tracked deck session: $_deckTitle ($_deckId)');
    } catch (e) {
      debugPrint('❌ Failed to track deck session: $e');
    }
  }

  Future<void> _updateMasteryScore() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null || _deckId.isEmpty) return;

    try {
      final correct = _cardResults.values.where((r) => r.correct).length;
      final masteryScore = _totalCardsInDeck > 0
          ? (correct / _totalCardsInDeck * 100).round()
          : 0;

      // Determine which user's deck to update (own deck vs public deck)
      final ownerUid = _quizOwnerUid ?? currentUid;

      final deckRef = FirebaseFirestore.instance
          .collection('users')
          .doc(ownerUid)
          .collection('decks')
          .doc(_deckId);

      // Get current highest score
      final deckSnap = await deckRef.get();
      final currentHighest =
          deckSnap.data()?['highestMasteryScore'] as int? ?? 0;

      await deckRef.update({
        'masteryScore': masteryScore,
        'lastMasteryTest': FieldValue.serverTimestamp(),
        'highestMasteryScore':
            masteryScore > currentHighest ? masteryScore : currentHighest,
      });

      debugPrint(
          '✅ Updated mastery score: $masteryScore% (highest: ${masteryScore > currentHighest ? masteryScore : currentHighest}%)');
    } catch (e) {
      debugPrint('❌ Failed to update mastery score: $e');
    }
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
    if (_cardQueue.isEmpty) {
      // All cards mastered during quiz - shouldn't happen but safety check
      _finishQuiz();
      return _buildLoading();
    }

    final card = _cardQueue[_currentQueueIndex];

    return SafeArea(
      child: Column(
        children: [
          // Top bar (fixed)
          _QuizTopBar(deckTitle: _deckTitle, isMasteryTest: _isMasteryTest),

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
                        cardsSeenCount: _cardsSeenCount,
                        totalCards: _totalCardsInDeck,
                        cardsNeedingReview: _cardsNeedingReview,
                      ),

                      // ── Quiz Timer badge (only shown when timer is on) ─────
                      if (_timerEnabled &&
                          !_cardSession.answered &&
                          !(_cardSession.showThinkFirstGate &&
                              !_cardSession.choicesRevealed))
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: _TimerBadge(secondsLeft: _timerSecondsLeft),
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
                        child: _cardSession.answered
                            ? Column(
                                children: [
                                  _NextDoneButton(
                                    isLast: _cardQueue.length == 1,
                                    isCorrect: _cardSession.isCorrect,
                                    isMasteryTest: _isMasteryTest,
                                    showEligibilitySparkle: !_isMasteryTest &&
                                        _cardQueue.length == 1 &&
                                        _cardSession.isCorrect &&
                                        _isMasteryTestEligible,
                                    onTap: _advance,
                                  ),
                                  if (_cardSession.canSkip &&
                                      !_cardSession.isCorrect &&
                                      !_isMasteryTest) ...[
                                    const SizedBox(height: 12),
                                    _SkipButton(onTap: _onSkipCard),
                                  ],
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),

                      const SizedBox(height: 40),
                      _MotivationalBubble(message: _motivationalMessage),
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
    // Only show the think-first gate on this card's true first showing
    if (_cardSession.showThinkFirstGate && !_cardSession.choicesRevealed) {
      // ── Phase 1: Think-first gate ──────────────────────────────────────────
      return Column(
        children: [
          _ThinkFirstBanner(),
          const SizedBox(height: 20),
          _RevealChoicesButton(
            onTap: () => setState(() {
              _cardSession.choicesRevealed = true;
              _startTimer(); // timer begins only now, after the gate is passed
            }),
          ),
        ],
      );
    }

    // ── Phase 2: Choices visible ─────────────────────────────────────────────
    return Column(
      children: List.generate(_cardSession.shuffledChoices.length, (i) {
        final originalIdx = _cardSession.shuffleMap[i];
        final isCorrectOption = originalIdx == card.correctIndex;
        final isUserChoice = _cardSession.selectedShuffledIndex == i;

        // Determine visual state
        _ChoiceState state = _ChoiceState.idle;
        if (_cardSession.answered) {
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
            label: _cardSession.shuffledChoices[i],
            state: state,
            onTap: _cardSession.answered ? null : () => _onChoiceTapped(i),
          ),
        );
      }),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // IDENTIFICATION SECTION
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildIdentificationSection() {
    final fieldColor = _cardSession.answered
        ? (_cardSession.isCorrect
            ? AppColors.primaryContainer.withOpacity(0.30)
            : AppColors.errorContainer.withOpacity(0.40))
        : AppColors.surfaceContainerLow;

    final borderSide = _cardSession.answered
        ? BorderSide(
            color: _cardSession.isCorrect ? AppColors.primary : AppColors.error,
            width: 2,
          )
        : BorderSide.none;

    final textColor = _cardSession.answered
        ? (_cardSession.isCorrect ? AppColors.primary : AppColors.error)
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
          enabled: !_cardSession.answered,
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
            if (!_cardSession.answered) _onCheckIdentification();
          },
        ),

        // ── Feedback after checking ─────────────────────────────────────────
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          child: _cardSession.answered
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 14),
                    if (_cardSession.isCorrect)
                      _IdentificationFeedback(
                        correct: true,
                        correctAnswer: '',
                      )
                    else
                      _IdentificationFeedback(
                        correct: false,
                        correctAnswer: _cardSession.correctAnswerReveal,
                      ),
                  ],
                )
              : const SizedBox.shrink(),
        ),

        // ── Check Answer button (disappears after answering) ─────────────────
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          child: !_cardSession.answered
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
          _QuizTopBar(deckTitle: _deckTitle, isMasteryTest: _isMasteryTest),
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
    final correct = _cardResults.values.where((r) => r.correct).length;
    final total = _totalCardsInDeck;
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
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
// SKIP BUTTON (appears after 2 failed attempts)
// ─────────────────────────────────────────────────────────────────────────────

class _SkipButton extends StatelessWidget {
  const _SkipButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.errorContainer.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.error.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.skip_next_rounded,
              color: AppColors.error,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              'Give Up on This Card',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QUIZ TOP BAR
// ─────────────────────────────────────────────────────────────────────────────

class _QuizTopBar extends StatelessWidget {
  const _QuizTopBar({required this.deckTitle, this.isMasteryTest = false});
  final String deckTitle;
  final bool isMasteryTest;

  @override
  Widget build(BuildContext context) {
    final quizState = context.findAncestorStateOfType<_QuizScreenState>();
    final allCardsRevealed = quizState != null &&
        quizState._cardsSeenCount >= quizState._totalCardsInDeck;

    return Container(
      color: AppColors.background.withOpacity(0.88),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Close button with dynamic color
          GestureDetector(
            onTap: () {
              if (quizState != null) {
                quizState._showExitConfirmation();
              } else {
                Navigator.of(context).pop();
              }
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: allCardsRevealed
                    ? AppColors.primaryContainer.withOpacity(0.5)
                    : AppColors.errorContainer.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                allCardsRevealed
                    ? Icons.check_circle_rounded
                    : Icons.close_rounded,
                color: allCardsRevealed ? AppColors.primary : AppColors.error,
                size: 20,
              ),
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

          // Mode badge (Focus for learning, Mastery for test)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isMasteryTest
                  ? AppColors.tertiaryContainer.withOpacity(0.6)
                  : AppColors.primaryContainer.withOpacity(0.5),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                Icon(
                  isMasteryTest
                      ? Icons.emoji_events_rounded
                      : Icons.center_focus_strong_rounded,
                  color: isMasteryTest ? AppColors.tertiary : AppColors.primary,
                  size: 14,
                ),
                const SizedBox(width: 5),
                Text(
                  isMasteryTest ? 'MASTERY' : 'FOCUS',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color:
                        isMasteryTest ? AppColors.tertiary : AppColors.primary,
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
  const _ProgressHeader({
    required this.cardsSeenCount,
    required this.totalCards,
    required this.cardsNeedingReview,
  });

  final int cardsSeenCount;
  final int totalCards;
  final int cardsNeedingReview;

  @override
  Widget build(BuildContext context) {
    final progressPercent =
        totalCards > 0 ? (cardsSeenCount / totalCards * 100).round() : 0;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Card $cardsSeenCount of $totalCards',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                letterSpacing: 0.8,
              ),
            ),
            if (cardsNeedingReview > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.secondaryContainer.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.secondary.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.repeat_rounded,
                      color: AppColors.secondary,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$cardsNeedingReview to review',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
              )
            else
              Text(
                '$progressPercent% done',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _DualProgressBar(
          cardsSeenCount: cardsSeenCount,
          totalCards: totalCards,
          cardsNeedingReview: cardsNeedingReview,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DUAL PROGRESS BAR (shows completed + needs review)
// ─────────────────────────────────────────────────────────────────────────────

class _DualProgressBar extends StatelessWidget {
  const _DualProgressBar({
    required this.cardsSeenCount,
    required this.totalCards,
    required this.cardsNeedingReview,
  });

  final int cardsSeenCount;
  final int totalCards;
  final int cardsNeedingReview;

  @override
  Widget build(BuildContext context) {
    if (totalCards == 0) {
      return const SizedBox.shrink();
    }

    final cardsMastered = cardsSeenCount - cardsNeedingReview;
    final masteredProgress = cardsMastered / totalCards;
    final reviewProgress = cardsNeedingReview / totalCards;

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 10,
        child: Stack(
          children: [
            // Background (not yet seen)
            Container(
              width: double.infinity,
              color: AppColors.outlineVariant.withOpacity(0.22),
            ),

            // Animated progress
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: masteredProgress + reviewProgress),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              builder: (_, totalValue, __) => Row(
                children: [
                  // Mastered cards (green/primary)
                  if (masteredProgress > 0)
                    Expanded(
                      flex: (masteredProgress * 1000).round(),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOutCubic,
                        builder: (_, value, __) => Container(
                          color: AppColors.primary.withOpacity(value),
                        ),
                      ),
                    ),

                  // Cards needing review (orange/secondary)
                  if (reviewProgress > 0)
                    Expanded(
                      flex: (reviewProgress * 1000).round(),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOutCubic,
                        builder: (_, value, __) => Container(
                          color: AppColors.secondary.withOpacity(value * 0.8),
                        ),
                      ),
                    ),

                  // Remaining space
                  if (masteredProgress + reviewProgress < 1)
                    Expanded(
                      flex: ((1 - masteredProgress - reviewProgress) * 1000)
                          .round(),
                      child: const SizedBox.shrink(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
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
        trailingIcon =
            const Icon(Icons.cancel_rounded, color: AppColors.error, size: 22);
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
          border: Border.all(
              color: AppColors.primary.withOpacity(0.40), width: 1.5),
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
        border:
            Border.all(color: AppColors.error.withOpacity(0.35), width: 1.5),
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withOpacity(0.40),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.primary.withOpacity(0.35), width: 1.5),
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
  const _NextDoneButton({
    required this.isLast,
    required this.isCorrect,
    required this.onTap,
    this.isMasteryTest = false,
    this.showEligibilitySparkle = false,
  });
  final bool isLast;
  final bool isCorrect;
  final VoidCallback onTap;
  final bool isMasteryTest;
  final bool showEligibilitySparkle;

  @override
  Widget build(BuildContext context) {
    // Determine button text and style
    String buttonText;
    IconData buttonIcon;
    List<Color> gradientColors;

    if (isMasteryTest) {
      // MASTERY TEST MODE
      if (isCorrect) {
        // Correct answer
        if (isLast) {
          buttonText = 'Finish Quiz';
          buttonIcon = Icons.flag_rounded;
          gradientColors = [AppColors.tertiary, const Color(0xFFEBC23E)];
        } else {
          buttonText = 'Next Card';
          buttonIcon = Icons.arrow_forward_rounded;
          gradientColors = [AppColors.tertiary, const Color(0xFFEBC23E)];
        }
      } else {
        // Wrong answer - test failed
        buttonText = 'View Results';
        buttonIcon = Icons.assessment_rounded;
        gradientColors = [AppColors.error, const Color(0xFFD32F2F)];
      }
    } else {
      // LEARNING MODE
      if (isLast) {
        if (isCorrect) {
          // Last card + correct = Finish
          buttonText = 'Finish Quiz';
          buttonIcon = Icons.flag_rounded;
          gradientColors = [AppColors.tertiary, const Color(0xFFEBC23E)];
        } else {
          // Last card + wrong = Retry
          buttonText = 'Retry';
          buttonIcon = Icons.refresh_rounded;
          gradientColors = [AppColors.secondary, AppColors.secondaryFixedDim];
        }
      } else {
        // Not last card = Next
        buttonText = 'Next Card';
        buttonIcon = Icons.navigate_next_rounded;
        gradientColors = [AppColors.secondary, AppColors.secondaryFixedDim];
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: gradientColors[0].withOpacity(0.25),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Main button content (centered)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  buttonText,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  buttonIcon,
                  color: Colors.white,
                  size: 22,
                ),
              ],
            ),
            // Sparkle at the right edge (learning mode eligibility indicator)
            if (showEligibilitySparkle)
              Positioned(
                right: 20,
                top: 0,
                bottom: 0,
                child: Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutBack,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white.withOpacity(0.9),
                          size: 18,
                        ),
                      );
                    },
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
// MOTIVATIONAL BUBBLE
// ─────────────────────────────────────────────────────────────────────────────

// Module-level so the rotation interval logic in _QuizScreenState can pick
// from it directly without instantiating the widget.
const List<String> _motivationalMessages = [
  '"Active recall is the single most effective study technique. You\'ve got this!"',
  '"Each card you review today saves you hours of cramming tomorrow."',
  '"Struggle a little — that\'s your brain building new pathways!"',
  '"Consistency beats intensity. Keep going, one card at a time."',
];

class _MotivationalBubble extends StatelessWidget {
  const _MotivationalBubble({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
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
            border:
                Border.all(color: AppColors.surfaceContainerLowest, width: 2),
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
              message,
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
// QUIZ TIMER BADGE  — shown above the question when the timer is enabled.
// Turns orange at ≤8 s and red at ≤4 s so urgency is visually clear.
// ─────────────────────────────────────────────────────────────────────────────

class _TimerBadge extends StatelessWidget {
  const _TimerBadge({required this.secondsLeft});
  final int secondsLeft;

  @override
  Widget build(BuildContext context) {
    final isUrgent = secondsLeft <= 4;
    final isWarning = secondsLeft <= 8 && secondsLeft > 4;

    final Color color = isUrgent
        ? AppColors.error
        : isWarning
            ? const Color(0xFFE67E22) // orange
            : AppColors.primary;

    final double progress = secondsLeft / 15.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Icon + label + countdown — no background, just text and icon
        Row(
          children: [
            Icon(Icons.timer_rounded, color: color, size: 15),
            const SizedBox(width: 6),
            Text(
              isUrgent
                  ? 'Time\'s almost up!'
                  : isWarning
                      ? 'Hurry up!'
                      : 'Time remaining',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.3,
              ),
            ),
            const Spacer(),
            Text(
              '${secondsLeft}s',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Bare progress bar — no container wrapping it
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            backgroundColor: color.withOpacity(0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
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
