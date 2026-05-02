import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import '../../landing_page/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'deck-quiz_screen.dart';
import 'edit_deck_screen.dart';
import 'create_deck_screen.dart';
import '../../../business-layer/services/deck_service.dart';
import '../../../business-layer/services/share_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DECK HUB SCREEN  —  route: /decks
// Displays the main deck library with AI import, filters, and deck cards.
//
// SECTIONS:
//   1. Static content  — hero, search bar, filter chips, AI import, create card
//   2. Drafts          — unfinished decks (isDraft:true); tap → /create-deck
//   3. Recent Decks    — completed decks (isDraft:false); tap → /quiz
// ─────────────────────────────────────────────────────────────────────────────

class DeckHubScreen extends StatelessWidget {
  const DeckHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _DeckHubScaffold();
  }
}

class _DeckHubScaffold extends StatefulWidget {
  const _DeckHubScaffold();

  @override
  State<_DeckHubScaffold> createState() => _DeckHubScaffoldState();
}

class _DeckHubScaffoldState extends State<_DeckHubScaffold> {
  int _selectedFilter = 0;

  static const _filters = [
    'All Decks',
    'Biology',
    'Physics',
    'Organic Chem',
    'World History',
  ];

  @override
  void initState() {
    super.initState();
    // Silently repair any stale cardCount values on public mirror docs.
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      ShareService.repairCardCounts(uid: uid).catchError((_) {});
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _deckStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('decks')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Fetches draft cards then navigates to /create-deck to continue the draft.
  Future<void> _continueDraft(
    BuildContext context,
    String deckId,
    Map<String, dynamic> data,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    try {
      final savedCards = await DeckService.getDeckCards(deckId);
      if (!context.mounted) return;
      Navigator.pop(context); // close loader

      Navigator.of(context).pushNamed(
        '/create-deck',
        arguments: ContinueDraftArgs(
          draftId: deckId,
          title: data['title'] ?? '',
          tag: data['tag'] ?? 'Other',
          targetCardCount: (data['targetCardCount'] ?? 10) as int,
          savedCards: savedCards,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // close loader
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not load draft. Please try again.',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: Stack(
        children: [
          // ── Decorative blobs ─────────────────────────────
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

          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const _DeckTopBar(),
                Expanded(
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      // ── 1. STATIC CONTENT ──────────────────────────────
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            _HeroGreeting(),
                            const SizedBox(height: 20),
                            _SearchBar(),
                            const SizedBox(height: 16),

                            // FILTERS
                            SizedBox(
                              height: 40,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _filters.length + 1,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (context, i) {
                                  if (i == _filters.length) {
                                    return _FilterChip(
                                        label: '+ Add Filter',
                                        active: false,
                                        onTap: () {});
                                  }
                                  return _FilterChip(
                                    label: _filters[i],
                                    active: _selectedFilter == i,
                                    onTap: () =>
                                        setState(() => _selectedFilter = i),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 28),
                            _AIImportCard(),
                            const SizedBox(height: 16),
                            _CreateDeckCard(),
                            const SizedBox(height: 28),
                          ]),
                        ),
                      ),

                      // ── 2. DYNAMIC CONTENT (drafts + completed decks) ──
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _deckStream(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 40),
                                child: Center(
                                  child: CircularProgressIndicator(
                                      color: AppColors.primary),
                                ),
                              ),
                            );
                          }

                          final allDocs = snapshot.data?.docs ?? [];

                          // ── Split into drafts vs completed ──────────────
                          final draftDocs = allDocs
                              .where((d) => d.data()['isDraft'] == true)
                              .toList();

                          final selectedCategory = _filters[_selectedFilter];
                          final completedDocs = allDocs
                              .where((d) => d.data()['isDraft'] != true)
                              .where((d) => selectedCategory == 'All Decks'
                                  ? true
                                  : d.data()['tag'] == selectedCategory)
                              .toList();

                          // ── Build list items ────────────────────────────
                          final items = <Widget>[];

                          // DRAFTS SECTION
                          if (draftDocs.isNotEmpty) {
                            items.add(
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 0, 20, 16),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF3CD),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.edit_note_rounded,
                                            size: 14,
                                            color: Color(0xFF856404),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'DRAFTS',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: const Color(0xFF856404),
                                              letterSpacing: 1.0,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Unfinished Decks',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );

                            for (final doc in draftDocs) {
                              final data = doc.data();
                              items.add(
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(20, 0, 20, 12),
                                  child: _DraftDeckCard(
                                    deckId: doc.id,
                                    data: data,
                                    onContinue: () =>
                                        _continueDraft(context, doc.id, data),
                                    onDelete: () => _confirmDeleteDraft(context,
                                        doc.id, data['title'] ?? 'Untitled'),
                                  ),
                                ),
                              );
                            }

                            // Divider between sections
                            items.add(
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 8, 20, 24),
                                child: Divider(
                                  color:
                                      AppColors.outlineVariant.withOpacity(0.4),
                                  thickness: 1,
                                ),
                              ),
                            );
                          }

                          // RECENT DECKS HEADER
                          items.add(
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                              child: Text(
                                'Recent Decks',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.onSurface,
                                ),
                              ),
                            ),
                          );

                          // COMPLETED DECKS or EMPTY STATE
                          if (completedDocs.isEmpty) {
                            items.add(
                              Padding(
                                padding: const EdgeInsets.all(40),
                                child: Column(
                                  children: [
                                    Icon(Icons.layers_outlined,
                                        size: 64, color: AppColors.outline),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No decks yet',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Create your first deck to get started!',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          } else {
                            for (final doc in completedDocs) {
                              final deck = doc.data();
                              items.add(
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(20, 0, 20, 12),
                                  child: _DeckCard(
                                    deckId: doc.id,
                                    deckTitle: deck['title'] ?? 'Untitled',
                                    tag: deck['tag'] ?? 'Other',
                                    tagColor: AppColors.secondaryContainer,
                                    tagTextColor:
                                        AppColors.onSecondaryContainer,
                                    title: deck['title'] ?? 'Untitled',
                                    subtitle: 'Tap to view cards',
                                    progress:
                                        (deck['progress'] ?? 0.0).toDouble(),
                                    progressColor: AppColors.primary,
                                    visibility: deck['visibility'] as String? ?? 'private',
                                  ),
                                ),
                              );
                            }
                          }

                          return SliverList(
                            delegate: SliverChildListDelegate(items),
                          );
                        },
                      ),

                      // ── 3. BOTTOM SPACING ──────────────────────────────
                      const SliverToBoxAdapter(child: SizedBox(height: 140)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: const _QuickAddFAB(),
      bottomNavigationBar: const _DeckBottomNavBar(activeIndex: 1),
    );
  }

  Future<void> _confirmDeleteDraft(
      BuildContext context, String deckId, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: AppColors.surfaceContainerLowest,
        title: Text(
          'Delete draft "$title"?',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
          ),
        ),
        content: Text(
          'This will permanently delete this unfinished deck. This action cannot be undone.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: AppColors.onSurfaceVariant,
          ),
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
            child: Text('Delete',
                style: GoogleFonts.plusJakartaSans(
                    color: AppColors.error, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    try {
      await DeckService.deleteDeck(deckId);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete draft.',
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
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOP BAR
// ─────────────────────────────────────────────────────────────────────────────

class _DeckTopBar extends StatelessWidget {
  const _DeckTopBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background.withOpacity(0.80),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryContainer,
              border: Border.all(
                color: AppColors.primary.withOpacity(0.2),
                width: 2,
              ),
            ),
            child: const Icon(Icons.person_rounded,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 10),
          Text(
            'My Decks',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              letterSpacing: -0.4,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: AppColors.onSurface.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.cloud_done_outlined,
                    color: AppColors.primary, size: 18),
                const SizedBox(width: 5),
                Text(
                  'SYNCED',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    letterSpacing: 1.2,
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
// HERO GREETING
// ─────────────────────────────────────────────────────────────────────────────

class _HeroGreeting extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hello, Active Scholar! 👋',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
            letterSpacing: -0.6,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Ready to master your knowledge today?',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SEARCH BAR
// ─────────────────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
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
        style: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          color: AppColors.onSurface,
        ),
        decoration: InputDecoration(
          hintText: 'Search your knowledge base...',
          hintStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            color: AppColors.outline.withOpacity(0.6),
          ),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 6),
            child:
                Icon(Icons.search_rounded, color: AppColors.outline, size: 22),
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FILTER CHIP
// ─────────────────────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(999),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: active ? AppColors.onPrimary : AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI IMPORT CARD
// ─────────────────────────────────────────────────────────────────────────────

class _AIImportCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
            color: AppColors.primary.withOpacity(0.28),
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
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Smart AI Import',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    'Convert any content into flashcards',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.75),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _ImportOption(
                  icon: Icons.upload_file_rounded,
                  label: 'Upload PDF / TXT',
                  onTap: () async {
                    await handleUploadAndGenerateDeck(context);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ImportOption(
                  icon: Icons.content_paste_rounded,
                  label: 'Paste Notes',
                  onTap: () {},
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> handleUploadAndGenerateDeck(BuildContext context) async {
  try {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
      withData: true,
    );

    if (result == null || result.files.single.bytes == null) return;

    final fileBytes = result.files.single.bytes!;
    final text = utf8.decode(fileBytes);

    if (text.trim().isEmpty) throw Exception("File is empty");

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final response = await http.post(
      Uri.parse("https://generatedeck-x2xze3qnza-uc.a.run.app"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"text": text}),
    );

    if (response.statusCode != 200) throw Exception("Failed to generate deck");

    final data = jsonDecode(response.body);
    final cards = List<Map<String, dynamic>>.from(data['cards']);
    final title = data['title'] as String? ?? 'AI Generated Deck';

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final deckRef = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('decks')
        .add({
      "title": title,
      "tag": "AI",
      "isDraft": false,
      "visibility": "private",
      "cardCount": cards.length,
      "targetCardCount": cards.length,
      "createdAt": FieldValue.serverTimestamp(),
      "updatedAt": FieldValue.serverTimestamp(),
      "progress": 0.0,
    });

    final batch = FirebaseFirestore.instance.batch();
    for (final card in cards) {
      final cardRef = deckRef.collection('cards').doc();
      batch.set(cardRef, {
        "question": card['question'],
        "answer": card['answer'],
        "type": "identification",
      });
    }
    await batch.commit();

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Deck created successfully!")),
    );
  } catch (e) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error: $e")),
    );
  }
}

