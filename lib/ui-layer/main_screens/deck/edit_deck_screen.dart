import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../landing_page/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EDIT DECK SCREEN  —  route: /edit-deck
//
// RULES:
//   • Max 50 cards  |  Min 10 cards (cannot delete below 10)
//   • 5 pages max, 10 cards per page
//   • Partial saves OK — only dirty cards are written to Firestore
//   • Cards cannot be ADDED here; only edited or removed
//   • Deck title is also editable
// ─────────────────────────────────────────────────────────────────────────────

// ── Args ─────────────────────────────────────────────────────────────────────

class EditDeckArgs {
  const EditDeckArgs({required this.deckId, required this.deckTitle});
  final String deckId;
  final String deckTitle;
}

// ── Editable Card Model ───────────────────────────────────────────────────────

class _EditableCard {
  _EditableCard({
    required this.cardId,
    required this.question,
    required this.answer,
    required this.type,
    required this.choices,
    this.correctIndex,
  });

  final String cardId;
  String question;
  String answer;
  String type; // 'identification' | 'multiple_choice'
  List<String> choices; // always length-4 for MC
  int? correctIndex;
  bool isDirty = false;

  factory _EditableCard.fromMap(String id, Map<String, dynamic> data) {
    return _EditableCard(
      cardId: id,
      question: data['question'] ?? '',
      answer: data['answer'] ?? '',
      type: data['type'] ?? 'identification',
      choices: data['choices'] != null
          ? List<String>.from(data['choices'])
          : ['', '', '', ''],
      correctIndex: data['correctIndex'],
    );
  }

