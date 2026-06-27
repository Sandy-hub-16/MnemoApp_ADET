import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../landing_page/app_theme.dart';
import '../../../business-layer/services/deck_service.dart';
import '../../widgets/app_spinner.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CREATE DECK SCREEN  —  route: /create-deck
//
// TWO-PHASE FLOW:
//   Phase 1 — Deck Setup   : name, subject tag, target card count
//   Phase 2 — Card Editor  : build cards one by one (Multiple Choice OR Identification)
//
// DRAFT FLOW:
//   • User may leave during Phase 2. A 3-button dialog appears:
//       [Stay]  [Save Draft]  [Discard]
//   • "Save Draft" calls DeckService.saveDraft() (new deck) or
//     DeckService.updateDraft() (updating an existing draft), then pops.
//   • Draft decks land in Firestore with isDraft:true.
//   • Continuing a draft passes ContinueDraftArgs via route arguments.
//     didChangeDependencies() detects args, pre-populates all state, and
//     jumps straight to Phase 2.
//   • When the user finishes and taps "Save Deck" on a draft,
//     DeckService.completeDraft() clears isDraft and writes the final cards.
//
// CARD MODEL:
//   Each _CardData can be either MultipleChoice (question + 4 choices + correct
//   index) or Identification (question + exact-match answer string).
//   Both types are stored together in the same deck and serialised to Firestore
//   with a `type` field so the quiz screen can branch its UI accordingly.
//
// 🎨 FRONTEND NOTE:
//   All state is local to _CreateDeckScreenState.
//   Wire _onSaveDeck() to DeckService.createDeck() — already done below.
//   The quiz screen reads 'type', 'choices', 'correctIndex', and 'answer' fields.
// ─────────────────────────────────────────────────────────────────────────────

// ── Enums & Data Models ──────────────────────────────────────────────────────

enum CardType { multipleChoice, identification }

class _CardData {
  _CardData({required this.id})
      : type = CardType.multipleChoice,
        question = '',
        choices = ['', '', '', ''],
        correctIndex = null,
        answer = '';

  /// Reconstruct a saved card from a Firestore map (used when continuing a draft).
  factory _CardData.fromMap(
      {required String id, required Map<String, dynamic> map}) {
    final card = _CardData(id: id);
    final rawType = map['type'] as String? ?? 'multiple_choice';
    card.type = rawType == 'identification'
        ? CardType.identification
        : CardType.multipleChoice;
    card.question = map['question'] as String? ?? '';
    if (card.type == CardType.multipleChoice) {
      final raw = map['choices'];
      if (raw is List) {
        card.choices = raw.map((e) => e.toString()).toList();
        // Pad / trim to exactly 4 entries
        while (card.choices.length < 4) card.choices.add('');
        if (card.choices.length > 4) card.choices = card.choices.sublist(0, 4);
      }
      card.correctIndex = map['correctIndex'] as int?;
    } else {
      card.answer = map['answer'] as String? ?? '';
    }
    return card;
  }

  final String id;
  CardType type;
  String question;
  List<String> choices; // always length-4; only used for multipleChoice
  int? correctIndex; // null = user hasn't chosen yet; 0-3 once chosen
  String answer; // exact-match string; only used for identification

  /// True when enough data exists to count this card as "saved"
  bool get isComplete {
    if (question.trim().isEmpty) return false;
    if (type == CardType.identification) return answer.trim().isNotEmpty;
    // multipleChoice: question + correctIndex selected + all 4 choices filled
    if (correctIndex == null) return false;
    return choices.every((c) => c.trim().isNotEmpty);
  }

  Map<String, dynamic> toMap() {
    if (type == CardType.multipleChoice) {
      final idx = correctIndex ?? 0;
      return {
        'type': 'multiple_choice',
        'question': question.trim(),
        'choices': choices.map((c) => c.trim()).toList(),
        'correctIndex': idx,
        'answer': choices[idx].trim(),
      };
    } else {
      return {
        'type': 'identification',
        'question': question.trim(),
        'answer': answer.trim(),
      };
    }
  }
}

// ── Route Arguments ──────────────────────────────────────────────────────────

/// Passed via Navigator.pushNamed('/create-deck', arguments: ContinueDraftArgs(...))
/// when the user taps "Continue Draft" from the deck hub.
class ContinueDraftArgs {
  const ContinueDraftArgs({
    required this.draftId,
    required this.title,
    required this.tag,
    required this.targetCardCount,
    required this.savedCards,
  });

