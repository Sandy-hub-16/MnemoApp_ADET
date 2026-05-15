import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import '../../landing_page/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'deck-quiz_screen.dart';
import 'edit_deck_screen.dart';
import 'create_deck_screen.dart';
import 'deck_study_screen.dart';
import '../../../business-layer/services/deck_service.dart';
import '../../../business-layer/services/export_service.dart';
import '../../../business-layer/services/share_service.dart';
import '../../../business-layer/services/deck_search_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DECK SCREEN  —  route: /decks
// Displays the main deck library with AI import, filters, and deck cards.
//
// SECTIONS:
//   1. Static content  — hero, search bar, filter chips, AI import, create card
//   2. Drafts          — unfinished decks (isDraft:true); tap → /create-deck
//   3. Recent Decks    — completed decks (isDraft:false); tap → /quiz
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// QUESTION TYPE ENUM
// ─────────────────────────────────────────────────────────────────────────────

enum QuestionType {
  multipleChoice,
  identification,
  both;

  String get apiValue {
    switch (this) {
      case QuestionType.multipleChoice:
        return 'multiple_choice';
      case QuestionType.identification:
        return 'identification';
      case QuestionType.both:
        return 'both';
    }
  }

  String get displayName {
    switch (this) {
      case QuestionType.multipleChoice:
        return 'Multiple Choice';
      case QuestionType.identification:
        return 'Identification';
      case QuestionType.both:
        return 'Both (50/50)';
    }
  }

  String get description {
    switch (this) {
      case QuestionType.multipleChoice:
        return 'Choose from 4 options per question';
      case QuestionType.identification:
        return 'Type the correct answer freely';
      case QuestionType.both:
        return 'Mix of both types, split evenly';
    }
  }