  Map<String, dynamic> toMap() {
    if (type == 'multiple_choice') {
      final idx = correctIndex ?? 0;
      return {
        'type': 'multiple_choice',
        'question': question.trim(),
        'choices': choices.map((c) => c.trim()).toList(),
        'correctIndex': idx,
        'answer': choices.isNotEmpty ? choices[idx].trim() : answer.trim(),
      };
    }
    return {
      'type': 'identification',
      'question': question.trim(),
      'answer': answer.trim(),
    };
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class EditDeckScreen extends StatefulWidget {
  const EditDeckScreen({super.key, required this.args});
  final EditDeckArgs args;

  @override
  State<EditDeckScreen> createState() => _EditDeckScreenState();
}

class _EditDeckScreenState extends State<EditDeckScreen> {
  static const int _cardsPerPage = 10;
  static const int _minCards = 10;

  List<_EditableCard> _cards = [];
  bool _loading = true;
  bool _saving = false;
  int _currentPage = 0;

  late TextEditingController _titleCtrl;
  bool _titleDirty = false;

  String get _deckId => widget.args.deckId;

  int get _pageCount => (_cards.length / _cardsPerPage).ceil().clamp(1, 5);

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.args.deckTitle);
    _titleCtrl.addListener(() => setState(() => _titleDirty = true));
    _loadCards();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  // ── Firestore ─────────────────────────────────────────────────────────────

  Future<void> _loadCards() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('decks')
        .doc(_deckId)
        .collection('cards')
        .orderBy('createdAt')
        .get();

    if (mounted) {
      setState(() {
        _cards = snap.docs
            .map((d) => _EditableCard.fromMap(d.id, d.data()))
            .toList();
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _saving = true);

    try {
      final batch = FirebaseFirestore.instance.batch();

      // Update dirty cards
      for (final card in _cards) {
        if (!card.isDirty) continue;
        final ref = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('decks')
            .doc(_deckId)
            .collection('cards')
            .doc(card.cardId);
        batch.update(ref, card.toMap());
      }

      // Update deck title if changed
      if (_titleDirty && _titleCtrl.text.trim().isNotEmpty) {
        final deckRef = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('decks')
            .doc(_deckId);
        batch.update(deckRef, {
          'title': _titleCtrl.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      for (final card in _cards) {
        card.isDirty = false;
      }
      _titleDirty = false;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Changes saved!',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e',
                style:
                    GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteCard(_EditableCard card) async {
    if (_cards.length <= _minCards) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'A deck must keep at least $_minCards cards.',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: AppColors.surfaceContainerLowest,
        title: Text(
          'Remove Card?',
          style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800, color: AppColors.onSurface),
        ),
        content: Text(
          'This card will be permanently removed from the deck.',
          style: GoogleFonts.plusJakartaSans(
              color: AppColors.onSurfaceVariant, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(_, false),
            child: Text('Cancel',
                style: GoogleFonts.plusJakartaSans(
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(_, true),
            child: Text('Remove',
                style: GoogleFonts.plusJakartaSans(
                    color: AppColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('decks')
        .doc(_deckId)
        .collection('cards')
        .doc(card.cardId)
        .delete();

    setState(() {
      _cards.remove(card);
      // Clamp page if the last page no longer exists
      if (_currentPage >= _pageCount) {
        _currentPage = (_pageCount - 1).clamp(0, 4);
      }
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Decorative blobs
          Positioned(
            top: -50,
            right: -60,
            child: _Blob(
              size: 280,
              color: AppColors.primaryContainer.withOpacity(0.20),
            ),
          ),
          Positioned(
            bottom: 80,
            left: -80,
            child: _Blob(
              size: 220,
              color: AppColors.secondaryContainer.withOpacity(0.22),
            ),
          ),

          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Top Bar
                _EditTopBar(
                  saving: _saving,
                  onBack: () => Navigator.pop(context),
                  onSave: _save,
                ),

                // Body
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        )
                      : _cards.isEmpty
                          ? const _EmptyState()
                          : _EditorBody(
                              allCards: _cards,
                              currentPage: _currentPage,
                              pageCount: _pageCount,
                              cardsPerPage: _cardsPerPage,
                              titleCtrl: _titleCtrl,
                              totalCards: _cards.length,
                              minCards: _minCards,
                              onPageChanged: (p) =>
                                  setState(() => _currentPage = p),
                              onDeleteCard: _deleteCard,
                              onCardChanged: (card) =>
                                  setState(() => card.isDirty = true),
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
// TOP BAR
// ─────────────────────────────────────────────────────────────────────────────

class _EditTopBar extends StatelessWidget {
  const _EditTopBar({
    required this.saving,
    required this.onBack,
    required this.onSave,
  });

  final bool saving;
  final VoidCallback onBack;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background.withOpacity(0.92),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.onSurface.withOpacity(0.05),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: AppColors.onSurface,
                size: 20,
              ),
            ),
          ),

          // Title
          Expanded(
            child: Center(
              child: Text(
                'Edit Deck',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface,
                  letterSpacing: -0.4,
                ),
              ),
            ),
          ),

          // Save button
          GestureDetector(
            onTap: saving ? null : onSave,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 72,
              height: 40,
              decoration: BoxDecoration(
                color: saving
                    ? AppColors.outline.withOpacity(0.25)
                    : AppColors.primary,
                borderRadius: BorderRadius.circular(999),
                boxShadow: saving
                    ? []
                    : [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.30),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Center(
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Save',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
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
// EDITOR BODY (sliver layout)
// ─────────────────────────────────────────────────────────────────────────────

class _EditorBody extends StatelessWidget {
  const _EditorBody({
    required this.allCards,
    required this.currentPage,
    required this.pageCount,
    required this.cardsPerPage,
    required this.titleCtrl,
    required this.totalCards,
    required this.minCards,
    required this.onPageChanged,
    required this.onDeleteCard,
    required this.onCardChanged,
  });

  final List<_EditableCard> allCards;
  final int currentPage;
  final int pageCount;
  final int cardsPerPage;
  final TextEditingController titleCtrl;
  final int totalCards;
  final int minCards;
  final void Function(int) onPageChanged;
  final void Function(_EditableCard) onDeleteCard;
  final void Function(_EditableCard) onCardChanged;

  List<_EditableCard> get _pageCards {
    final start = currentPage * cardsPerPage;
    final end = (start + cardsPerPage).clamp(0, allCards.length);
    return allCards.sublist(start, end);
  }

  @override
  Widget build(BuildContext context) {
    final pageCards = _pageCards;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── Deck meta + pagination ─────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _DeckMetaSection(titleCtrl: titleCtrl, totalCards: totalCards),
              const SizedBox(height: 20),
              _PaginationTabs(
                pageCount: pageCount,
                currentPage: currentPage,
                totalCards: totalCards,
                cardsPerPage: cardsPerPage,
                onPageChanged: onPageChanged,
              ),
              const SizedBox(height: 20),
            ]),
          ),
        ),

        // ── Card editors ───────────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) {
                final card = pageCards[i];
                final globalIndex = currentPage * cardsPerPage + i;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _CardEditor(
                    key: ValueKey(card.cardId),
                    card: card,
                    cardNumber: globalIndex + 1,
                    canDelete: totalCards > minCards,
                    onDelete: () => onDeleteCard(card),
                    onChanged: () => onCardChanged(card),
                  ),
                );
              },
              childCount: pageCards.length,
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DECK META SECTION
// ─────────────────────────────────────────────────────────────────────────────

class _DeckMetaSection extends StatelessWidget {
  const _DeckMetaSection({
    required this.titleCtrl,
    required this.totalCards,
  });

  final TextEditingController titleCtrl;
  final int totalCards;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DECK TITLE',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurfaceVariant,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: titleCtrl,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.onSurface,
            ),
            decoration: InputDecoration(
              hintText: 'Deck title...',
              hintStyle: GoogleFonts.plusJakartaSans(
                color: AppColors.outline.withOpacity(0.5),
              ),
              filled: true,
              fillColor: AppColors.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.secondaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.style_rounded,
                    color: AppColors.onSecondaryContainer,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$totalCards Cards',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAGINATION TABS
// ─────────────────────────────────────────────────────────────────────────────

class _PaginationTabs extends StatelessWidget {
  const _PaginationTabs({
    required this.pageCount,
    required this.currentPage,
    required this.totalCards,
    required this.cardsPerPage,
    required this.onPageChanged,
  });

  final int pageCount;
  final int currentPage;
  final int totalCards;
  final int cardsPerPage;
  final void Function(int) onPageChanged;

  String _label(int page) {
    final start = page * cardsPerPage + 1;
    final end = ((page + 1) * cardsPerPage).clamp(0, totalCards);
    return '$start–$end';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: AppColors.onSurface.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: List.generate(pageCount, (i) {
            final active = i == currentPage;
            return GestureDetector(
              onTap: () => onPageChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color:
                      active ? AppColors.primaryContainer : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _label(i),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    color:
                        active ? AppColors.primary : AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD EDITOR
// ─────────────────────────────────────────────────────────────────────────────

class _CardEditor extends StatefulWidget {
  const _CardEditor({
    super.key,
    required this.card,
    required this.cardNumber,
    required this.canDelete,
    required this.onDelete,
    required this.onChanged,
  });

  final _EditableCard card;
  final int cardNumber;
  final bool canDelete;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  @override
  State<_CardEditor> createState() => _CardEditorState();
}

class _CardEditorState extends State<_CardEditor> {
  late TextEditingController _questionCtrl;
  late TextEditingController _answerCtrl;
  late List<TextEditingController> _choiceCtrl;

  @override
  void initState() {
    super.initState();
    _questionCtrl = TextEditingController(text: widget.card.question);
    _answerCtrl = TextEditingController(text: widget.card.answer);
    _choiceCtrl =
        widget.card.choices.map((c) => TextEditingController(text: c)).toList();

    _questionCtrl.addListener(_sync);
    _answerCtrl.addListener(_sync);
    for (final c in _choiceCtrl) {
      c.addListener(_sync);
    }
  }

  void _sync() {
    widget.card.question = _questionCtrl.text;
    widget.card.answer = _answerCtrl.text;
    for (int i = 0; i < _choiceCtrl.length; i++) {
      if (i < widget.card.choices.length) {
        widget.card.choices[i] = _choiceCtrl[i].text;
      }
    }
    widget.onChanged();
  }

  @override
  void dispose() {
    _questionCtrl.dispose();
    _answerCtrl.dispose();
    for (final c in _choiceCtrl) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isId = widget.card.type == 'identification';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header bar ──────────────────────────────────────────────────
          Container(
            color: AppColors.surfaceContainerLow,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.drag_indicator_rounded,
                  color: AppColors.outline.withOpacity(0.6),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Card ${widget.cardNumber}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                // Type badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isId
                        ? AppColors.tertiaryContainer.withOpacity(0.55)
                        : AppColors.secondaryContainer.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    isId ? 'IDENTIFICATION' : 'MULTIPLE CHOICE',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: isId
                          ? AppColors.onTertiaryContainer
                          : AppColors.onSecondaryContainer,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const Spacer(),
                // Delete button
                GestureDetector(
                  onTap: widget.onDelete,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: widget.canDelete
                          ? AppColors.errorContainer.withOpacity(0.65)
                          : AppColors.outlineVariant.withOpacity(0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      color: widget.canDelete
                          ? AppColors.error
                          : AppColors.outline.withOpacity(0.3),
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Card fields ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Question
                _FieldLabel('Front (Question)'),
                const SizedBox(height: 6),
                _EditField(
                  controller: _questionCtrl,
                  minLines: 2,
                  hint: 'Enter the question...',
                ),
                const SizedBox(height: 16),

                // Answer area
                if (isId) ...[
                  _FieldLabel('Back (Answer)'),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.tertiaryContainer.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: _EditField(
                      controller: _answerCtrl,
                      minLines: 2,
                      hint: 'Enter the answer...',
                    ),
                  ),
                ] else ...[
                  _FieldLabel('Options — tap ○ to mark correct answer'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryContainer.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: List.generate(
                        _choiceCtrl.length,
                        (i) {
                          final isCorrect = widget.card.correctIndex == i;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    setState(
                                        () => widget.card.correctIndex = i);
                                    widget.onChanged();
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isCorrect
                                          ? AppColors.primary
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: isCorrect
                                            ? AppColors.primary
                                            : AppColors.outlineVariant,
                                        width: 2,
                                      ),
                                    ),
                                    child: isCorrect
                                        ? const Icon(
                                            Icons.check_rounded,
                                            color: Colors.white,
                                            size: 14,
                                          )
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: _choiceCtrl[i],
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      color: AppColors.onSurface,
                                      fontWeight: isCorrect
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                    ),
                                    decoration: InputDecoration(
                                      hintText:
                                          'Choice ${String.fromCharCode(65 + i)}...',
                                      hintStyle: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        color:
                                            AppColors.outline.withOpacity(0.5),
                                      ),
                                      filled: true,
                                      fillColor: isCorrect
                                          ? AppColors.primaryContainer
                                              .withOpacity(0.30)
                                          : AppColors.surfaceContainerLow,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SMALL REUSABLES
// ─────────────────────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.plusJakartaSans(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppColors.onSurfaceVariant,
        letterSpacing: 1.0,
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  const _EditField({
    required this.controller,
    this.minLines = 1,
    this.hint = '',
  });

  final TextEditingController controller;
  final int minLines;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: null,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 15,
        color: AppColors.onSurface,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          color: AppColors.outline.withOpacity(0.5),
        ),
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.style_outlined,
              size: 64, color: AppColors.outline.withOpacity(0.45)),
          const SizedBox(height: 16),
          Text(
            'No cards found',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'This deck appears to have no cards.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
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