  /// Firestore document ID of the existing draft.
  final String draftId;
  final String title;
  final String tag;
  final int targetCardCount;

  /// Already-saved card maps fetched from Firestore. The editor will
  /// pre-populate these so the user picks up exactly where they left off.
  final List<Map<String, dynamic>> savedCards;
}

// ── Screen ────────────────────────────────────────────────────────────────────

enum _Phase { setup, editor }

class CreateDeckScreen extends StatefulWidget {
  const CreateDeckScreen({super.key});

  @override
  State<CreateDeckScreen> createState() => _CreateDeckScreenState();
}

class _CreateDeckScreenState extends State<CreateDeckScreen>
    with TickerProviderStateMixin {
  // ── Phase 1 state ──────────────────────────────────────────────────────────
  _Phase _phase = _Phase.setup;
  final _titleController = TextEditingController();
  int _selectedTagIndex = 0;
  int _targetCardCount = 10;

  static const _tags = [
    'Biology',
    'Physics',
    'Organic Chem',
    'World History',
    'History',
    'Math',
    'Other',
  ];

  // ── Phase 2 state ──────────────────────────────────────────────────────────
  late List<_CardData> _cards;
  int _currentCardIndex = 0;
  late AnimationController _phaseTransitionCtrl;

  // ── Draft state ────────────────────────────────────────────────────────────
  /// Non-null while editing (or continuing) a draft. Set when:
  ///   (a) user arrives via ContinueDraftArgs, or
  ///   (b) user saves a draft for the first time (DeckService returns the new id).
  String? _draftId;

  /// Guards didChangeDependencies so we only parse route args once.
  bool _argsLoaded = false;

  // ── Saving state ───────────────────────────────────────────────────────────
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _phaseTransitionCtrl = AnimationController(
      duration: const Duration(milliseconds: 340),
      vsync: this,
    );
    // Initialise _cards to a valid list so late is satisfied before
    // didChangeDependencies runs (which may replace it with draft data).
    _cards = List.generate(
      _targetCardCount,
      (i) => _CardData(id: '${DateTime.now().millisecondsSinceEpoch}_$i'),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsLoaded) return;
    _argsLoaded = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! ContinueDraftArgs) return;

    // ── Pre-populate from draft ──────────────────────────────────────────
    _draftId = args.draftId;
    _titleController.text = args.title;

    final tagIdx = _tags.indexOf(args.tag);
    _selectedTagIndex = tagIdx == -1 ? 0 : tagIdx;
    _targetCardCount = args.targetCardCount;

    // Build card list: restore saved cards, append blank slots for the rest.
    _cards = List.generate(args.targetCardCount, (i) {
      if (i < args.savedCards.length) {
        return _CardData.fromMap(
          id: '${DateTime.now().millisecondsSinceEpoch}_$i',
          map: args.savedCards[i],
        );
      }
      return _CardData(id: '${DateTime.now().millisecondsSinceEpoch}_$i');
    });

    // Jump directly to the editor and position at first incomplete card.
    _currentCardIndex =
        _cards.indexWhere((c) => !c.isComplete).clamp(0, _cards.length - 1);
    _phase = _Phase.editor;
    _phaseTransitionCtrl.value = 1.0; // animation already "done"
  }

  @override
  void dispose() {
    _titleController.dispose();
    _phaseTransitionCtrl.dispose();
    super.dispose();
  }

  // ── Phase transition ───────────────────────────────────────────────────────

  void _startEditing() {
    if (_titleController.text.trim().isEmpty) return;

    _cards = List.generate(
      _targetCardCount,
      (i) => _CardData(id: '${DateTime.now().millisecondsSinceEpoch}_$i'),
    );
    _currentCardIndex = 0;

    setState(() => _phase = _Phase.editor);
    _phaseTransitionCtrl.forward(from: 0);
  }

  // ── Card navigation ────────────────────────────────────────────────────────

  void _goToPrevCard() {
    if (_currentCardIndex > 0) {
      setState(() => _currentCardIndex--);
    }
  }

  void _goToNextCard() {
    if (_currentCardIndex < _cards.length - 1) {
      final currentType = _cards[_currentCardIndex].type;
      final nextCard = _cards[_currentCardIndex + 1];
      // Carry the current card's type to the next card only if it is still
      // untouched (question empty), so the user doesn't lose a type they
      // already chose on a card they visited earlier.
      if (nextCard.question.isEmpty) {
        nextCard.type = currentType;
      }
      setState(() => _currentCardIndex++);
    }
  }

  // ── Save Draft ─────────────────────────────────────────────────────────────

  Future<void> _onSaveDraft() async {
    if (_isSaving) return;

    // ── SAVE DRAFT STATE FOR ROLLBACK ──────────────────────────────────────
    final draftIdBefore = _draftId;

    // ── OPTIMISTICALLY MARK AS SAVING ─────────────────────────────────────
    setState(() => _isSaving = true);

    // ── SHOW SAVING INDICATOR ──────────────────────────────────────────────
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Saving draft...',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFFB45309),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      ),
    );

    final completedCards = _cards.where((c) => c.isComplete).toList();
    final cardMaps = completedCards.map((c) => c.toMap()).toList();

    try {
      if (_draftId != null) {
        // Update the existing draft document in place.
        await DeckService.updateDraft(
          draftId: _draftId!,
          cards: cardMaps,
        );
      } else {
        // First time saving — create the Firestore doc and store its id so
        // that any subsequent save/complete in the same session can reuse it.
        final newId = await DeckService.saveDraft(
          title: _titleController.text.trim(),
          tag: _tags[_selectedTagIndex],
          targetCardCount: _targetCardCount,
          cards: cardMaps,
        );
        // ── OPTIMISTICALLY UPDATE DRAFT ID ────────────────────────────────
        setState(() => _draftId = newId);
      }

      if (!mounted) return;

      // ── SUCCESS: SHOW SUCCESS MESSAGE ──────────────────────────────────
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Draft saved — ${completedCards.length} card${completedCards.length == 1 ? '' : 's'} preserved.',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFFB45309),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        ),
      );

      if (mounted) {
        setState(() => _isSaving = false);
        // Delay pop to let user see success message
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      // ── ERROR: REVERT DRAFT ID ────────────────────────────────────────
      debugPrint('Draft save error: $e');
      if (mounted) {
        setState(() {
          _draftId = draftIdBefore;
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not save draft: $e',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      }
    }
  }

  // ── Save Deck (complete) ───────────────────────────────────────────────────

  bool get _canSave {
    if (_titleController.text.trim().isEmpty) return false;
    // ALL cards must be complete to save as a finished deck.
    return _cards.every((c) => c.isComplete);
  }

  Future<void> _onSaveDeck() async {
    if (!_canSave || _isSaving) return;

    // ── OPTIMISTICALLY MARK AS SAVING ─────────────────────────────────────
    setState(() => _isSaving = true);

    // ── SHOW SAVING INDICATOR ──────────────────────────────────────────────
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Saving deck...',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      ),
    );

    final completedCards = _cards.where((c) => c.isComplete).toList();
    final cardMaps = completedCards.map((c) => c.toMap()).toList();

    try {
      if (_draftId != null) {
        // Completing a draft: flip isDraft → false and write final cards.
        await DeckService.completeDraft(
          draftId: _draftId!,
          title: _titleController.text.trim(),
          tag: _tags[_selectedTagIndex],
          cards: cardMaps,
        );
      } else {
        // Brand-new deck (no draft state).
        await DeckService.createDeck(
          title: _titleController.text.trim(),
          tag: _tags[_selectedTagIndex],
          cards: cardMaps,
        );
      }

      if (!mounted) return;

      // ── SUCCESS: SHOW SUCCESS MESSAGE ──────────────────────────────────
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${completedCards.length} card${completedCards.length == 1 ? '' : 's'} saved!',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );

      if (mounted) {
        setState(() => _isSaving = false);
        // Delay navigation to let user see success message
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/decks',
            (route) => false,
          );
        }
      }
    } catch (e) {
      // ── ERROR: REVERT SAVING STATE ────────────────────────────────────
      debugPrint('Deck save error: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e',
                style:
                    GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      }
    }
  }

  // ── Back handler ───────────────────────────────────────────────────────────

  Future<bool> _onWillPop() async {
    if (_phase == _Phase.editor) {
      // Show the 3-option "Leave Deck?" dialog.
      final result = await showDialog<_LeaveAction>(
        context: context,
        builder: (ctx) => _LeaveDeckDialog(ctx, hasDraft: _draftId != null),
      );

      switch (result) {
        case _LeaveAction.stay:
        case null:
          // Stay in the editor — do nothing.
          return false;

        case _LeaveAction.saveDraft:
          await _onSaveDraft();
          return false; // _onSaveDraft pops after saving

        case _LeaveAction.discard:
          // Discard & go back to setup (or pop if we came from the deck hub).
          if (_draftId != null) {
            // We were continuing an existing draft — just leave without saving.
            Navigator.of(context).pop();
            return false;
          }
          setState(() {
            _phase = _Phase.setup;
            _phaseTransitionCtrl.reverse();
          });
          return false;
      }
    }
    return true;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            // ── Decorative blobs ─────────────────────────────────────────
            const Positioned(
              top: -60,
              right: -100,
              child: _Blob(size: 340, color: Color(0x1257FDC8)),
            ),
            const Positioned(
              bottom: 160,
              left: -120,
              child: _Blob(size: 300, color: Color(0x14C2E8FF)),
            ),
            const Positioned(
              top: 300,
              right: -60,
              child: _Blob(size: 200, color: Color(0x0EFFE087)),
            ),

            // ── Phases ───────────────────────────────────────────────────
            SafeArea(
              bottom: false,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.04, 0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                        parent: anim, curve: Curves.easeOutCubic)),
                    child: child,
                  ),
                ),
                child: _phase == _Phase.setup
                    ? _SetupPhase(
                        key: const ValueKey('setup'),
                        titleController: _titleController,
                        tags: _tags,
                        selectedTagIndex: _selectedTagIndex,
                        targetCardCount: _targetCardCount,
                        onTagSelected: (i) =>
                            setState(() => _selectedTagIndex = i),
                        onCardCountChanged: (v) =>
                            setState(() => _targetCardCount = v),
                        onBack: () => Navigator.pop(context),
                        onStart: _startEditing,
                        onTitleChanged: (_) => setState(() {}),
                      )
                    : _EditorPhase(
                        key: const ValueKey('editor'),
                        cards: _cards,
                        currentIndex: _currentCardIndex,
                        canSave: _canSave,
                        isSaving: _isSaving,
                        onCardChanged: () => setState(() {}),
                        onPrev: _goToPrevCard,
                        onNext: _goToNextCard,
                        onSave: _onSaveDeck,
                        onSaveDraft: _onSaveDraft,
                        onBack: () => _onWillPop(),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PHASE 1 — DECK SETUP
// ═════════════════════════════════════════════════════════════════════════════

class _SetupPhase extends StatelessWidget {
  const _SetupPhase({
    super.key,
    required this.titleController,
    required this.tags,
    required this.selectedTagIndex,
    required this.targetCardCount,
    required this.onTagSelected,
    required this.onCardCountChanged,
    required this.onBack,
    required this.onStart,
    required this.onTitleChanged,
  });

  final TextEditingController titleController;
  final List<String> tags;
  final int selectedTagIndex;
  final int targetCardCount;
  final ValueChanged<int> onTagSelected;
  final ValueChanged<int> onCardCountChanged;
  final VoidCallback onBack;
  final VoidCallback onStart;
  final ValueChanged<String> onTitleChanged;

  bool get _canProceed => titleController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Top bar ─────────────────────────────────────────────────────
        _TopBar(
          title: 'Create Deck',
          onBack: onBack,
          trailing: const SizedBox(width: 36),
        ),

        Expanded(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // ── Hero title ────────────────────────────────────
                    Text(
                      'New Deck',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface,
                        letterSpacing: -1.0,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Let's build your next learning milestone.",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        color: AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 36),

                    // ── Deck name ─────────────────────────────────────
                    _SetupFieldLabel(label: 'Deck Name'),
                    const SizedBox(height: 8),
                    _DeckNameField(
                      controller: titleController,
                      onChanged: onTitleChanged,
                    ),
                    const SizedBox(height: 28),

                    // ── Subject tag ───────────────────────────────────
                    _SetupFieldLabel(label: 'Subject'),
                    const SizedBox(height: 10),
                    _SubjectChips(
                      tags: tags,
                      selectedIndex: selectedTagIndex,
                      onSelected: onTagSelected,
                    ),
                    const SizedBox(height: 28),

                    // ── Card count slider ─────────────────────────────
                    _SetupFieldLabel(label: 'Target Cards'),
                    const SizedBox(height: 12),
                    _CardCountSlider(
                      value: targetCardCount,
                      onChanged: onCardCountChanged,
                    ),
                    const SizedBox(height: 44),

                    // ── CTA button ────────────────────────────────────
                    _PrimaryButton(
                      label: 'Start Adding Cards',
                      icon: Icons.add_circle_rounded,
                      enabled: _canProceed,
                      onTap: onStart,
                    ),

                    const SizedBox(height: 32),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PHASE 2 — CARD EDITOR
// ═════════════════════════════════════════════════════════════════════════════

class _EditorPhase extends StatelessWidget {
  const _EditorPhase({
    super.key,
    required this.cards,
    required this.currentIndex,
    required this.canSave,
    required this.isSaving,
    required this.onCardChanged,
    required this.onPrev,
    required this.onNext,
    required this.onSave,
    required this.onSaveDraft,
    required this.onBack,
  });

  final List<_CardData> cards;
  final int currentIndex;
  final bool canSave;
  final bool isSaving;
  final VoidCallback onCardChanged;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onSave;
  final VoidCallback onSaveDraft;
  final VoidCallback onBack;

  _CardData get _current => cards[currentIndex];
  double get _progress => (currentIndex + 1) / cards.length;
  int get _completedCount => cards.where((c) => c.isComplete).length;
  bool get _currentCardComplete => _current.isComplete;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Top bar with progress ──────────────────────────────────────
        _EditorTopBar(
          currentIndex: currentIndex,
          total: cards.length,
          progress: _progress,
          canSave: canSave,
          completedCount: _completedCount,
          onBack: onBack,
          onSave: onSave,
          onSaveDraft: onSaveDraft,
        ),

        Expanded(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // ── Card type toggle ──────────────────────────────
                    _CardTypeToggle(
                      type: _current.type,
                      onChanged: (t) {
                        _current.type = t;
                        onCardChanged();
                      },
                    ),
                    const SizedBox(height: 16),

                    // ── Card editor container ─────────────────────────
                    _CardEditorContainer(
                      card: _current,
                      onChanged: onCardChanged,
                    ),
                    const SizedBox(height: 20),

                    // ── Dot progress indicator ────────────────────────
                    _DotIndicator(
                      cards: cards,
                      currentIndex: currentIndex,
                    ),
                    const SizedBox(height: 20),

                    // ── Navigation buttons ────────────────────────────
                    _NavigationButtons(
                      canGoPrev: currentIndex > 0,
                      // Next is only enabled when the current card is fully filled.
                      canGoNext: currentIndex < cards.length - 1 &&
                          _currentCardComplete,
                      showSave: currentIndex == cards.length - 1 && canSave,
                      canSave: canSave,
                      isSaving: isSaving,
                      onPrev: onPrev,
                      onNext: onNext,
                      onSave: onSave,
                    ),
                    const SizedBox(height: 48),
                  ]),
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
// The widgets below (_TopBar, _EditorTopBar, _SetupFieldLabel, _DeckNameField,
// _SubjectChips, _CardCountSlider, _PrimaryButton, _CardTypeToggle,
// _CardEditorContainer, _MultipleChoiceEditor, _IdentificationEditor,
// _NavigationButtons, _DotIndicator, _CircleIconButton, _Blob) are unchanged
// from the original file. Only the state layer above was modified.
// ─────────────────────────────────────────────────────────────────────────────

// ── Leave Action Enum ─────────────────────────────────────────────────────────

enum _LeaveAction { stay, saveDraft, discard }

// ── Leave Deck Dialog ─────────────────────────────────────────────────────────
//
// Replaces the old _DiscardDialog. Shows three choices:
//   • Stay      — keep editing
//   • Save Draft — persist progress and leave
//   • Discard   — abandon changes and leave
//
// When the user is already working on a known draft (hasDraft == true), the
// "Discard" label changes to "Leave Without Saving" so intent is crystal-clear.

AlertDialog _LeaveDeckDialog(BuildContext ctx, {required bool hasDraft}) =>
    AlertDialog(
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        'Leave Deck?',
        style: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w800,
          color: AppColors.onSurface,
          fontSize: 18,
        ),
      ),
      content: Text(
        hasDraft
            ? 'You can save your current progress to continue later, or leave without saving.'
            : 'Save your progress as a draft to continue later, or discard everything.',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          color: AppColors.onSurfaceVariant,
          height: 1.5,
        ),
      ),
      actions: [
        // ── Stay ──────────────────────────────────────────────────────────
        TextButton(
          onPressed: () => Navigator.pop(ctx, _LeaveAction.stay),
          child: Text(
            'Stay',
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),

        // ── Save Draft ────────────────────────────────────────────────────
        TextButton(
          onPressed: () => Navigator.pop(ctx, _LeaveAction.saveDraft),
          style: TextButton.styleFrom(
            backgroundColor: const Color(0xFFFEF3C7),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          ),
          child: Text(
            'Save Draft',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFFB45309),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),

        // ── Discard / Leave Without Saving ────────────────────────────────
        TextButton(
          onPressed: () => Navigator.pop(ctx, _LeaveAction.discard),
          child: Text(
            hasDraft ? 'Leave Without Saving' : 'Discard',
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );

// ── Top Bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.onBack,
    required this.trailing,
  });

  final String title;
  final VoidCallback onBack;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
      child: Row(
        children: [
          _CircleIconButton(icon: Icons.arrow_back_rounded, onTap: onBack),
          Expanded(
            child: Center(
              child: Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface,
                ),
              ),
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

// ── Editor Top Bar (with progress) ────────────────────────────────────────────

class _EditorTopBar extends StatelessWidget {
  const _EditorTopBar({
    required this.currentIndex,
    required this.total,
    required this.progress,
    required this.canSave,
    required this.completedCount,
    required this.onBack,
    required this.onSave,
    required this.onSaveDraft,
  });

  final int currentIndex;
  final int total;
  final double progress;
  final bool canSave;
  final int completedCount;
  final VoidCallback onBack;
  final VoidCallback onSave;
  final VoidCallback onSaveDraft;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              _CircleIconButton(icon: Icons.arrow_back_rounded, onTap: onBack),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Card ${currentIndex + 1} of $total',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    Text(
                      '$completedCount card${completedCount == 1 ? '' : 's'} complete',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Always show a save button. When all cards are complete it saves
              // the deck; otherwise it saves the current progress as a draft.
              GestureDetector(
                onTap: canSave ? onSave : onSaveDraft,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: canSave
                        ? const LinearGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.primaryFixedDim
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: canSave ? null : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    canSave ? 'Save Deck' : 'Save Draft',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: canSave
                          ? AppColors.onPrimary
                          : const Color(0xFFB45309),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: AppColors.outlineVariant.withOpacity(0.3),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ── Setup Field Label ─────────────────────────────────────────────────────────

class _SetupFieldLabel extends StatelessWidget {
  const _SetupFieldLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.onSurfaceVariant,
        letterSpacing: 0.4,
      ),
    );
  }
}

// ── Deck Name Field ───────────────────────────────────────────────────────────

class _DeckNameField extends StatelessWidget {
  const _DeckNameField({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.onSurface,
      ),
      decoration: InputDecoration(
        hintText: 'e.g. Cell Biology Chapter 3',
        hintStyle: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          color: AppColors.outline,
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }
}

// ── Subject Chips ─────────────────────────────────────────────────────────────

class _SubjectChips extends StatelessWidget {
  const _SubjectChips({
    required this.tags,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> tags;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(tags.length, (i) {
        final selected = i == selectedIndex;
        return GestureDetector(
          onTap: () => onSelected(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primaryContainer
                  : AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected
                    ? AppColors.primary.withOpacity(0.4)
                    : AppColors.outlineVariant.withOpacity(0.5),
              ),
            ),
            child: Text(
              tags[i],
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color:
                    selected ? AppColors.primary : AppColors.onSurfaceVariant,
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ── Card Count Slider ─────────────────────────────────────────────────────────

class _CardCountSlider extends StatelessWidget {
  const _CardCountSlider({
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  // Manual deck creation limits
  static const int _minManualCards = 10;
  static const int _maxManualCards = 50;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$value cards',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            Text(
              'Min $_minManualCards · Max $_maxManualCards',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 6,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: AppColors.outlineVariant.withOpacity(0.3),
            thumbColor: AppColors.primary,
            overlayColor: AppColors.primary.withOpacity(0.12),
          ),
          child: Slider(
            value: value.toDouble(),
            min: _minManualCards.toDouble(),
            max: _maxManualCards.toDouble(),
            divisions: _maxManualCards - _minManualCards,
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
      ],
    );
  }
}

// ── Primary Button ────────────────────────────────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: enabled
              ? const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryFixedDim],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: enabled ? null : AppColors.outlineVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(999),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.30),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: enabled ? AppColors.onPrimary : AppColors.outline,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              icon,
              color: enabled ? AppColors.onPrimary : AppColors.outline,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Card Type Toggle ──────────────────────────────────────────────────────────

class _CardTypeToggle extends StatelessWidget {
  const _CardTypeToggle({
    required this.type,
    required this.onChanged,
  });

  final CardType type;
  final ValueChanged<CardType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _TypeTab(
            label: 'Multiple Choice',
            icon: Icons.check_circle_outline_rounded,
            selected: type == CardType.multipleChoice,
            onTap: () => onChanged(CardType.multipleChoice),
          ),
          const SizedBox(width: 4),
          _TypeTab(
            label: 'Identification',
            icon: Icons.edit_outlined,
            selected: type == CardType.identification,
            onTap: () => onChanged(CardType.identification),
          ),
        ],
      ),
    );
  }
}

class _TypeTab extends StatelessWidget {
  const _TypeTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.surfaceContainerLowest
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.onSurface.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color:
                    selected ? AppColors.primary : AppColors.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color:
                      selected ? AppColors.primary : AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Card Editor Container ─────────────────────────────────────────────────────

class _CardEditorContainer extends StatelessWidget {
  const _CardEditorContainer({
    required this.card,
    required this.onChanged,
  });

  final _CardData card;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
            child: child,
          ),
        ),
        child: card.type == CardType.multipleChoice
            ? _MultipleChoiceEditor(
                key: ValueKey('mc_${card.id}'),
                card: card,
                onChanged: onChanged,
              )
            : _IdentificationEditor(
                key: ValueKey('id_${card.id}'),
                card: card,
                onChanged: onChanged,
              ),
      ),
    );
  }
}

