import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../ui-layer/widgets/app_spinner.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EXPORT SERVICE
//
// Generates and saves a study-deck export file (PDF or plain text) directly
// to the device's Downloads / Documents folder — no share sheet involved.
//
// DATA PATH
// ─────────
//   users/{uid}/decks/{deckId}/cards   (ordered by `order` ascending)
//
// ENTRY POINT
// ───────────
//   exportDeck()  → shows loading dialog → fetches cards → builds bytes →
//                   dismisses loader → saves to device → shows success snackbar
//
// SUPPORTED FORMATS
// ─────────────────
//   ExportFormat.pdf       → _buildPdf()   using the `pdf` + `printing` package
//   ExportFormat.plainText → _buildTxt()   pure UTF-8 string builder
//
// ERROR HANDLING
// ──────────────
//   Every failure point dismisses the loader and shows a local error snackbar.
// ─────────────────────────────────────────────────────────────────────────────

// ── Format enum ──────────────────────────────────────────────────────────────

enum ExportFormat { pdf, plainText }

// ── Service ──────────────────────────────────────────────────────────────────

abstract final class ExportService {
  // ── Public entry point ───────────────────────────────────────────────────

  /// Fetches all cards for [deckId], generates the export file in [format],
  /// and saves it directly to the device's Downloads/Documents folder.
  ///
  /// Shows a non-dismissible loading dialog while working and surfaces error
  /// snackbars on any failure.
  static Future<void> exportDeck({
    required BuildContext context,
    required String deckId,
    required String deckTitle,
    required ExportFormat format,
  }) async {
    // ── Show loading dialog ─────────────────────────────────────────────────
    bool loadingOpen = false;

    if (context.mounted) {
      loadingOpen = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const PopScope(
          canPop: false,
          child: Center(
            child: AppSpinner(),
          ),
        ),
      );
    }

    void safePopLoader() {
      if (loadingOpen && context.mounted) {
        loadingOpen = false;
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    // ── Fetch cards ─────────────────────────────────────────────────────────
    List<Map<String, dynamic>> cards;
    try {
      cards = await _fetchCards(deckId);
    } catch (_) {
      safePopLoader();
      if (context.mounted) {
        _showError(context, 'Failed to load deck cards. Please try again.');
      }
      return;
    }

    // ── Guard: empty deck ───────────────────────────────────────────────────
    if (cards.isEmpty) {
      safePopLoader();
      if (context.mounted) {
        _showError(context, 'This deck has no cards to export.');
      }
      return;
    }

    // ── Generate file bytes ─────────────────────────────────────────────────
    Uint8List bytes;
    try {
      if (format == ExportFormat.pdf) {
        bytes = await _buildPdf(deckTitle, cards);
      } else {
        bytes = _buildTxt(deckTitle, cards);
      }
    } catch (_) {
      safePopLoader();
      if (context.mounted) {
        final message = format == ExportFormat.pdf
            ? 'PDF generation failed. Please try again.'
            : 'Text export failed. Please try again.';
        _showError(context, message);
      }
      return;
    }

    // ── Save to device ──────────────────────────────────────────────────────
    final fileName = _sanitiseFileName(deckTitle, format);
    // file_saver wants the name WITHOUT the extension — it adds it from MimeType
    final fileNameStem = fileName.replaceAll(
      format == ExportFormat.pdf ? '.pdf' : '.txt',
      '',
    );

    try {
      await FileSaver.instance.saveFile(
        name: fileNameStem,
        bytes: bytes,
        mimeType: format == ExportFormat.pdf ? MimeType.pdf : MimeType.text,
      );

      safePopLoader();

      if (context.mounted) {
        _showSuccess(
          context,
          format == ExportFormat.pdf
              ? 'PDF saved to your Downloads folder.'
              : 'Text file saved to your Downloads folder.',
        );
      }
    } catch (_) {
      safePopLoader();
      if (context.mounted) {
        _showError(context, 'Could not save the file. Please try again.');
      }
    }
  }

  // ── Private helpers ──────────────────────────────────────────────────────

  /// Fetches all cards for [deckId] from Firestore.
  ///
  /// Tries to order by the `order` field first (set by DeckService).
  /// Falls back to unordered fetch for AI-generated decks that lack the field.
  static Future<List<Map<String, dynamic>>> _fetchCards(String deckId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('User is not signed in.');

    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('decks')
        .doc(deckId)
        .collection('cards');

    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await ref.orderBy('order').get();
    } catch (_) {
      snap = await ref.get();
    }

    if (snap.docs.isEmpty) {
      snap = await ref.get();
    }

    return snap.docs.map((d) => d.data()).toList();
  }

