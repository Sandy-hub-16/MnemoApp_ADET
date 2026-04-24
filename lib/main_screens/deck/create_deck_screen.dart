import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../landing_page/app_theme.dart';
import '../../services/deck_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CREATE DECK SCREEN  —  route: /create-deck
// Full CRUD interface for building a new deck with Q&A flashcard pairs.
//
// 🎨 FRONTEND NOTE:
// All Q&A state is managed locally in _CreateDeckScreenState.
// Wire _onSaveDeck() to a Firestore write when backend is ready.
// ─────────────────────────────────────────────────────────────────────────────

// ── Data model ────────────────────────────────────────────────────────────────

class _QAPair {
  _QAPair({required this.id, required this.question, required this.answer});
  final String id;
  String question;
  String answer;
}

// ── Screen ────────────────────────────────────────────────────────────────────

class CreateDeckScreen extends StatefulWidget {
  const CreateDeckScreen({super.key});

  @override
  State<CreateDeckScreen> createState() => _CreateDeckScreenState();
}

class _CreateDeckScreenState extends State<CreateDeckScreen> {
  final _titleController = TextEditingController();
  int _selectedTagIndex = 0;
  final List<_QAPair> _pairs = [];

  static const _tags = [
    'Biology',
    'Physics',
    'Organic Chem',
    'World History',
    'History',
    'Other',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  // ── CRUD helpers ─────────────────────────────────────────────────────────

  /// CREATE & UPDATE — opens the Q&A form sheet.
  /// Pass [existing] to pre-fill for editing, or null to create a new card.
  void _openQAForm(_QAPair? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QAFormSheet(
        existing: existing,
        onSave: (q, a) {
          setState(() {
            if (existing != null) {
              // UPDATE — mutate in place and refresh
              existing.question = q;
              existing.answer = a;
            } else {
              // CREATE — append new pair
              _pairs.add(_QAPair(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                question: q,
                answer: a,
              ));
            }
          });
        },
      ),
    );
  }

