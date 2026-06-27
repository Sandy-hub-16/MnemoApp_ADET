// ─────────────────────────────────────────────────────────────────────────────
// AMNESIA CONFIRMATION DIALOG
//
// Drop-in replacement for the inline _AmnesiaConfirmationDialog that used
// to live inside settings_screen.dart. The dialog logic is now fully
// self-contained here and all Firestore work is delegated to AmnesiaService,
// mirroring the pattern used by DeleteAccountConfirmationDialog /
// AccountDeletionService.
//
// Usage (from settings_screen.dart):
//   showDialog(
//     context: context,
//     barrierDismissible: false,
//     builder: (_) => const AmnesiaConfirmationDialog(),
//   );
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../landing_page/app_theme.dart';
import '../../../business-layer/services/amnesia_service.dart';
import '../../widgets/app_spinner.dart';

class AmnesiaConfirmationDialog extends StatefulWidget {
  const AmnesiaConfirmationDialog({super.key});

  @override
  State<AmnesiaConfirmationDialog> createState() =>
      _AmnesiaConfirmationDialogState();
}

class _AmnesiaConfirmationDialogState extends State<AmnesiaConfirmationDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _isProcessing = false;
  String? _errorMessage;

  final _service = AmnesiaService();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isConfirmationValid => _controller.text == 'I am absolutely sure';

  Future<void> _handleReset() async {
    if (!_isConfirmationValid) {
      setState(() => _errorMessage = 'Please type the exact phrase');
      return;
    }

    // Flip to loading state IN PLACE — never pop this dialog until the
    // operation is fully done. Popping early detaches the BuildContext so
    // any subsequent Navigator/ScaffoldMessenger calls become no-ops.
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    // Tracks whether we have already dismissed the dialog via nav.pop().
    // If true, the catch blocks must not call setState — the widget is
    // disposed and its context is detached.
    bool dialogPopped = false;

    try {
      await _service.resetAllProgress();

      if (!mounted) return;

      // Capture navigator + messenger BEFORE popping
      final nav = Navigator.of(context, rootNavigator: true);
      final messenger = ScaffoldMessenger.of(context);

      dialogPopped = true;

      // 1. Dismiss the amnesia dialog
      nav.pop();

      // 2. Trigger the SnackBar immediately
      messenger.showSnackBar(
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
                child: Text(
                  'All progress data has been reset',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
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

      // 3. Navigate IMMEDIATELY. The SnackBar will persist across the route change.
      // Note: Make sure to use '/' so your main.dart switch expression catches
      // it and routes directly to MainShell().
      nav.pushNamedAndRemoveUntil(
        '/',
        (route) => false,
      );
    } on AmnesiaException catch (e) {
      if (dialogPopped || !mounted) return;
      setState(() {
        _isProcessing = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (dialogPopped || !mounted) return;
      setState(() {
        _isProcessing = false;
        _errorMessage =
            'Something went wrong. Please check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: AppColors.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: _isProcessing ? _buildLoadingBody() : _buildConfirmBody(),
        ),
      ),
    );
  }

  // ── Loading state ──────────────────────────────────────────────────────────
  // Fixed height keeps the dialog from collapsing when switching from the
  // taller confirmation form to the spinner.
  Widget _buildLoadingBody() {
    return SizedBox(
      height: 160,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const AppSpinner(),
          const SizedBox(height: 24),
          Text(
            'Resetting all progress...',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please wait, do not close the app',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ── Confirmation form ──────────────────────────────────────────────────────
  Widget _buildConfirmBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.errorContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(14),
              ),
              child:
                  Icon(Icons.warning_rounded, color: AppColors.error, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Amnesia',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onSurface,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    'This action cannot be undone',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Warning box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.errorContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.error.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will permanently delete:',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              ..._buildWarningItem('All quiz attempt history'),
              ..._buildWarningItem('All mastery percentages'),
              ..._buildWarningItem('Study streak data'),
              ..._buildWarningItem('Weak spots and forgotten cards'),
              const SizedBox(height: 8),
              Text(
                'Your decks and cards will remain intact.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: AppColors.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Confirmation input
        Text(
          'Type "I am absolutely sure" to confirm:',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _controller,
          onChanged: (_) => setState(() => _errorMessage = null),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: AppColors.onSurface,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: 'I am absolutely sure',
            hintStyle: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: AppColors.outline.withOpacity(0.5),
            ),
            filled: true,
            fillColor: AppColors.surfaceContainerLow,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: _errorMessage != null
                    ? AppColors.error
                    : AppColors.outlineVariant,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: _errorMessage != null
                    ? AppColors.error
                    : AppColors.outlineVariant,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color:
                    _errorMessage != null ? AppColors.error : AppColors.primary,
                width: 2,
              ),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.error_outline_rounded,
                  color: AppColors.error, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _errorMessage!,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),

        // Action buttons
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
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
                onPressed: _handleReset,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  'Reset All Progress',
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
    );
  }

  List<Widget> _buildWarningItem(String text) {
    return [
      Row(
        children: [
          Icon(Icons.close_rounded, color: AppColors.error, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppColors.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
    ];
  }
}