class _ImportOption extends StatelessWidget {
  const _ImportOption({
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CREATE DECK CARD (dashed border)
// ─────────────────────────────────────────────────────────────────────────────

class _CreateDeckCard extends StatefulWidget {
  @override
  State<_CreateDeckCard> createState() => _CreateDeckCardState();
}

class _CreateDeckCardState extends State<_CreateDeckCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed('/create-deck'),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 24),
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _hovered
                      ? AppColors.primaryContainer
                      : AppColors.surfaceContainerLow,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: _hovered ? AppColors.primary : AppColors.outline,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create New Deck',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                  Text(
                    'Start from scratch manually',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DRAFT DECK CARD
// Visually distinct amber-tinted card for unfinished decks.
// Tapping routes to /create-deck to continue the draft.
// ─────────────────────────────────────────────────────────────────────────────

class _DraftDeckCard extends StatelessWidget {
  const _DraftDeckCard({
    required this.deckId,
    required this.data,
    required this.onContinue,
    required this.onDelete,
  });

  final String deckId;
  final Map<String, dynamic> data;
  final VoidCallback onContinue;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final title = data['title'] as String? ?? 'Untitled';
    final tag = data['tag'] as String? ?? 'Other';
    final cardCount = (data['cardCount'] ?? 0) as int;
    final targetCardCount = (data['targetCardCount'] ?? 10) as int;
    final ratio = targetCardCount > 0
        ? (cardCount / targetCardCount).clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      onTap: onContinue,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          // Warm amber-tinted background to signal "unfinished"
          color: const Color(0xFFFFFBF0),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFFFD95C).withOpacity(0.7),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD95C).withOpacity(0.15),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row: tag + DRAFT badge + menu ────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    // Subject tag
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBA0),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        tag.toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF856404),
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // DRAFT badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF856404).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: const Color(0xFF856404).withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.hourglass_top_rounded,
                            size: 10,
                            color: Color(0xFF856404),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'DRAFT',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF856404),
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Delete button (only action available for drafts)
                GestureDetector(
                  onTap: () => _showDraftMenu(context),
                  child: const Icon(Icons.more_vert_rounded,
                      color: Color(0xFFAA8800), size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Title ────────────────────────────────────────────────────
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap to continue building this deck',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: const Color(0xFFAA8800),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),

            // ── Completion progress ──────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CARDS COMPLETED',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFAA8800),
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  '$cardCount / $targetCardCount',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFAA8800),
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor: const Color(0xFFFFD95C).withOpacity(0.25),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFFFFB800)),
              ),
            ),
            const SizedBox(height: 14),

            // ── Continue CTA ─────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB800),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.edit_rounded, size: 14, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    'Continue Draft',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
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

  void _showDraftMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _DraftOptionsSheet(
        deckId: deckId,
        deckTitle: data['title'] ?? 'Untitled',
        onContinue: onContinue,
        onDelete: onDelete,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DRAFT OPTIONS SHEET
// Limited options: Continue Draft + Delete. No quiz/edit.
// ─────────────────────────────────────────────────────────────────────────────

class _DraftOptionsSheet extends StatelessWidget {
  const _DraftOptionsSheet({
    required this.deckId,
    required this.deckTitle,
    required this.onContinue,
    required this.onDelete,
  });

  final String deckId;
  final String deckTitle;
  final VoidCallback onContinue;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.outlineVariant,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 12),

          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.hourglass_top_rounded,
                          size: 11, color: Color(0xFF856404)),
                      const SizedBox(width: 4),
                      Text(
                        'DRAFT',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF856404),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    deckTitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Locked notice
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline_rounded,
                      size: 16, color: AppColors.outline),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Finish this deck to unlock Quiz & Edit',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          _SheetOption(
            icon: Icons.edit_rounded,
            label: 'Continue Draft',
            color: const Color(0xFFAA8800),
            onTap: () {
              Navigator.pop(context);
              onContinue();
            },
          ),
          _SheetOption(
            icon: Icons.delete_outline_rounded,
            label: 'Delete Draft',
            color: AppColors.error,
            onTap: () {
              Navigator.pop(context);
              onDelete();
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DECK CARD (completed decks only)
// ─────────────────────────────────────────────────────────────────────────────

class _DeckCard extends StatefulWidget {
  const _DeckCard({
    required this.deckId,
    required this.deckTitle,
    required this.tag,
    required this.tagColor,
    required this.tagTextColor,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.progressColor,
    required this.visibility,
  });

  final String deckId;
  final String deckTitle;
  final Color tagColor;
  final Color tagTextColor;
  final String tag;
  final String title;
  final String subtitle;
  final double progress;
  final Color progressColor;
  final String visibility;

  @override
  State<_DeckCard> createState() => _DeckCardState();
}

class _DeckCardState extends State<_DeckCard> {
  late String _currentVisibility;

  @override
  void initState() {
    super.initState();
    _currentVisibility = widget.visibility;
  }

  @override
  void didUpdateWidget(_DeckCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visibility != widget.visibility) {
      _currentVisibility = widget.visibility;
    }
  }

  void _onVisibilityChanged(String newVisibility) {
    setState(() => _currentVisibility = newVisibility);
  }

  @override
  Widget build(BuildContext context) {
    final isPublic = _currentVisibility == 'public';

    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed(
        '/quiz',
        arguments: QuizArgs(deckId: widget.deckId, deckTitle: widget.deckTitle),
      ),
      child: Container(
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
            // ── Tag + Visibility chip + More icon ─────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: widget.tagColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        widget.tag.toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: widget.tagTextColor,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // ── Visibility chip ──────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPublic
                            ? AppColors.primary.withOpacity(0.10)
                            : AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: isPublic
                              ? AppColors.primary.withOpacity(0.35)
                              : AppColors.outlineVariant,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPublic
                                ? Icons.public_rounded
                                : Icons.lock_outline_rounded,
                            size: 11,
                            color: isPublic
                                ? AppColors.primary
                                : AppColors.outline,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isPublic ? 'Public' : 'Private',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: isPublic
                                  ? AppColors.primary
                                  : AppColors.outline,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => _showDeckMenu(context),
                  child: Icon(Icons.more_vert_rounded,
                      color: AppColors.outline, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Title + subtitle ──────────────────────────────────────
            Text(
              widget.title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.subtitle,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),

            // ── Progress bar ──────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'MASTERY PROGRESS',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.outline,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  '${(widget.progress * 100).round()}%',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.outline,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: widget.progress,
                minHeight: 8,
                backgroundColor: AppColors.outlineVariant.withOpacity(0.25),
                valueColor:
                    AlwaysStoppedAnimation<Color>(widget.progressColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeckMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _DeckOptionsSheet(
        deckId: widget.deckId,
        deckTitle: widget.deckTitle,
        currentVisibility: _currentVisibility,
        onVisibilityChanged: _onVisibilityChanged,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DECK OPTIONS SHEET (completed decks)
// ─────────────────────────────────────────────────────────────────────────────

class _DeckOptionsSheet extends StatefulWidget {
  const _DeckOptionsSheet({
    required this.deckId,
    required this.deckTitle,
    required this.currentVisibility,
    required this.onVisibilityChanged,
  });

  final String deckId;
  final String deckTitle;
  final String currentVisibility;
  final ValueChanged<String> onVisibilityChanged;

  @override
  State<_DeckOptionsSheet> createState() => _DeckOptionsSheetState();
}

class _DeckOptionsSheetState extends State<_DeckOptionsSheet> {
  bool _isTogglingVisibility = false;

  void _handleEdit(BuildContext context) {
    Navigator.pop(context);
    Navigator.of(context).pushNamed(
      '/edit-deck',
      arguments: EditDeckArgs(deckId: widget.deckId, deckTitle: widget.deckTitle),
    );
  }

  void _handleDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: AppColors.surfaceContainerLowest,
        title: Text(
          'Delete "${widget.deckTitle}"?',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
          ),
        ),
        content: Text(
          'This will permanently delete the deck and all its cards. This action cannot be undone.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: AppColors.onSurfaceVariant,
          ),
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
            child: Text('Delete',
                style: GoogleFonts.plusJakartaSans(
                    color: AppColors.error, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    Navigator.pop(context);

    try {
      await DeckService.deleteDeck(widget.deckId);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete deck.',
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
    }
  }

  // ── Visibility toggle ───────────────────────────────────────────────────

  Future<void> _handleVisibilityToggle(BuildContext context) async {
    if (_isTogglingVisibility) return;

    final newVisibility =
        widget.currentVisibility == 'public' ? 'private' : 'public';

    setState(() => _isTogglingVisibility = true);

    try {
      await ShareService.setVisibility(
        deckId: widget.deckId,
        visibility: newVisibility,
      );

      // Update the card chip immediately via callback
      widget.onVisibilityChanged(newVisibility);

      if (context.mounted) Navigator.pop(context);
    } on StateError catch (e) {
      // Draft deck — cannot be shared
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.message,
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          ),
        );
      }
    } on ArgumentError {
      // Visibility already equals requested value — silently dismiss
      if (context.mounted) Navigator.pop(context);
    } catch (e, st) {
      // FirebaseException or any other network error
      debugPrint('[ShareService.setVisibility] error: $e\n$st');
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update visibility. Please try again.',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTogglingVisibility = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPublic = widget.currentVisibility == 'public';

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.outlineVariant,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 8),
          _SheetOption(
            icon: Icons.play_arrow_rounded,
            label: 'Study This Deck',
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).pushNamed(
                '/quiz',
                arguments:
                    QuizArgs(deckId: widget.deckId, deckTitle: widget.deckTitle),
              );
            },
          ),
          _SheetOption(
            icon: Icons.edit_outlined,
            label: 'Edit Deck',
            onTap: () => _handleEdit(context),
          ),
          // ── Visibility toggle option ──────────────────────────────────
          _isTogglingVisibility
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              : ListTile(
                  leading: Icon(
                    isPublic
                        ? Icons.lock_outline_rounded
                        : Icons.public_rounded,
                    color: isPublic
                        ? AppColors.onSurfaceVariant
                        : AppColors.primary,
                    size: 22,
                  ),
                  title: Text(
                    isPublic ? 'Make Private' : 'Make Public',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isPublic
                          ? AppColors.onSurface
                          : AppColors.primary,
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPublic
                          ? AppColors.primary.withOpacity(0.10)
                          : AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isPublic
                            ? AppColors.primary.withOpacity(0.35)
                            : AppColors.outlineVariant,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      isPublic ? 'Public' : 'Private',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isPublic
                            ? AppColors.primary
                            : AppColors.outline,
                      ),
                    ),
                  ),
                  onTap: () => _handleVisibilityToggle(context),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
          _SheetOption(
            icon: Icons.delete_outline_rounded,
            label: 'Delete Deck',
            color: AppColors.error,
            onTap: () => _handleDelete(context),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  const _SheetOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.onSurface;
    return ListTile(
      leading: Icon(icon, color: c, size: 22),
      title: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: c,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QUICK ADD FAB
// ─────────────────────────────────────────────────────────────────────────────

class _QuickAddFAB extends StatelessWidget {
  const _QuickAddFAB();

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () {},
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      icon: const Icon(Icons.add_rounded, size: 24),
      label: Text(
        'Quick Add',
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
// BOTTOM NAV BAR
// ─────────────────────────────────────────────────────────────────────────────

class _DeckBottomNavBar extends StatelessWidget {
  const _DeckBottomNavBar({required this.activeIndex});
  final int activeIndex;

  static const _items = [
    _NavItem(icon: Icons.home_outlined, label: 'Home', route: '/home'),
    _NavItem(icon: Icons.layers_outlined, label: 'Decks', route: '/decks'),
    _NavItem(
        icon: Icons.explore_outlined, label: 'Discover', route: '/discover'),
    _NavItem(
        icon: Icons.analytics_outlined, label: 'Progress', route: '/progress'),
    _NavItem(
        icon: Icons.person_outline_rounded,
        label: 'Profile',
        route: '/profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withOpacity(0.06),
            blurRadius: 32,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _items.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              final active = i == activeIndex;

              return GestureDetector(
                onTap: () {
                  if (!active) {
                    Navigator.of(context).pushReplacementNamed(item.route);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.primaryContainer.withOpacity(0.45)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        active ? _filledIcon(item.icon) : item.icon,
                        size: 24,
                        color: active
                            ? AppColors.primary
                            : AppColors.onSurfaceVariant,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: active
                              ? AppColors.primary
                              : AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  static final _filledIconMap = {
    Icons.home_outlined: Icons.home_rounded,
    Icons.layers_outlined: Icons.layers_rounded,
    Icons.explore_outlined: Icons.explore_rounded,
    Icons.analytics_outlined: Icons.analytics_rounded,
    Icons.person_outline_rounded: Icons.person_rounded,
  };

  IconData _filledIcon(IconData icon) => _filledIconMap[icon] ?? icon;
}

class _NavItem {
  const _NavItem(
      {required this.icon, required this.label, required this.route});
  final IconData icon;
  final String label;
  final String route;
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
