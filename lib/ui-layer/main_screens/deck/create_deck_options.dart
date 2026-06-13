import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../landing_page/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CREATE DECK OPTIONS
//
// Shared widgets and handlers for creating decks (AI and manual).
// Used by both HomeScreen and DeckHubScreen.
//
// PUBLIC API:
//   QuestionType                       — enum
//   handleUploadAndGenerateDeck()      — AI import via file upload
//   handlePasteNotesAndGenerateDeck()  — AI import via pasted text
//   AIImportCard                       — widget: "Smart AI Import" card
//   CreateDeckCard                     — widget: dashed manual-create card
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
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
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
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
                      child: const Icon(Icons.numbers_rounded,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Number of Cards',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.onSurface,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            'Max $maxCount cards for this content',
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
                const SizedBox(height: 24),

                // ── Stepper ──────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Decrement
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
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
                      ),

                      // Count input
                      SizedBox(
                        width: 100,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.text,
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
                      ),

                      // Increment
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
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
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
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
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () async {
                              final data =
                                  await Clipboard.getData(Clipboard.kTextPlain);
                              if (data?.text != null &&
                                  data!.text!.isNotEmpty) {
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
                        ),
                        const SizedBox(width: 6),
                        // ── Clear button ─────────────────────────────────
                        ValueListenableBuilder<bool>(
                          valueListenable: isEmpty,
                          builder: (_, empty, __) => AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: empty ? 0.0 : 1.0,
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () => textController.clear(),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppColors.errorContainer
                                        .withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.clear_rounded,
                                          size: 13, color: AppColors.error),
                                      const SizedBox(width: 5),
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
                        ),
                      ],
                    ),
                  ),
                  // ── Text field ────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                    child: TextField(
                      controller: textController,
                      maxLines: 8,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: AppColors.onSurface,
                        height: 1.5,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Type or paste your notes here…',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: AppColors.outline.withOpacity(0.6),
                        ),
                      ),
                    ),
                  ),
                  // ── Character count ───────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                    child: ValueListenableBuilder<int>(
                      valueListenable: charCount,
                      builder: (_, count, __) {
                        const maxChars = 10000;
                        final countColor = count > maxChars * 0.9
                            ? AppColors.error
                            : count > maxChars * 0.7
                                ? const Color(0xFFF59E0B)
                                : AppColors.outline;
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Icon(
                              Icons.text_fields_rounded,
                              size: 11,
                              color: count == 0
                                  ? AppColors.outline.withOpacity(0.5)
                                  : countColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$count / $maxChars',
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
// ERROR SNACK BAR
// ─────────────────────────────────────────────────────────────────────────────

void showCreateDeckErrorSnackBar(BuildContext context, String message) {
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

/// Estimates whether a PDF is scanned/image-based by checking average bytes
/// per page. Scanned pages are image-heavy (~200 KB+), text pages are lean
/// (~10–50 KB). 150 KB per page is a conservative threshold.
bool _isLikelyScannedPdf(Uint8List bytes, int pageCount) {
  if (pageCount <= 0) return false;
  final bytesPerPage = bytes.length / pageCount;
  return bytesPerPage > 150 * 1024; // 150 KB per page
}

// ─────────────────────────────────────────────────────────────────────────────
// DETAIL FILTERING HELPERS
// ─────────────────────────────────────────────────────────────────────────────

/// Scans raw PDF bytes for the /Count dictionary entry to read total pages.
/// No external package needed — works on any text-based PDF.
int _estimatePdfPageCount(Uint8List bytes) {
  try {
    final raw = String.fromCharCodes(
      bytes.map((b) => (b >= 32 && b < 127) ? b : 32),
    );
    final regex = RegExp(r'/Count\s+(\d+)');
    final matches = regex.allMatches(raw);
    if (matches.isNotEmpty) {
      return matches
          .map((m) => int.tryParse(m.group(1) ?? '0') ?? 0)
          .reduce((a, b) => a > b ? a : b);
    }
  } catch (_) {}
  return 0; // unknown — caller should skip the dialog
}

/// Estimates "pages" for plain-text content (≈ 3 000 chars per page).
int _estimateTxtPageCount(int charCount) =>
    (charCount / 3000).ceil().clamp(1, 500);

// ─────────────────────────────────────────────────────────────────────────────
// PAGE RANGE DIALOG
// ─────────────────────────────────────────────────────────────────────────────

Future<int?> _showPageRangeDialog(
  BuildContext context, {
  required int totalPages,
  required bool isPdf,
  bool isScanned = false,
}) {
  int currentPages = totalPages;
  final controller = TextEditingController(text: '$totalPages');

  // Build chip options highest → lowest
  List<int> buildOptions() {
    final opts = <int>{totalPages};
    for (final f in [0.75, 0.5, 0.25]) {
      final v = (totalPages * f).round();
      if (v >= 1 && v < totalPages) opts.add(v);
    }
    for (final v in [20, 15, 10, 5]) {
      if (v < totalPages) opts.add(v);
    }
    opts.add(1);
    return opts.where((v) => v >= 1 && v <= totalPages).toList()
      ..sort((a, b) => b.compareTo(a)); // highest to lowest
  }

  return showDialog<int>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        void setPages(int value) {
          if (!ctx.mounted) return;
          currentPages = value.clamp(1, totalPages);
          controller.text = '$currentPages';
        }

        final options = buildOptions();
        final pageLabel = isPdf ? 'pages' : 'est. pages';

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
                // ── Header ─────────────────────────────────────────────────
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
                      child: const Icon(Icons.filter_list_rounded,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Detail Filtering',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.onSurface,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            'Total: $totalPages $pageLabel detected',
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
                const SizedBox(height: 12),

                // ── Info banner ────────────────────────────────────────────
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isScanned
                        ? const Color(0xFFFFF3CD)
                        : AppColors.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: isScanned
                        ? Border.all(
                            color: const Color(0xFFFFD95C).withOpacity(0.6))
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isScanned
                            ? Icons.photo_camera_outlined
                            : Icons.info_outline_rounded,
                        size: 14,
                        color: isScanned
                            ? const Color(0xFF856404)
                            : AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isScanned
                              ? 'This looks like a scanned PDF. '
                                  'The AI reads images directly — max 5 pages per request.'
                              : 'Select how many pages the AI should read. '
                                  'Fewer pages = faster, more focused cards.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: isScanned
                                ? const Color(0xFF856404)
                                : AppColors.primary,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Stepper ────────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Decrement
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () {
                            if (currentPages > 1 && ctx.mounted) {
                              setState(() => setPages(currentPages - 1));
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: currentPages > 1
                                  ? AppColors.primaryContainer
                                  : AppColors.outlineVariant.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.remove_rounded,
                              size: 22,
                              color: currentPages > 1
                                  ? AppColors.primary
                                  : AppColors.outline,
                            ),
                          ),
                        ),
                      ),

                      // Page number input
                      SizedBox(
                        width: 100,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.text,
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
                              if (!ctx.mounted) return;
                              final parsed = int.tryParse(val);
                              if (parsed != null) {
                                setState(() => setPages(parsed));
                              }
                            },
                            onSubmitted: (val) {
                              if (!ctx.mounted) return;
                              final parsed = int.tryParse(val) ?? 1;
                              setState(() => setPages(parsed));
                            },
                          ),
                        ),
                      ),

                      // Increment
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () {
                            if (currentPages < totalPages && ctx.mounted) {
                              setState(() => setPages(currentPages + 1));
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: currentPages < totalPages
                                  ? AppColors.primaryContainer
                                  : AppColors.outlineVariant.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              size: 22,
                              color: currentPages < totalPages
                                  ? AppColors.primary
                                  : AppColors.outline,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Quick-select chips (highest → lowest) ──────────────────
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: options
                        .map((v) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  onTap: () {
                                    if (ctx.mounted)
                                      setState(() => setPages(v));
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: currentPages == v
                                          ? AppColors.primary
                                          : AppColors.surfaceContainerLow,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: currentPages == v
                                            ? AppColors.primary
                                            : AppColors.outlineVariant,
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      v == totalPages ? 'All ($v)' : '$v pages',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: currentPages == v
                                            ? AppColors.onPrimary
                                            : AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Action buttons ─────────────────────────────────────────
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
                        onPressed: () => Navigator.pop(ctx, currentPages),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          'Read $currentPages ${currentPages == 1 ? 'Page' : 'Pages'}',
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
      showCreateDeckErrorSnackBar(
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
      showCreateDeckErrorSnackBar(context, 'The selected file is empty.');
    return;
  }

  // ── PDF size gate ──────────────────────────────────────────────────────────
  // Cloud Run's default request body limit is 32 MB. base64 adds ~33% overhead,
  // so a 20 MB raw PDF encodes to ~27 MB — safely under the limit.
  // For PDFs the full binary is always sent (the server decides text vs vision),
  // so there is no client-side way to reduce the payload — reject here instead.
  if (isPdf && fileBytes.length > 20 * 1024 * 1024) {
    if (context.mounted) {
      final mb = (fileBytes.length / (1024 * 1024)).toStringAsFixed(1);
      showCreateDeckErrorSnackBar(
        context,
        'PDF is too large ($mb MB — max 20 MB). '
        'Export only the pages you need as a smaller PDF, or paste the text instead.',
      );
    }
    return;
  }

  // ── Step 2: Detail Filtering — page range dialog ───────────────────────────
  int pageLimit = 0; // 0 = send full file; >0 = capped page count
  if (isPdf) {
    final detectedPages = _estimatePdfPageCount(fileBytes);
    if (detectedPages > 1 && context.mounted) {
      // Scanned/photographed PDFs are limited to 5 pages because the
      // vision model only accepts up to 5 images per request.
      // Text-based PDFs have no such cap — the server reads them directly.
      final likelyScanned = _isLikelyScannedPdf(fileBytes, detectedPages);
      final maxSelectablePages =
          likelyScanned ? detectedPages.clamp(1, 5) : detectedPages;

      final selectedPages = await _showPageRangeDialog(
        context,
        totalPages: maxSelectablePages,
        isPdf: true,
        isScanned: likelyScanned,
      );
      if (selectedPages == null) return; // user cancelled
      if (selectedPages < detectedPages) pageLimit = selectedPages;
    }
  } else {
    // TXT: estimate pages from char count, truncate client-side
    final rawText = utf8.decode(fileBytes, allowMalformed: true);
    final estimatedPages = _estimateTxtPageCount(rawText.trim().length);
    if (estimatedPages > 1 && context.mounted) {
      final selectedPages = await _showPageRangeDialog(
        context,
        totalPages: estimatedPages,
        isPdf: false,
      );
      if (selectedPages == null) return; // user cancelled
      if (selectedPages < estimatedPages) pageLimit = selectedPages;
    }
  }

  // ── Step 3: Question type dialog ──────────────────────────────────────────
  if (!context.mounted) return;
  final questionType = await _showQuestionTypeDialog(context);
  if (questionType == null) return; // user cancelled

  // ── Step 4: Category dialog ────────────────────────────────────────────────
  if (!context.mounted) return;
  final category = await _showCategoryDialog(context);
  if (category == null) return; // user cancelled

  // ── Step 5: Estimate max & show count dialog ───────────────────────────────
  // AI generation limits: Min 10, Max 30
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

  // ── Step 6: Show loading overlay ──────────────────────────────────────────
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
    // ── Yield one frame so the loading dialog can paint before the
    // synchronous base64Encode blocks the main isolate. ───────────────────────
    await Future<void>.delayed(const Duration(milliseconds: 100));

    // ── Step 7: Build request body ───────────────────────────────────────────
    Map<String, dynamic> requestBody;
    if (isPdf) {
      final base64Data = base64Encode(fileBytes);
      requestBody = {
        'fileBase64': base64Data,
        'fileType': 'pdf',
        'questionType': questionType.apiValue,
        'questionCount': questionCount,
        if (pageLimit > 0) 'pageLimit': pageLimit, // Detail Filtering
      };
    } else {
      final text = utf8.decode(fileBytes, allowMalformed: true);
      if (text.trim().isEmpty) throw Exception('File is empty');
      // Apply page limit: truncate text client-side (≈ 3 000 chars per page)
      final charLimit = pageLimit > 0 ? pageLimit * 3000 : null;
      final filteredText = (charLimit != null && text.length > charLimit)
          ? text.substring(0, charLimit)
          : text;
      requestBody = {
        'text': filteredText,
        'fileType': 'txt',
        'questionType': questionType.apiValue,
        'questionCount': questionCount,
      };
    }

    // ── Step 8: Call Cloud Run endpoint ─────────────────────────────────────
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

    // ── Step 9: Parse response ───────────────────────────────────────────────
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

    // ── Step 10: Write to Firestore ───────────────────────────────────────────
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

    // ── Step 9b: Soft under-delivery warning ─────────────────────────────────
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

    // ── Step 11: Success ──────────────────────────────────────────────────────
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
      showCreateDeckErrorSnackBar(
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
      showCreateDeckErrorSnackBar(
          context,
          e.toString().contains('Exception:')
              ? e.toString().replaceFirst('Exception: ', '')
              : 'Something went wrong. Please try again.');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI IMPORT CARD  (public — used by HomeScreen and DeckHubScreen)
// ─────────────────────────────────────────────────────────────────────────────

class AIImportCard extends StatelessWidget {
  const AIImportCard({super.key});

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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CREATE DECK CARD  (public — dashed manual-create card)
// ─────────────────────────────────────────────────────────────────────────────

class CreateDeckCard extends StatefulWidget {
  const CreateDeckCard({super.key});

  @override
  State<CreateDeckCard> createState() => _CreateDeckCardState();
}

class _CreateDeckCardState extends State<CreateDeckCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => Navigator.of(context).pushNamed('/create-deck'),
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