  /// DELETE — shows confirmation dialog before removing.
  void _confirmDelete(_QAPair pair) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Delete Card?',
          style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700, color: AppColors.onSurface),
        ),
        content: Text(
          'This Q&A card will be permanently removed from your deck.',
          style: GoogleFonts.plusJakartaSans(
              fontSize: 14, color: AppColors.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(
                  color: AppColors.primary, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() => _pairs.removeWhere((p) => p.id == pair.id));
              Navigator.pop(ctx);
            },
            child: Text(
              'Delete',
              style: GoogleFonts.plusJakartaSans(
                  color: AppColors.error, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  /// SAVE DECK — writes to Firestore via DeckService; stream in deck_screen auto-refreshes.
  Future<void> _onSaveDeck() async {
    if (!_canSave) return;

    final title = _titleController.text.trim();
    final tag = _tags[_selectedTagIndex];

    final List<Map<String, dynamic>> cards = _pairs.map((p) {
      return {
        'id': p.id,
        'question': p.question,
        'answer': p.answer,
        'createdAt': DateTime.now().toIso8601String(),
      };
    }).toList();

    try {
      await DeckService.createDeck(
        title: title,
        tag: tag,
        cards: cards,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Deck saved successfully!'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );

      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/decks', // or whatever route deck_screen uses
          (route) => false, // Remove all previous routes
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save deck: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    }
  }

  bool get _canSave =>
      _titleController.text.trim().isNotEmpty && _pairs.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: Stack(
        children: [
          // ── Decorative blobs (mirrors deck_screen.dart) ──────────────────
          Positioned(
            top: -40,
            right: -80,
            child: _Blob(
              size: 320,
              color: AppColors.primaryContainer.withOpacity(0.22),
            ),
          ),
          Positioned(
            bottom: 200,
            left: -100,
            child: _Blob(
              size: 280,
              color: AppColors.secondaryContainer.withOpacity(0.25),
            ),
          ),

          // ── Main content ─────────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top bar
                _CreateDeckTopBar(
                  canSave: _canSave,
                  onBack: () => Navigator.pop(context),
                  onSave: _canSave ? _onSaveDeck : null,
                ),

                Expanded(
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            // ── Deck name input ─────────────────────────
                            _DeckNameInput(
                              controller: _titleController,
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 20),

                            // ── Subject tag selector ────────────────────
                            _SubjectSelector(
                              tags: _tags,
                              selectedIndex: _selectedTagIndex,
                              onSelected: (i) =>
                                  setState(() => _selectedTagIndex = i),
                            ),
                            const SizedBox(height: 28),

                            // ── Q&A section header ──────────────────────
                            _QASectionHeader(
                              count: _pairs.length,
                              onAdd: _pairs.isEmpty
                                  ? null
                                  : () => _openQAForm(null),
                            ),
                            const SizedBox(height: 16),

                            // ── READ: Q&A cards or empty state ──────────
                            if (_pairs.isEmpty)
                              _EmptyCardsState(onAdd: () => _openQAForm(null))
                            else
                              ..._pairs.asMap().entries.map((entry) {
                                final index = entry.key;
                                final pair = entry.value;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _QACard(
                                    pair: pair,
                                    cardNumber: index + 1,
                                    onEdit: () => _openQAForm(pair),
                                    onDelete: () => _confirmDelete(pair),
                                  ),
                                );
                              }),

                            const SizedBox(height: 140),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
              
              ],
            ),
          ),
        ],
      ),
      // ── FAB: Add new Q&A card ───────────────────────────────────────────
      floatingActionButton: _AddCardFAB(onTap: () => _openQAForm(null)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOP BAR
// ─────────────────────────────────────────────────────────────────────────────

class _CreateDeckTopBar extends StatelessWidget {
  const _CreateDeckTopBar({
    required this.canSave,
    required this.onBack,
    required this.onSave,
  });

  final bool canSave;
  final VoidCallback onBack;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background.withOpacity(0.80),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: onBack,
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
              child: const Icon(Icons.arrow_back_rounded,
                  color: AppColors.onSurface, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Create Deck',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              letterSpacing: -0.4,
            ),
          ),
          const Spacer(),

          // Save button
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: GestureDetector(
              onTap: onSave,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
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
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: canSave ? AppColors.onPrimary : AppColors.outline,
                    ),
                    const SizedBox(width: 6),
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
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DECK NAME INPUT
// ─────────────────────────────────────────────────────────────────────────────

class _DeckNameInput extends StatelessWidget {
  const _DeckNameInput({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Deck Name',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurfaceVariant,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
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
              hintText: 'e.g. Cellular Biology — Chapter 4',
              hintStyle: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                color: AppColors.outline.withOpacity(0.5),
              ),
              prefixIcon: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.layers_outlined,
                    color: AppColors.primary, size: 22),
              ),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUBJECT TAG SELECTOR
// ─────────────────────────────────────────────────────────────────────────────

class _SubjectSelector extends StatelessWidget {
  const _SubjectSelector({
    required this.tags,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> tags;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Subject',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurfaceVariant,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: tags.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final active = i == selectedIndex;
              return GestureDetector(
                onTap: () => onSelected(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
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
                      color: active
                          ? AppColors.onPrimary
                          : AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Q&A SECTION HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _QASectionHeader extends StatelessWidget {
  const _QASectionHeader({required this.count, this.onAdd});

  final int count;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Q&A Cards',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              '$count card${count == 1 ? '' : 's'} added',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        if (onAdd != null)
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded,
                      size: 16, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    'Add Card',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyCardsState extends StatefulWidget {
  const _EmptyCardsState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  State<_EmptyCardsState> createState() => _EmptyCardsStateState();
}

class _EmptyCardsStateState extends State<_EmptyCardsState> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onAdd,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 40),
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.primary.withOpacity(0.05)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _hovered
                  ? AppColors.primary.withOpacity(0.5)
                  : AppColors.outlineVariant.withOpacity(0.5),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _hovered
                      ? AppColors.primaryContainer
                      : AppColors.surfaceContainerLow,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: _hovered ? AppColors.primary : AppColors.outline,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Add Your First Card',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap to create a Q&A flashcard pair',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Q&A CARD  (READ + DELETE + triggers UPDATE)
// ─────────────────────────────────────────────────────────────────────────────

class _QACard extends StatelessWidget {
  const _QACard({
    required this.pair,
    required this.cardNumber,
    required this.onEdit,
    required this.onDelete,
  });

  final _QAPair pair;
  final int cardNumber;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

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
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Card header: badge + actions ────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'CARD $cardNumber',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Row(
                children: [
                  // Edit button
                  GestureDetector(
                    onTap: onEdit,
                    child: Container(
                      width: 32,
                      height: 32,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.edit_outlined,
                          size: 15, color: AppColors.primary),
                    ),
                  ),
                  // Delete button
                  GestureDetector(
                    onTap: onDelete,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        size: 15,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Question ────────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: AppColors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    'Q',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  pair.question,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),

          // ── Divider ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              height: 1,
              color: AppColors.outlineVariant.withOpacity(0.3),
            ),
          ),

          // ── Answer ──────────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    'A',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  pair.answer,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: AppColors.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Q&A FORM SHEET  (CREATE + UPDATE)
// ─────────────────────────────────────────────────────────────────────────────

class _QAFormSheet extends StatefulWidget {
  const _QAFormSheet({this.existing, required this.onSave});

  final _QAPair? existing;
  final void Function(String question, String answer) onSave;

  @override
  State<_QAFormSheet> createState() => _QAFormSheetState();
}

class _QAFormSheetState extends State<_QAFormSheet> {
  late final TextEditingController _qCtrl;
  late final TextEditingController _aCtrl;

  @override
  void initState() {
    super.initState();
    _qCtrl = TextEditingController(text: widget.existing?.question ?? '');
    _aCtrl = TextEditingController(text: widget.existing?.answer ?? '');
  }

  @override
  void dispose() {
    _qCtrl.dispose();
    _aCtrl.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _qCtrl.text.trim().isNotEmpty && _aCtrl.text.trim().isNotEmpty;

  bool get _isEditing => widget.existing != null;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Pushes sheet up when keyboard appears
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Handle ──────────────────────────────────────────────────
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),

            // ── Sheet header ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isEditing ? 'Edit Card' : 'New Q&A Card',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onSurface,
                      letterSpacing: -0.3,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded,
                          size: 18, color: AppColors.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Question field ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _QATextField(
                controller: _qCtrl,
                label: 'Question',
                hint: 'e.g. What is cellular respiration?',
                icon: Icons.help_outline_rounded,
                iconColor: AppColors.primary,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 12),

            // ── Answer field ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _QATextField(
                controller: _aCtrl,
                label: 'Answer',
                hint:
                    'e.g. The process by which cells convert glucose into energy...',
                icon: Icons.lightbulb_outline_rounded,
                iconColor: AppColors.secondary,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 20),

            // ── Action buttons ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Row(
                children: [
                  // Cancel
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Save / Add card
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: _canSave
                          ? () {
                              widget.onSave(
                                _qCtrl.text.trim(),
                                _aCtrl.text.trim(),
                              );
                              Navigator.pop(context);
                            }
                          : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: _canSave
                              ? const LinearGradient(
                                  colors: [
                                    AppColors.primary,
                                    AppColors.primaryFixedDim,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color:
                              _canSave ? null : AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: _canSave
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.22),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  )
                                ]
                              : [],
                        ),
                        child: Center(
                          child: Text(
                            _isEditing ? 'Save Changes' : 'Add Card',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _canSave
                                  ? AppColors.onPrimary
                                  : AppColors.outline,
                            ),
                          ),
                        ),
                      ),
                    ),
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
// REUSABLE TEXT FIELD FOR THE FORM SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _QATextField extends StatelessWidget {
  const _QATextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.iconColor,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final Color iconColor;
  final ValueChanged<String> onChanged;

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
        maxLines: 4,
        minLines: 2,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          color: AppColors.onSurface,
          height: 1.5,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurfaceVariant,
          ),
          hintText: hint,
          hintStyle: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: AppColors.outline.withOpacity(0.5),
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 10, top: 14),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 0, minHeight: 0),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADD CARD FAB
// ─────────────────────────────────────────────────────────────────────────────

class _AddCardFAB extends StatelessWidget {
  const _AddCardFAB({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onTap,
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      icon: const Icon(Icons.add_rounded, size: 24),
      label: Text(
        'Add Card',
        style: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w800,
          fontSize: 14,
          letterSpacing: 0.5,
        ),
      ),
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
