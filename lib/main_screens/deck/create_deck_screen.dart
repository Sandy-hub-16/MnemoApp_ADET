import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../landing_page/app_theme.dart';
import '../../services/deck_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CREATE DECK SCREEN  —  route: /create-deck
//
// TWO-PHASE FLOW:
//   Phase 1 — Deck Setup   : name, subject tag, target card count
//   Phase 2 — Card Editor  : build cards one by one (Multiple Choice OR Identification)
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

  @override
  void initState() {
    super.initState();
    _phaseTransitionCtrl = AnimationController(
      duration: const Duration(milliseconds: 340),
      vsync: this,
    );
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

  // ── Save Deck ──────────────────────────────────────────────────────────────

  bool get _canSave {
    if (_titleController.text.trim().isEmpty) return false;
    // At least one complete card
    return _cards.any((c) => c.isComplete);
  }

  Future<void> _onSaveDeck() async {
    if (!_canSave) return;

    final completedCards = _cards.where((c) => c.isComplete).toList();

    try {
      await DeckService.createDeck(
        title: _titleController.text.trim(),
        tag: _tags[_selectedTagIndex],
        cards: completedCards.map((c) => c.toMap()).toList(),
      );

      if (!mounted) return;

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
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/decks',
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    }
  }

  // ── Back handler ───────────────────────────────────────────────────────────

  Future<bool> _onWillPop() async {
    if (_phase == _Phase.editor) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => _DiscardDialog(ctx),
      );
      if (confirmed == true) {
        setState(() {
          _phase = _Phase.setup;
          _phaseTransitionCtrl.reverse();
        });
        return false;
      }
      return false;
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
                        onCardChanged: () => setState(() {}),
                        onPrev: _goToPrevCard,
                        onNext: _goToNextCard,
                        onSave: _onSaveDeck,
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
    required this.onCardChanged,
    required this.onPrev,
    required this.onNext,
    required this.onSave,
    required this.onBack,
  });

  final List<_CardData> cards;
  final int currentIndex;
  final bool canSave;
  final VoidCallback onCardChanged;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onSave;
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
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: child,
                      ),
                      child: _current.type == CardType.multipleChoice
                          ? _MCCardEditor(
                              key: ValueKey(
                                  'mc_${currentIndex}_${_current.type}'),
                              card: _current,
                              onChanged: onCardChanged,
                            )
                          : _IdentificationCardEditor(
                              key: ValueKey(
                                  'id_${currentIndex}_${_current.type}'),
                              card: _current,
                              onChanged: onCardChanged,
                            ),
                    ),

                    const SizedBox(height: 28),

                    // ── Navigation row ────────────────────────────────
                    _NavigationRow(
                      currentIndex: currentIndex,
                      total: cards.length,
                      allComplete: _completedCount == cards.length,
                      currentCardComplete: _currentCardComplete,
                      onPrev: onPrev,
                      onNext: onNext,
                      onSave: onSave,
                    ),

                    // ── Dots indicator ────────────────────────────────
                    const SizedBox(height: 20),
                    _DotIndicator(
                      cards: cards,
                      currentIndex: currentIndex,
                    ),

                    const SizedBox(height: 120),
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
// MULTIPLE CHOICE CARD EDITOR
// ─────────────────────────────────────────────────────────────────────────────

class _MCCardEditor extends StatefulWidget {
  const _MCCardEditor({super.key, required this.card, required this.onChanged});
  final _CardData card;
  final VoidCallback onChanged;

  @override
  State<_MCCardEditor> createState() => _MCCardEditorState();
}

class _MCCardEditorState extends State<_MCCardEditor> {
  late TextEditingController _qCtrl;
  late List<TextEditingController> _choiceCtrl;

  @override
  void initState() {
    super.initState();
    _qCtrl = TextEditingController(text: widget.card.question);
    _choiceCtrl = List.generate(
      4,
      (i) => TextEditingController(text: widget.card.choices[i]),
    );
  }

  @override
  void dispose() {
    _qCtrl.dispose();
    for (final c in _choiceCtrl) {
      c.dispose();
    }
    super.dispose();
  }

  void _sync() {
    widget.card.question = _qCtrl.text;
    for (int i = 0; i < 4; i++) {
      widget.card.choices[i] = _choiceCtrl[i].text;
    }
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
          // ── Question ─────────────────────────────────────────────────
          _CardSection(
            label: 'Question',
            icon: Icons.help_outline_rounded,
            iconColor: AppColors.primary,
            child: _CardTextArea(
              controller: _qCtrl,
              hint: 'e.g. What is the powerhouse of the cell?',
              onChanged: (_) => _sync(),
            ),
          ),

          _CardDivider(),

          // ── Choices ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Answer Choices',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Tap circle = correct',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          ...List.generate(4, (i) {
            final labels = ['A', 'B', 'C', 'D'];
            final isCorrect = widget.card.correctIndex != null &&
                widget.card.correctIndex == i;
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: _ChoiceRow(
                label: labels[i],
                controller: _choiceCtrl[i],
                isCorrect: isCorrect,
                onToggle: () {
                  setState(() => widget.card.correctIndex = i);
                  _sync();
                },
                onChanged: (_) => _sync(),
              ),
            );
          }),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// IDENTIFICATION CARD EDITOR