// ── Multiple Choice Editor ────────────────────────────────────────────────────

class _MultipleChoiceEditor extends StatefulWidget {
  const _MultipleChoiceEditor(
      {super.key, required this.card, required this.onChanged});
  final _CardData card;
  final VoidCallback onChanged;

  @override
  State<_MultipleChoiceEditor> createState() => _MultipleChoiceEditorState();
}

class _MultipleChoiceEditorState extends State<_MultipleChoiceEditor> {
  late final TextEditingController _qCtrl;
  late final List<TextEditingController> _cCtrls;

  @override
  void initState() {
    super.initState();
    _qCtrl = TextEditingController(text: widget.card.question);
    _cCtrls = List.generate(
        4, (i) => TextEditingController(text: widget.card.choices[i]));
  }

  @override
  void dispose() {
    _qCtrl.dispose();
    for (final c in _cCtrls) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CardFieldLabel(label: 'Question'),
        const SizedBox(height: 8),
        _CardTextField(
          controller: _qCtrl,
          hint: 'Type your question…',
          maxLines: 3,
          onChanged: (v) {
            widget.card.question = v;
            widget.onChanged();
          },
        ),
        const SizedBox(height: 20),
        _CardFieldLabel(label: 'Choices  (tap the circle to mark correct)'),
        const SizedBox(height: 10),
        ...List.generate(4, (i) {
          final isCorrect = widget.card.correctIndex == i;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    widget.card.correctIndex = i;
                    widget.onChanged();
                    setState(() {});
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCorrect
                          ? AppColors.primary
                          : AppColors.surfaceContainerLow,
                      border: Border.all(
                        color: isCorrect
                            ? AppColors.primary
                            : AppColors.outlineVariant,
                        width: 2,
                      ),
                    ),
                    child: isCorrect
                        ? const Icon(Icons.check_rounded,
                            size: 14, color: AppColors.onPrimary)
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CardTextField(
                    controller: _cCtrls[i],
                    hint: 'Choice ${i + 1}',
                    onChanged: (v) {
                      widget.card.choices[i] = v;
                      widget.onChanged();
                    },
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ── Identification Editor ─────────────────────────────────────────────────────

class _IdentificationEditor extends StatefulWidget {
  const _IdentificationEditor(
      {super.key, required this.card, required this.onChanged});
  final _CardData card;
  final VoidCallback onChanged;

  @override
  State<_IdentificationEditor> createState() => _IdentificationEditorState();
}

class _IdentificationEditorState extends State<_IdentificationEditor> {
  late final TextEditingController _qCtrl;
  late final TextEditingController _aCtrl;

  @override
  void initState() {
    super.initState();
    _qCtrl = TextEditingController(text: widget.card.question);
    _aCtrl = TextEditingController(text: widget.card.answer);
  }

  @override
  void dispose() {
    _qCtrl.dispose();
    _aCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CardFieldLabel(label: 'Question'),
        const SizedBox(height: 8),
        _CardTextField(
          controller: _qCtrl,
          hint: 'Type your question…',
          maxLines: 3,
          onChanged: (v) {
            widget.card.question = v;
            widget.onChanged();
          },
        ),
        const SizedBox(height: 20),
        _CardFieldLabel(label: 'Answer'),
        const SizedBox(height: 8),
        _CardTextField(
          controller: _aCtrl,
          hint: 'Exact-match answer…',
          onChanged: (v) {
            widget.card.answer = v;
            widget.onChanged();
          },
        ),
      ],
    );
  }
}

// ── Card Field Label ──────────────────────────────────────────────────────────

class _CardFieldLabel extends StatelessWidget {
  const _CardFieldLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.onSurfaceVariant,
        letterSpacing: 0.6,
      ),
    );
  }
}