  IconData get icon {
    switch (this) {
      case QuestionType.multipleChoice:
        return Icons.radio_button_checked_rounded;
      case QuestionType.identification:
        return Icons.edit_note_rounded;
      case QuestionType.both:
        return Icons.auto_awesome_rounded;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI IMPORT DIALOGS
// ─────────────────────────────────────────────────────────────────────────────

/// Step 1 — Pick question type
Future<QuestionType?> _showQuestionTypeDialog(BuildContext context) {
  return showDialog<QuestionType>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: AppColors.surfaceContainerLowest,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryFixedDim],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.quiz_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Question Type',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onSurface,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Choose how your cards are tested',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Options ───────────────────────────────────────────────────
            ...QuestionType.values.map((type) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _QuestionTypeOption(
                    type: type,
                    onTap: () => Navigator.pop(ctx, type),
                  ),
                )),

            // ── Cancel ────────────────────────────────────────────────────
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _QuestionTypeOption extends StatelessWidget {
  const _QuestionTypeOption({required this.type, required this.onTap});

  final QuestionType type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.outlineVariant.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(type.icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type.displayName,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                  Text(
                    type.description,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.outline, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Step 2 — Pick category
Future<String?> _showCategoryDialog(BuildContext context) {
  const categories = [
    'Biology',
    'Physics',
    'Organic Chem',
    'World History',
    'Other',
  ];

  return showDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: AppColors.surfaceContainerLowest,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryFixedDim],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.category_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose Category',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onSurface,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Organize your deck by subject',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Options ───────────────────────────────────────────────────
            ...categories.map((category) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx, category),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.outlineVariant.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.label_rounded,
                                color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              category,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onSurface,
                              ),
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                              color: AppColors.outline, size: 20),
                        ],
                      ),
                    ),
                  ),
                )),

            // ── Cancel ────────────────────────────────────────────────────
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Step 3 — Pick number of questions, enforcing [maxCount].
Future<int?> _showQuestionCountDialog(BuildContext context, int maxCount) {
  int currentCount = (maxCount >= 10) ? 10 : maxCount;
  final TextEditingController controller =
      TextEditingController(text: currentCount.toString());

  return showDialog<int>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        void setCount(int value) {
          currentCount = value.clamp(1, maxCount);
          controller.text = currentCount.toString();
          controller.selection = TextSelection.fromPosition(
            TextPosition(offset: controller.text.length),
          );
        }

        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          backgroundColor: AppColors.surfaceContainerLowest,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────────────
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primaryFixedDim
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.format_list_numbered_rounded,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Number of Questions',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.onSurface,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            'Max $maxCount based on your content',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Counter display ──────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.outlineVariant.withOpacity(0.4),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Decrement
                      GestureDetector(
                        onTap: () {
                          if (currentCount > 1) {
                            setState(() => setCount(currentCount - 1));
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: currentCount > 1
                                ? AppColors.primaryContainer
                                : AppColors.outlineVariant.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.remove_rounded,
                            size: 22,
                            color: currentCount > 1
                                ? AppColors.primary
                                : AppColors.outline,
                          ),
                        ),
                      ),

                      // Count input
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: controller,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onSurface,
                            letterSpacing: -1,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (val) {
                            final parsed = int.tryParse(val);
                            if (parsed != null) {
                              setState(() => setCount(parsed));
                            }
                          },
                          onSubmitted: (val) {
                            final parsed = int.tryParse(val) ?? 1;
                            setState(() => setCount(parsed));
                          },
                        ),
                      ),

                      // Increment
                      GestureDetector(
                        onTap: () {
                          if (currentCount < maxCount) {
                            setState(() => setCount(currentCount + 1));
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: currentCount < maxCount
                                ? AppColors.primaryContainer
                                : AppColors.outlineVariant.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.add_rounded,
                            size: 22,
                            color: currentCount < maxCount
                                ? AppColors.primary
                                : AppColors.outline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── Quick select chips ───────────────────────────────────
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ([10, 15, 20, 25, maxCount]
                            .where((v) => v <= maxCount)
                            .toSet()
                            .toList()
                          ..sort())
                        .map((v) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () => setState(() => setCount(v)),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: currentCount == v
                                        ? AppColors.primary
                                        : AppColors.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: currentCount == v
                                          ? AppColors.primary
                                          : AppColors.outlineVariant,
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    v == maxCount ? 'Max ($v)' : '$v',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: currentCount == v
                                          ? AppColors.onPrimary
                                          : AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Warning if at max ────────────────────────────────────
                if (currentCount >= maxCount)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3CD),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFFFFD95C).withOpacity(0.6)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 15, color: Color(0xFF856404)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Maximum of $maxCount questions reached for this content.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: const Color(0xFF856404),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Action buttons ───────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx, null),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, currentCount),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          'Generate $currentCount Cards',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// PASTE NOTES DIALOG
// ─────────────────────────────────────────────────────────────────────────────

