import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../landing_page/app_theme.dart';

class StudyScreenArgs {
  final String deckId;
  final String deckTitle;

  /// When set, the screen scrolls to this card and highlights it.
  /// Matched by comparing against card['question'].
  final String? highlightQuestion;

  StudyScreenArgs({
    required this.deckId,
    required this.deckTitle,
    this.highlightQuestion,
  });
}

class DeckStudyScreen extends StatefulWidget {
  const DeckStudyScreen({super.key});

  @override
  State<DeckStudyScreen> createState() => _DeckStudyScreenState();
}

class _DeckStudyScreenState extends State<DeckStudyScreen> {
  List<Map<String, dynamic>> _cards = [];
  Map<String, dynamic>? _deckData;
  bool _isLoading = true;
  String? _error;
  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey> _cardKeys = [];
  String? _highlightQuestion;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments as StudyScreenArgs;
    _highlightQuestion = args.highlightQuestion;
    _loadDeckAndCards(args.deckId);
  }

  Future<void> _loadDeckAndCards(String deckId) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Not signed in');

      final deckDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('decks')
          .doc(deckId)
          .get();

      if (!deckDoc.exists) throw Exception('Deck not found');

      final cardsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('decks')
          .doc(deckId)
          .collection('cards')
          .get();

      final cards = cardsSnapshot.docs.map((doc) => doc.data()).toList();

      // Build one GlobalKey per card for targeted scrolling
      final keys = List.generate(cards.length, (_) => GlobalKey());

      setState(() {
        _deckData = deckDoc.data();
        _cards = cards;
        _cardKeys
          ..clear()
          ..addAll(keys);
        _isLoading = false;
      });

      // Scroll to highlighted card after the list has been built
      if (_highlightQuestion != null && _highlightQuestion!.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToHighlighted();
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _scrollToHighlighted() {
    final target = _highlightQuestion;
    if (target == null) return;

    final idx = _cards.indexWhere(
      (c) => (c['question'] as String? ?? '') == target,
    );
    if (idx < 0 || idx >= _cardKeys.length) return;

    final ctx = _cardKeys[idx].currentContext;
    if (ctx == null) return;

    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      alignment: 0.15, // slight top offset so card isn't right at the edge
    );
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as StudyScreenArgs;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_rounded, color: AppColors.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Browse Cards',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 64, color: AppColors.error),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to load deck',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            color: AppColors.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : _cards.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.layers_outlined,
                                size: 64, color: AppColors.outline),
                            const SizedBox(height: 16),
                            Text(
                              'No cards in this deck',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(20),
                      children: [
                        _DeckDetailsHeader(
                          deckTitle: args.deckTitle,
                          deckData: _deckData!,
                          cardCount: _cards.length,
                        ),
                        const SizedBox(height: 24),
                        ..._cards.asMap().entries.map((entry) {
                          final index = entry.key;
                          final card = entry.value;
                          final question = card['question'] as String? ?? '';
                          final isHighlighted = _highlightQuestion != null &&
                              _highlightQuestion == question;
                          return Padding(
                            key: _cardKeys.length > index
                                ? _cardKeys[index]
                                : null,
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _CardItem(
                              cardNumber: index + 1,
                              question: question,
                              answer: card['answer'] ?? '',
                              isHighlighted: isHighlighted,
                            ),
                          );
                        }),
                        const SizedBox(height: 40),
                      ],
                    ),
    );
  }
}

class _DeckDetailsHeader extends StatelessWidget {
  const _DeckDetailsHeader({
    required this.deckTitle,
    required this.deckData,
    required this.cardCount,
  });

  final String deckTitle;
  final Map<String, dynamic> deckData;
  final int cardCount;

  @override
  Widget build(BuildContext context) {
    final tag = deckData['tag'] as String? ?? 'Other';
    final clonedFromUsername = deckData['clonedFromUsername'] as String?;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryFixedDim],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.auto_stories_rounded,
                    color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deckTitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      tag,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.75),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  icon: Icons.layers_rounded,
                  label: 'Cards',
                  value: '$cardCount',
                ),
                Container(
                    width: 1, height: 32, color: Colors.white.withOpacity(0.2)),
                _StatItem(
                  icon: Icons.category_rounded,
                  label: 'Category',
                  value: tag,
                ),
              ],
            ),
          ),
          if (clonedFromUsername != null && clonedFromUsername.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_outline_rounded,
                      size: 14, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    'Created by $clonedFromUsername',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            color: Colors.white.withOpacity(0.75),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _CardItem extends StatelessWidget {
  const _CardItem({
    required this.cardNumber,
    required this.question,
    required this.answer,
    this.isHighlighted = false,
  });

  final int cardNumber;
  final String question;
  final String answer;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isHighlighted
            ? AppColors.errorContainer.withOpacity(0.18)
            : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHighlighted
              ? AppColors.error.withOpacity(0.45)
              : AppColors.outlineVariant.withOpacity(0.3),
          width: isHighlighted ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isHighlighted
                ? AppColors.error.withOpacity(0.08)
                : AppColors.onSurface.withOpacity(0.04),
            blurRadius: isHighlighted ? 20 : 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card number badge + optional "Needs Review" pill
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryFixedDim],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Card $cardNumber',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (isHighlighted) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.error.withOpacity(0.3), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.flag_rounded,
                          color: AppColors.error, size: 11),
                      const SizedBox(width: 4),
                      Text(
                        'Needs Review',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.error,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.help_outline_rounded,
                    color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Question',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      question,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            height: 1,
            color: AppColors.outlineVariant.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.tertiaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.check_circle_outline_rounded,
                    color: AppColors.tertiary, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Answer',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.tertiary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      answer,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