// ── Card Text Field ───────────────────────────────────────────────────────────

class _CardTextField extends StatelessWidget {
  const _CardTextField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      maxLines: maxLines,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.onSurface,
        height: 1.4,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          color: AppColors.outline,
          fontWeight: FontWeight.w400,
        ),
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}

// ── Navigation Buttons ────────────────────────────────────────────────────────

class _NavigationButtons extends StatelessWidget {
  const _NavigationButtons({
    required this.canGoPrev,
    required this.canGoNext,
    required this.showSave,
    required this.canSave,
    required this.isSaving,
    required this.onPrev,
    required this.onNext,
    required this.onSave,
  });

  final bool canGoPrev;
  final bool canGoNext;
  final bool showSave;
  final bool canSave;
  final bool isSaving;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ── Previous Card ─────────────────────────────────────────────────
        Expanded(
          child: GestureDetector(
            onTap: canGoPrev ? onPrev : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: canGoPrev
                    ? AppColors.secondaryContainer
                    : AppColors.outlineVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.arrow_back_rounded,
                      size: 16, color: AppColors.onSurface),
                  const SizedBox(width: 6),
                  Text(
                    'Previous',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // ── Next Card  /  Save Deck ───────────────────────────────────────
        Expanded(
          child: GestureDetector(
            onTap: isSaving
                ? null
                : showSave
                    ? onSave
                    : (canGoNext ? onNext : null),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                gradient: showSave
                    ? const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryFixedDim],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: showSave
                    ? null
                    : (!canGoNext
                        ? AppColors.outlineVariant.withOpacity(0.4)
                        : AppColors.secondaryContainer),
                borderRadius: BorderRadius.circular(999),
                boxShadow: showSave
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.30),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        )
                      ]
                    : [],
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: isSaving
                    ? const Center(
                        key: ValueKey('loading'),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: AppSpinnerSmall(color: AppColors.onPrimary),
                        ),
                      )
                    : showSave
                        ? Row(
                            key: const ValueKey('save'),
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Save Deck',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.onPrimary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.check_circle_rounded,
                                  size: 16, color: AppColors.onPrimary),
                            ],
                          )
                        : Row(
                            key: const ValueKey('next'),
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Next Card',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: !canGoNext
                                      ? AppColors.outline
                                      : AppColors.onSecondaryContainer,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(Icons.arrow_forward_rounded,
                                  size: 16,
                                  color: !canGoNext
                                      ? AppColors.outline
                                      : AppColors.onSecondaryContainer),
                            ],
                          ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Dot Progress Indicator ────────────────────────────────────────────────────

class _DotIndicator extends StatelessWidget {
  const _DotIndicator({required this.cards, required this.currentIndex});
  final List<_CardData> cards;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final showDots = cards.length <= 20;

    if (!showDots) {
      return Center(
        child: Text(
          '${cards.where((c) => c.isComplete).length} / ${cards.length} filled',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: AppColors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Center(
      child: Wrap(
        spacing: 5,
        runSpacing: 5,
        children: List.generate(cards.length, (i) {
          final isCurrent = i == currentIndex;
          final isComplete = cards[i].isComplete;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isCurrent ? 20 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isCurrent
                  ? AppColors.primary
                  : isComplete
                      ? AppColors.primaryFixedDim
                      : AppColors.outlineVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(999),
            ),
          );
        }),
      ),
    );
  }
}

// ── Circle Icon Button ────────────────────────────────────────────────────────

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surfaceContainerLow,
          border: Border.all(
            color: AppColors.outlineVariant.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Icon(icon, color: AppColors.onSurface, size: 18),
      ),
    );
  }
}

// ── Decorative Blob ───────────────────────────────────────────────────────────

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