// ─────────────────────────────────────────────────────────────────────────────

class _IdentificationCardEditor extends StatefulWidget {
  const _IdentificationCardEditor(
      {super.key, required this.card, required this.onChanged});
  final _CardData card;
  final VoidCallback onChanged;

  @override
  State<_IdentificationCardEditor> createState() =>
      _IdentificationCardEditorState();
}

class _IdentificationCardEditorState extends State<_IdentificationCardEditor> {
  late TextEditingController _qCtrl;
  late TextEditingController _aCtrl;

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

  void _sync() {
    widget.card.question = _qCtrl.text;
    widget.card.answer = _aCtrl.text;
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
          // ── Question ─────────────────────────────────────────────────
          _CardSection(
            label: 'Question',
            icon: Icons.help_outline_rounded,
            iconColor: AppColors.primary,
            child: _CardTextArea(
              controller: _qCtrl,
              hint: 'e.g. What process converts glucose into ATP?',
              onChanged: (_) => _sync(),
            ),
          ),

          _CardDivider(),

          // ── Answer ────────────────────────────────────────────────────
          _CardSection(
            label: 'Correct Answer',
            icon: Icons.lightbulb_outline_rounded,
            iconColor: AppColors.secondary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CardTextArea(
                  controller: _aCtrl,
                  hint: 'Type the exact correct answer...',
                  maxLines: 2,
                  onChanged: (_) => _sync(),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryContainer.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 16, color: AppColors.secondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Students must type this exact answer. Identification tests precise recall.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppColors.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SHARED SUB-COMPONENTS
// ═════════════════════════════════════════════════════════════════════════════

// ── Top Bars ──────────────────────────────────────────────────────────────────

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
      color: AppColors.background.withOpacity(0.85),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          _CircleIconButton(
            icon: Icons.arrow_back_rounded,
            onTap: onBack,
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              letterSpacing: -0.4,
            ),
          ),
          const Spacer(),
          trailing,
        ],
      ),
    );
  }
}

class _EditorTopBar extends StatelessWidget {
  const _EditorTopBar({
    required this.currentIndex,
    required this.total,
    required this.progress,
    required this.canSave,
    required this.completedCount,
    required this.onBack,
    required this.onSave,
  });