  /// Generates a PDF document from [cards] with [deckTitle] as the heading.
  /// Uses Noto Sans for full Unicode support (no more Helvetica warnings).
  static Future<Uint8List> _buildPdf(
    String deckTitle,
    List<Map<String, dynamic>> cards,
  ) async {
    // ── Load Unicode-capable fonts ─────────────────────────────────────────
    final regular = await PdfGoogleFonts.notoSansRegular();
    final bold    = await PdfGoogleFonts.notoSansBold();

    const accentColor = PdfColor.fromInt(0xFF6750A4);
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        // Theme ensures every widget inherits Unicode fonts by default
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        build: (pw.Context ctx) {
          final widgets = <pw.Widget>[];

          // ── Deck title heading ──────────────────────────────────────────
          widgets.add(
            pw.Text(
              deckTitle,
              style: pw.TextStyle(font: bold, fontSize: 24),
            ),
          );
          widgets.add(pw.SizedBox(height: 8));
          widgets.add(pw.Divider(thickness: 1));
          widgets.add(pw.SizedBox(height: 16));

          // ── Cards ───────────────────────────────────────────────────────
          for (int i = 0; i < cards.length; i++) {
            final card     = cards[i];
            final n        = i + 1;
            final question = card['question'] as String? ?? '';
            final type     = card['type']     as String? ?? '';

            widgets.add(
              pw.Text(
                '$n. $question',
                style: pw.TextStyle(font: bold, fontSize: 13),
              ),
            );
            widgets.add(pw.SizedBox(height: 6));

            if (type == 'multiple_choice') {
              final choices = (card['choices'] as List?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  [];
              final correctIndex = (card['correctIndex'] as int?) ?? 0;
              const labels = ['A', 'B', 'C', 'D'];

              for (int j = 0; j < choices.length && j < 4; j++) {
                final label      = labels[j];
                final choiceText = choices[j];
                final isCorrect  = j == correctIndex;

                final choiceWidget = pw.Text(
                  '$label) $choiceText',
                  style: pw.TextStyle(
                    font:     isCorrect ? bold : regular,
                    fontSize: 12,
                    color:    isCorrect ? accentColor : PdfColors.black,
                  ),
                );

                if (isCorrect) {
                  widgets.add(
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: accentColor, width: 1.5),
                        borderRadius: pw.BorderRadius.circular(20),
                      ),
                      child: choiceWidget,
                    ),
                  );
                } else {
                  widgets.add(
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      child: choiceWidget,
                    ),
                  );
                }
              }
            } else {
              // identification
              final answer = card['answer'] as String? ?? '';
              widgets.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8),
                  child: pw.Text(
                    'Answer: $answer',
                    style: pw.TextStyle(font: regular, fontSize: 12),
                  ),
                ),
              );
            }

            widgets.add(pw.SizedBox(height: 16));
          }

          return widgets;
        },
      ),
    );

    return doc.save();
  }

  /// Generates a UTF-8 plain-text representation of [cards] with [deckTitle]
  /// as the first line. Returns the encoded bytes.
  static Uint8List _buildTxt(
    String deckTitle,
    List<Map<String, dynamic>> cards,
  ) {
    final buffer = StringBuffer();

    buffer.writeln(deckTitle);
    buffer.writeln();

    const labels = ['A', 'B', 'C', 'D'];

    for (int i = 0; i < cards.length; i++) {
      final card     = cards[i];
      final n        = i + 1;
      final question = card['question'] as String? ?? '';
      final type     = card['type']     as String? ?? '';

      buffer.writeln('$n. $question');

      if (type == 'multiple_choice') {
        final choices = (card['choices'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        final correctIndex = (card['correctIndex'] as int?) ?? 0;

        for (int j = 0; j < choices.length && j < 4; j++) {
          final label = labels[j];
          final line  = '$label) ${choices[j]}';
          // Wrap the correct answer in asterisks so it stands out
          buffer.writeln(j == correctIndex ? '*$line*' : line);
        }
      } else {
        final answer = card['answer'] as String? ?? '';
        buffer.writeln('Answer: $answer');
      }

      buffer.writeln();
    }

    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  /// Sanitises [title] into a safe file name and appends the correct extension.
  static String _sanitiseFileName(String title, ExportFormat format) {
    final stem = title
        .trim()
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '');
    final ext = format == ExportFormat.pdf ? '.pdf' : '.txt';
    return '$stem\_export$ext';
  }

  // ── Snackbar helpers ─────────────────────────────────────────────────────

  static void _showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  static void _showError(BuildContext context, String message) {
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
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFB3261E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}