Future<String?> _showPasteNotesDialog(BuildContext context) {
  final TextEditingController textController = TextEditingController();
  final ValueNotifier<int> charCount = ValueNotifier(0);
  final ValueNotifier<bool> isEmpty = ValueNotifier(true);

  textController.addListener(() {
    charCount.value = textController.text.length;
    isEmpty.value = textController.text.trim().isEmpty;
  });

  return showDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: AppColors.surfaceContainerLowest,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryFixedDim],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.content_paste_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Paste Notes',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onSurface,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Paste or type your notes below',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  icon: Icon(Icons.close_rounded,
                      color: AppColors.onSurfaceVariant, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.all(6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Text Area ─────────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.outlineVariant.withOpacity(0.5),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Clipboard toolbar ──────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                    child: Row(
                      children: [
                        Icon(Icons.notes_rounded,
                            size: 14, color: AppColors.outline),
                        const SizedBox(width: 6),
                        Text(
                          'YOUR NOTES',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.outline,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const Spacer(),
                        // ── Paste from clipboard button ──────────────────
                        GestureDetector(
                          onTap: () async {
                            final data =
                                await Clipboard.getData(Clipboard.kTextPlain);
                            if (data?.text != null && data!.text!.isNotEmpty) {
                              textController.text = data.text!;
                              textController.selection =
                                  TextSelection.fromPosition(
                                TextPosition(
                                    offset: textController.text.length),
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.content_paste_go_rounded,
                                    size: 13, color: AppColors.primary),
                                const SizedBox(width: 5),
                                Text(
                                  'Paste',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // ── Clear button ─────────────────────────────────
                        ValueListenableBuilder<bool>(
                          valueListenable: isEmpty,
                          builder: (_, empty, __) => AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: empty ? 0.0 : 1.0,
                            child: GestureDetector(
                              onTap: () => textController.clear(),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.errorContainer.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline_rounded,
                                        size: 13, color: AppColors.error),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Clear',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.error,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),
                  Divider(
                    height: 1,
                    color: AppColors.outlineVariant.withOpacity(0.4),
                    indent: 14,
                    endIndent: 14,
                  ),

                  // ── TextField ──────────────────────────────────────────
                  SizedBox(
                    height: 220,
                    child: TextField(
                      controller: textController,
                      autofocus: true,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      keyboardType: TextInputType.multiline,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.onSurface,
                        height: 1.55,
                      ),
                      decoration: InputDecoration(
                        hintText:
                            'Paste your lecture notes, textbook content, or study material here…\n\nPress Ctrl+V or use the Paste button above.',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: AppColors.onSurfaceVariant.withOpacity(0.5),
                          fontWeight: FontWeight.w400,
                          height: 1.6,
                        ),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      ),
                    ),
                  ),

                  // ── Character count footer ─────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                    child: Row(
                      children: [
                        ValueListenableBuilder<int>(
                          valueListenable: charCount,
                          builder: (_, count, __) {
                            final Color countColor = count == 0
                                ? AppColors.outline.withOpacity(0.5)
                                : count < 100
                                    ? AppColors.error.withOpacity(0.8)
                                    : AppColors.primary;
                            return Row(
                              children: [
                                Icon(
                                  count < 100 && count > 0
                                      ? Icons.warning_amber_rounded
                                      : Icons.check_circle_outline_rounded,
                                  size: 12,
                                  color: count == 0
                                      ? AppColors.outline.withOpacity(0.5)
                                      : countColor,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  count == 0
                                      ? 'No content yet'
                                      : count < 100
                                          ? '$count chars — add more for better results'
                                          : '$count characters',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: count == 0
                                        ? AppColors.outline.withOpacity(0.5)
                                        : countColor,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Action buttons ────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx, null),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: isEmpty,
                    builder: (_, empty, __) => AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: empty ? 0.45 : 1.0,
                      child: ElevatedButton.icon(
                        onPressed: empty
                            ? null
                            : () =>
                                Navigator.pop(ctx, textController.text.trim()),
                        icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                        label: Text(
                          'Continue',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                          disabledBackgroundColor: AppColors.primary,
                          disabledForegroundColor: AppColors.onPrimary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
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
// ─────────────────────────────────────────────────────────────────────────────
// AI IMPORT HANDLER  (PDF + TXT, with question type & count dialogs)
// ─────────────────────────────────────────────────────────────────────────────

Future<void> handleUploadAndGenerateDeck(BuildContext context) async {
  // ── Step 1: Pick file (PDF or TXT) ────────────────────────────────────────
  FilePickerResult? result;
  try {
    result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'pdf'],
      withData: true,
    );
  } catch (_) {
    if (context.mounted) {
      _showErrorSnackBar(
          context, 'Could not open file picker. Please try again.');
    }
    return;
  }

  if (result == null || result.files.single.bytes == null) return;

  final fileBytes = result.files.single.bytes!;
  final fileName = result.files.single.name.toLowerCase();
  final isPdf = fileName.endsWith('.pdf');

  // Validate non-empty
  if (fileBytes.isEmpty) {
    if (context.mounted)
      _showErrorSnackBar(context, 'The selected file is empty.');
    return;
  }

  // ── Step 2: Question type dialog ──────────────────────────────────────────
  if (!context.mounted) return;
  final questionType = await _showQuestionTypeDialog(context);
  if (questionType == null) return; // user cancelled

  // ── Step 3: Category dialog ────────────────────────────────────────────────
  if (!context.mounted) return;
  final category = await _showCategoryDialog(context);
  if (category == null) return; // user cancelled

  // ── Step 4: Estimate max & show count dialog ───────────────────────────────
  // AI generation limits: Min 10, Max 30
  // For TXT: ~1 question per 300 chars of content, capped at 30, minimum 10.
  // For PDF: assume up to 30 (can't inspect without parsing), minimum 10.
  const int minAICards = 10;
  const int maxAICards = 30;

  int maxQuestions;
  if (isPdf) {
    maxQuestions = maxAICards;
  } else {
    final text = utf8.decode(fileBytes, allowMalformed: true);
    final estimatedMax =
        (text.trim().length / 300).ceil().clamp(minAICards, maxAICards);
    maxQuestions = estimatedMax;
  }

  if (!context.mounted) return;
  final questionCount = await _showQuestionCountDialog(context, maxQuestions);
  if (questionCount == null) return; // user cancelled

  // ── Step 5: Show loading overlay ──────────────────────────────────────────
  bool loadingDialogOpen = false;
  if (context.mounted) {
    loadingDialogOpen = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(height: 16),
                Text(
                  'Generating your deck…',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This may take a moment',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void safePopLoader() {
    if (loadingDialogOpen && context.mounted) {
      loadingDialogOpen = false;
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  try {
    // ── Step 6: Build request body ───────────────────────────────────────────
    Map<String, dynamic> requestBody;
    if (isPdf) {
      final base64Data = base64Encode(fileBytes);
      requestBody = {
        'fileBase64': base64Data,
        'fileType': 'pdf',
        'questionType': questionType.apiValue,
        'questionCount': questionCount,
      };
    } else {
      final text = utf8.decode(fileBytes, allowMalformed: true);
      if (text.trim().isEmpty) throw Exception('File is empty');
      requestBody = {
        'text': text,
        'fileType': 'txt',
        'questionType': questionType.apiValue,
        'questionCount': questionCount,
      };
    }

    // ── Step 7: Call Cloud Run endpoint ─────────────────────────────────────
    final response = await http
        .post(
          Uri.parse('https://generatedeck-x2xze3qnza-uc.a.run.app'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(requestBody),
        )
        .timeout(const Duration(seconds: 120));

    if (response.statusCode != 200) {
      throw Exception(
          'Server returned ${response.statusCode}: ${response.body}');
    }

    // ── Step 8: Parse response ───────────────────────────────────────────────
    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected response format from server.');
    }

    final rawCards = decoded['cards'];
    if (rawCards == null || rawCards is! List) {
      throw Exception('No cards returned from server.');
    }

    final cards = List<Map<String, dynamic>>.from(rawCards);
    if (cards.isEmpty) throw Exception('Server returned 0 cards.');

    final title = (decoded['title'] as String?)?.trim().isNotEmpty == true
        ? decoded['title'] as String
        : 'AI Generated Deck';

    // ── Step 9: Write to Firestore ───────────────────────────────────────────
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in.');

    final deckRef = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('decks')
        .add({
      'title': title,
      'tag': category,
      'isDraft': false,
      'visibility': 'private',
      'cardCount': cards.length,
      'targetCardCount': cards.length,
      'questionType': questionType.apiValue,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'progress': 0.0,
    });

    final batch = FirebaseFirestore.instance.batch();
    for (final card in cards) {
      final cardRef = deckRef.collection('cards').doc();

      final hasOptions = card.containsKey('options') &&
          card['options'] is List &&
          (card['options'] as List).isNotEmpty;

      int? correctIndex;
      if (hasOptions) {
        final options = card['options'] as List;
        final answer = (card['answer'] as String? ?? '').trim().toLowerCase();
        correctIndex = options.indexWhere(
          (opt) => opt.toString().trim().toLowerCase() == answer,
        );
        if (correctIndex == -1) correctIndex = 0;
      }

      batch.set(cardRef, {
        'question': card['question'] ?? '',
        'answer': card['answer'] ?? '',
        'type': hasOptions ? 'multiple_choice' : 'identification',
        'createdAt': FieldValue.serverTimestamp(),
        if (hasOptions) 'choices': card['options'],
        if (hasOptions && correctIndex != null) 'correctIndex': correctIndex,
      });
    }
    await batch.commit();

    // ── Step 8b: Soft under-delivery warning ─────────────────────────────────
    final threshold = (questionCount * 0.5).ceil();
    if (cards.length < threshold && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: Colors.white, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Only ${cards.length} of $questionCount cards were generated. You can add more cards manually.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFF59E0B), // amber-500
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          duration: const Duration(seconds: 5),
        ),
      );
    }

    // ── Step 9: Success ──────────────────────────────────────────────────────
    safePopLoader();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Deck created successfully!',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${cards.length} ${questionType.displayName} cards — "$title"',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.85),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF16A34A), // green-700
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  } catch (e) {
    safePopLoader();
    if (context.mounted) {
      _showErrorSnackBar(
          context,
          e.toString().contains('Exception:')
              ? e.toString().replaceFirst('Exception: ', '')
              : 'Something went wrong. Please try again.');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PASTE NOTES HANDLER
// ─────────────────────────────────────────────────────────────────────────────

Future<void> handlePasteNotesAndGenerateDeck(BuildContext context) async {
  // ── Step 1: Show paste dialog ──────────────────────────────────────────────
  if (!context.mounted) return;
  final pastedText = await _showPasteNotesDialog(context);
  if (pastedText == null || pastedText.trim().isEmpty) return;

  // ── Step 2: Question type dialog ───────────────────────────────────────────
  if (!context.mounted) return;
  final questionType = await _showQuestionTypeDialog(context);
  if (questionType == null) return;

  // ── Step 3: Category dialog ────────────────────────────────────────────────
  if (!context.mounted) return;
  final category = await _showCategoryDialog(context);
  if (category == null) return;

  // ── Step 4: Estimate max & show count dialog ───────────────────────────────
  const int minAICards = 10;
  const int maxAICards = 30;
  final estimatedMax =
      (pastedText.trim().length / 300).ceil().clamp(minAICards, maxAICards);

  if (!context.mounted) return;
  final questionCount = await _showQuestionCountDialog(context, estimatedMax);
  if (questionCount == null) return;

  // ── Step 5: Show loading overlay ───────────────────────────────────────────
  bool loadingDialogOpen = false;
  if (context.mounted) {
    loadingDialogOpen = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(height: 16),
                Text(
                  'Generating your deck…',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This may take a moment',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void safePopLoader() {
    if (loadingDialogOpen && context.mounted) {
      loadingDialogOpen = false;
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  try {
    // ── Step 6: Call Cloud Run endpoint ────────────────────────────────────
    final response = await http
        .post(
          Uri.parse('https://generatedeck-x2xze3qnza-uc.a.run.app'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'text': pastedText,
            'fileType': 'txt',
            'questionType': questionType.apiValue,
            'questionCount': questionCount,
          }),
        )
        .timeout(const Duration(seconds: 120));

    if (response.statusCode != 200) {
      throw Exception(
          'Server returned ${response.statusCode}: ${response.body}');
    }

    // ── Step 7: Parse response ──────────────────────────────────────────────
    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected response format from server.');
    }

    final rawCards = decoded['cards'];
    if (rawCards == null || rawCards is! List) {
      throw Exception('No cards returned from server.');
    }

    final cards = List<Map<String, dynamic>>.from(rawCards);
    if (cards.isEmpty) throw Exception('Server returned 0 cards.');

    final title = (decoded['title'] as String?)?.trim().isNotEmpty == true
        ? decoded['title'] as String
        : 'AI Generated Deck';

    // ── Step 8: Write to Firestore ──────────────────────────────────────────
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in.');

    final deckRef = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('decks')
        .add({
      'title': title,
      'tag': category,
      'isDraft': false,
      'visibility': 'private',
      'cardCount': cards.length,
      'targetCardCount': cards.length,
      'questionType': questionType.apiValue,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'progress': 0.0,
    });

    final batch = FirebaseFirestore.instance.batch();
    for (final card in cards) {
      final cardRef = deckRef.collection('cards').doc();

      final hasOptions = card.containsKey('options') &&
          card['options'] is List &&
          (card['options'] as List).isNotEmpty;

      int? correctIndex;
      if (hasOptions) {
        final options = card['options'] as List;
        final answer = (card['answer'] as String? ?? '').trim().toLowerCase();
        correctIndex = options.indexWhere(
          (opt) => opt.toString().trim().toLowerCase() == answer,
        );
        if (correctIndex == -1) correctIndex = 0;
      }

      batch.set(cardRef, {
        'question': card['question'] ?? '',
        'answer': card['answer'] ?? '',
        'type': hasOptions ? 'multiple_choice' : 'identification',
        'createdAt': FieldValue.serverTimestamp(),
        if (hasOptions) 'choices': card['options'],
        if (hasOptions && correctIndex != null) 'correctIndex': correctIndex,
      });
    }
    await batch.commit();

    // ── Step 8b: Soft under-delivery warning ────────────────────────────────
    final threshold = (questionCount * 0.5).ceil();
    if (cards.length < threshold && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: Colors.white, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Only ${cards.length} of $questionCount cards were generated. You can add more cards manually.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFF59E0B),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          duration: const Duration(seconds: 5),
        ),
      );
    }

    // ── Step 9: Success ─────────────────────────────────────────────────────
    safePopLoader();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Deck created successfully!',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${cards.length} ${questionType.displayName} cards — "$title"',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.85),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  } catch (e) {
    safePopLoader();
    if (context.mounted) {
      _showErrorSnackBar(
          context,
          e.toString().contains('Exception:')
              ? e.toString().replaceFirst('Exception: ', '')
              : 'Something went wrong. Please try again.');
    }
  }
}

void _showErrorSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ),
        ],
      ),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      duration: const Duration(seconds: 4),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// DECK HUB SCREEN
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

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _searchQuery = '';
  List<QueryDocumentSnapshot<Map<String, dynamic>>>? _cachedResults;
  final DeckSearchEngine<QueryDocumentSnapshot<Map<String, dynamic>>> _engine =
      DeckSearchEngine();

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      ShareService.repairCardCounts(uid: uid).catchError((_) {});
    }
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () async {
      final keyword = _searchController.text.trim().toLowerCase();
      if (_engine.length < 500) {
        if (mounted) {
          setState(() {
            _searchQuery = keyword;
            _cachedResults = null;
          });
        }
      } else {
        final activeTag =
            _selectedFilter == 0 ? null : _filters[_selectedFilter];
        try {
          await compute(runIsolateQuery, (
            index: _engine.snapshot(
                tagOf: (doc) => doc.data()['tag'] as String? ?? ''),
            keyword: keyword,
            tagFilter: activeTag,
          ));
          if (mounted) {
            setState(() {
              _searchQuery = keyword;
              _cachedResults = null;
            });
          }
        } catch (_) {
          if (mounted) {
            setState(() {
              _searchQuery = keyword;
              _cachedResults = null;
            });
          }
        }
      }
    });
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
      Navigator.pop(context);

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
      Navigator.pop(context);
      _showErrorSnackBar(context, 'Could not load draft. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: Stack(
        children: [
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
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            _HeroGreeting(),
                            const SizedBox(height: 20),
                            _SearchBar(controller: _searchController),
                            const SizedBox(height: 16),
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

                          // Rebuild the search index on every Firestore emission
                          _engine.rebuild(
                            allDocs,
                            (doc) =>
                                '${doc.data()['title'] ?? ''} ${doc.data()['tag'] ?? ''}'
                                    .toLowerCase(),
                          );

                          final selectedCategory = _filters[_selectedFilter];
                          final String? tagFilter =
                              selectedCategory == 'All Decks'
                                  ? null
                                  : selectedCategory;

                          // Apply search + tag filter via the engine
                          final filteredDocs =
                              (_cachedResults != null && _engine.length >= 500)
                                  ? _cachedResults!
                                  : _engine.query(
                                      _searchQuery,
                                      tagFilter: tagFilter,
                                      tagOf: (doc) =>
                                          doc.data()['tag'] as String? ?? '',
                                    );

                          final draftDocs = filteredDocs
                              .where((d) => d.data()['isDraft'] == true)
                              .toList();

                          final completedDocs = filteredDocs
                              .where((d) => d.data()['isDraft'] != true)
                              .toList();

                          final items = <Widget>[];

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

                          if (completedDocs.isEmpty) {
                            final hasDecksButFiltered =
                                allDocs.any((d) => d.data()['isDraft'] != true);
                            items.add(
                              Padding(
                                padding: const EdgeInsets.all(40),
                                child: hasDecksButFiltered
                                    ? Column(
                                        children: [
                                          Icon(
                                            Icons.search_off_rounded,
                                            size: 64,
                                            color: AppColors.outline
                                                .withOpacity(0.5),
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'No decks found',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.onSurface,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            _searchQuery.isNotEmpty
                                                ? 'No decks match "$_searchQuery". Try a different keyword or clear the filter.'
                                                : 'No decks match the active filter.',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 14,
                                              color: AppColors.onSurfaceVariant,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      )
                                    : Column(
                                        children: [
                                          Icon(Icons.layers_outlined,
                                              size: 64,
                                              color: AppColors.outline),
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
                                    visibility: deck['visibility'] as String? ??
                                        'private',
                                    clonedFromUsername:
                                        deck['clonedFromUsername'] as String?,
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
                      const SliverToBoxAdapter(child: SizedBox(height: 140)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
        _showErrorSnackBar(context, 'Failed to delete draft.');
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryFixedDim],
            ).createShader(bounds),
            child: Text(
              'Mnemo',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                fontStyle: FontStyle.italic,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.tertiary.withOpacity(0.15),
                  AppColors.primary.withOpacity(0.10),
                ],
              ),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppColors.tertiary.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.layers_rounded,
                  color: AppColors.tertiary,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  'LIBRARY',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.tertiary,
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
          'Your Deck Library',
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
          'Create, import, and organize your flashcard decks',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.onSurfaceVariant,
            height: 1.4,
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
  const _SearchBar({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.outlineVariant.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppColors.onSurface,
        ),
        decoration: InputDecoration(
          hintText: 'Search your decks...',
          hintStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppColors.onSurfaceVariant.withOpacity(0.6),
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: Icon(
              Icons.search_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, __) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  color: AppColors.onSurfaceVariant,
                  size: 20,
                ),
                onPressed: () => controller.clear(),
              );
            },
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryFixedDim],
                )
              : null,
          color: active ? null : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active
                ? AppColors.primary.withOpacity(0.3)
                : AppColors.outlineVariant.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
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
            color: active ? Colors.white : AppColors.onSurfaceVariant,
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
                  onTap: () async {
                    await handlePasteNotesAndGenerateDeck(context);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
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
                GestureDetector(
                  onTap: () => _showDraftMenu(context),
                  child: const Icon(Icons.more_vert_rounded,
                      color: Color(0xFFAA8800), size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),
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
    this.clonedFromUsername,
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
  final String? clonedFromUsername;

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
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
            if (widget.clonedFromUsername != null &&
                widget.clonedFromUsername!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.person_outline_rounded,
                    size: 11,
                    color: AppColors.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Cloned from @${widget.clonedFromUsername}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      color: AppColors.outline,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
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
                valueColor: AlwaysStoppedAnimation<Color>(widget.progressColor),
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
        onExport: () async {
          final format = await _showExportFormatDialog(context);
          if (format == null || !context.mounted) return;
          await ExportService.exportDeck(
            context: context,
            deckId: widget.deckId,
            deckTitle: widget.deckTitle,
            format: format,
          );
        },
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
    required this.onExport,
  });

  final String deckId;
  final String deckTitle;
  final String currentVisibility;
  final ValueChanged<String> onVisibilityChanged;
  final VoidCallback onExport;

  @override
  State<_DeckOptionsSheet> createState() => _DeckOptionsSheetState();
}

class _DeckOptionsSheetState extends State<_DeckOptionsSheet> {
  bool _isTogglingVisibility = false;

  void _handleEdit(BuildContext context) {
    Navigator.pop(context);
    Navigator.of(context).pushNamed(
      '/edit-deck',
      arguments:
          EditDeckArgs(deckId: widget.deckId, deckTitle: widget.deckTitle),
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

    // REPLACE WITH:
    try {
      await DeckService.deleteDeck(widget.deckId);
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.20),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete_rounded,
                      color: Colors.white, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Deck deleted',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '"${widget.deckTitle}" has been removed',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.85),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        _showErrorSnackBar(context, 'Failed to delete deck.');
      }
    }
  }

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

      widget.onVisibilityChanged(newVisibility);

      if (context.mounted) Navigator.pop(context);
    } on StateError catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        _showErrorSnackBar(context, e.message);
      }
    } on ArgumentError {
      if (context.mounted) Navigator.pop(context);
    } catch (e, st) {
      debugPrint('[ShareService.setVisibility] error: $e\n$st');
      if (context.mounted) {
        Navigator.pop(context);
        _showErrorSnackBar(
            context, 'Failed to update visibility. Please try again.');
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
            icon: Icons.auto_stories_rounded,
            label: 'Study This Deck',
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).pushNamed(
                '/study',
                arguments: StudyScreenArgs(
                    deckId: widget.deckId, deckTitle: widget.deckTitle),
              );
            },
          ),
          _SheetOption(
            icon: Icons.edit_outlined,
            label: 'Edit Deck',
            onTap: () => _handleEdit(context),
          ),
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
                      color: isPublic ? AppColors.onSurface : AppColors.primary,
                    ),
                  ),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                        color: isPublic ? AppColors.primary : AppColors.outline,
                      ),
                    ),
                  ),
                  onTap: () => _handleVisibilityToggle(context),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
          _SheetOption(
            icon: Icons.ios_share_rounded,
            label: 'Export Deck',
            onTap: () {
              Navigator.pop(context); // close options sheet
              widget.onExport();
            },
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

// ─────────────────────────────────────────────────────────────────────────────
// EXPORT FORMAT DIALOG
// ─────────────────────────────────────────────────────────────────────────────

Future<ExportFormat?> _showExportFormatDialog(BuildContext context) {
  return showModalBottomSheet<ExportFormat>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ExportFormatDialog(),
  );
}

class _ExportFormatDialog extends StatelessWidget {
  const _ExportFormatDialog();

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
          // ── Drag handle ──────────────────────────────────────────────────
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.outlineVariant,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 16),

          // ── Header ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryFixedDim],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.ios_share_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Export Deck',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'Choose a format',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── PDF option ───────────────────────────────────────────────────
          _SheetOption(
            icon: Icons.picture_as_pdf_rounded,
            label: 'Save as PDF',
            onTap: () => Navigator.pop(context, ExportFormat.pdf),
          ),

          // ── Plain Text option ────────────────────────────────────────────
          _SheetOption(
            icon: Icons.text_snippet_outlined,
            label: 'Save as Plain Text (.txt)',
            onTap: () => Navigator.pop(context, ExportFormat.plainText),
          ),

          // ── Cancel ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context, null),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHEET OPTION (shared by deck options and export format dialog)
// ─────────────────────────────────────────────────────────────────────────────

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