  final int currentIndex;
  final int total;
  final double progress;
  final bool canSave;
  final int completedCount;
  final VoidCallback onBack;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: AppColors.background.withOpacity(0.90),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
          child: Row(
            children: [
              _CircleIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: onBack,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Card ${currentIndex + 1} of $total',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      '$completedCount complete',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Save deck button
              GestureDetector(
                onTap: canSave ? onSave : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    color: canSave ? null : AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: canSave
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_rounded,
                          size: 14,
                          color: canSave
                              ? AppColors.onPrimary
                              : AppColors.outline),
                      const SizedBox(width: 5),
                      Text(
                        'Save Deck',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color:
                              canSave ? AppColors.onPrimary : AppColors.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Progress bar ─────────────────────────────────────────────────
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: progress),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          builder: (_, value, __) => LinearProgressIndicator(
            value: value,
            backgroundColor: AppColors.outlineVariant.withOpacity(0.25),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            minHeight: 3,
          ),
        ),
      ],
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
      label.toUpperCase(),
      style: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: AppColors.onSurfaceVariant,
        letterSpacing: 1.1,
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurface,
        ),
        decoration: InputDecoration(
          hintText: 'e.g. Organic Chemistry II',
          hintStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            color: AppColors.outline.withOpacity(0.5),
          ),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 8),
            child:
                Icon(Icons.layers_outlined, color: AppColors.primary, size: 22),
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
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
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tags.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final active = i == selectedIndex;
          return GestureDetector(
            onTap: () => onSelected(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: active
                    ? AppColors.primary
                    : AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(999),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : [],
              ),
              child: Text(
                tags[i],
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color:
                      active ? AppColors.onPrimary : AppColors.onSurfaceVariant,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Card Count Slider ─────────────────────────────────────────────────────────

class _CardCountSlider extends StatelessWidget {
  const _CardCountSlider({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'How many cards?',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$value',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: AppColors.outlineVariant.withOpacity(0.4),
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withOpacity(0.12),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              value: value.toDouble(),
              min: 1,
              max: 50,
              divisions: 49,
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('1',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11, color: AppColors.outline)),
              Text('50',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11, color: AppColors.outline)),
            ],
          ),
        ],
      ),
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
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: enabled
              ? const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryFixedDim],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: enabled ? null : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(999),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.28),
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
                letterSpacing: 0.2,
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
  const _CardTypeToggle({required this.type, required this.onChanged});
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
          _ToggleOption(
            label: 'Multiple Choice',
            icon: Icons.checklist_rounded,
            active: type == CardType.multipleChoice,
            onTap: () => onChanged(CardType.multipleChoice),
          ),
          _ToggleOption(
            label: 'Identification',
            icon: Icons.edit_outlined,
            active: type == CardType.identification,
            onTap: () => onChanged(CardType.identification),
          ),
        ],
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  const _ToggleOption({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color:
                active ? AppColors.surfaceContainerLowest : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: active
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
                color: active ? AppColors.primary : AppColors.outline,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color:
                      active ? AppColors.primary : AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Card Section (Question / Answer containers) ───────────────────────────────

class _CardSection extends StatelessWidget {
  const _CardSection({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.child,
  });

  final String label;
  final IconData icon;
  final Color iconColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ── Card Text Area ────────────────────────────────────────────────────────────

class _CardTextArea extends StatelessWidget {
  const _CardTextArea({
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.maxLines = 3,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        maxLines: maxLines,
        minLines: 2,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          color: AppColors.onSurface,
          height: 1.5,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: AppColors.outline.withOpacity(0.5),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }
}

// ── Card Divider ──────────────────────────────────────────────────────────────

class _CardDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: AppColors.outlineVariant.withOpacity(0.25),
      margin: const EdgeInsets.symmetric(horizontal: 20),
    );
  }
}

// ── Choice Row (MC answer option) ─────────────────────────────────────────────

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.controller,
    required this.isCorrect,
    required this.onToggle,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final bool isCorrect;
  final VoidCallback onToggle;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isCorrect
            ? AppColors.primaryContainer.withOpacity(0.5)
            : AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCorrect
              ? AppColors.primary.withOpacity(0.5)
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // ── Correct toggle ──────────────────────────────────────────
          GestureDetector(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isCorrect
                    ? AppColors.primary
                    : AppColors.surfaceContainerLowest,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.onSurface.withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: isCorrect
                  ? const Icon(Icons.check_rounded,
                      color: AppColors.onPrimary, size: 16)
                  : Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.outline.withOpacity(0.6),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 10),

          // ── Text field ──────────────────────────────────────────────
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: AppColors.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Enter choice ${label}...',
                hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppColors.outline.withOpacity(0.5),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Navigation Row (Prev / Next → Save Deck) ──────────────────────────────────

class _NavigationRow extends StatelessWidget {
  const _NavigationRow({
    required this.currentIndex,
    required this.total,
    required this.allComplete,
    required this.currentCardComplete,
    required this.onPrev,
    required this.onNext,
    required this.onSave,
  });

  final int currentIndex;
  final int total;
  final bool allComplete;
  final bool currentCardComplete;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onSave;

  bool get _isLastCard => currentIndex == total - 1;

  @override
  Widget build(BuildContext context) {
    // On the last card AND all cards complete → morph Next into Save Deck
    final bool showSave = _isLastCard && allComplete && currentCardComplete;
    // Next button is only active when current card is complete and not last
    final bool canGoNext = !_isLastCard && currentCardComplete;

    return Row(
      children: [
        // ── Previous ─────────────────────────────────────────────────────
        Expanded(
          child: GestureDetector(
            onTap: currentIndex > 0 ? onPrev : null,
            child: AnimatedOpacity(
              opacity: currentIndex > 0 ? 1.0 : 0.35,
              duration: const Duration(milliseconds: 200),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
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
        ),
        const SizedBox(width: 12),

        // ── Next Card  /  Save Deck ───────────────────────────────────────
        Expanded(
          child: GestureDetector(
            onTap: showSave ? onSave : (canGoNext ? onNext : null),
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
                child: showSave
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
    // Show at most 9 dots; if more cards, show condensed view
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

// ── Discard Dialog ────────────────────────────────────────────────────────────

AlertDialog _DiscardDialog(BuildContext ctx) => AlertDialog(
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        'Go Back?',
        style: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w800,
          color: AppColors.onSurface,
          fontSize: 18,
        ),
      ),
      content: Text(
        'Your card progress will be reset. The deck name and subject will remain.',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          color: AppColors.onSurfaceVariant,
          height: 1.5,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(
            'Stay',
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            'Go Back',
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
