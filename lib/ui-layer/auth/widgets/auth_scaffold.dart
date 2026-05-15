import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../landing_page/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AUTH SCAFFOLD
// Reused by SignIn, Step1, Step2, Step3.
// Provides: blobs, frosted header bar, scrollable body slot.
// ─────────────────────────────────────────────────────────────────────────────

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.child,
    this.title = 'Create Account',
    this.showBack = true,
    this.trailing,
  });

  final Widget child;
  final String title;
  final bool showBack;

  /// Optional widget in the top-right (e.g. step counter).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Background blobs ─────────────────────────────────────────────
          const Positioned.fill(child: _AuthBlobs()),

          // ── Scrollable page content ──────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _AuthTopBar(
                  title: title,
                  showBack: showBack,
                  trailing: trailing,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(
                      left: 24,
                      right: 24,
                      top: 8,
                      bottom: 40,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: child,
                      ),
                    ),
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
// TOP BAR — frosted glass, back arrow, title, optional trailing slot.
// ─────────────────────────────────────────────────────────────────────────────

class _AuthTopBar extends StatelessWidget {
  const _AuthTopBar({
    required this.title,
    required this.showBack,
    this.trailing,
  });

  final String title;
  final bool showBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFECF5F1).withOpacity(0.78),
            border: Border(
              bottom: BorderSide(
                color: AppColors.outlineVariant.withOpacity(0.14),
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              // Back button
              if (showBack) _BackButton() else const SizedBox(width: 48),

              // Title — centred
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    letterSpacing: -0.2,
                  ),
                ),
              ),

              // Trailing
              SizedBox(
                width: 72,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: trailing ?? const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatefulWidget {
  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        Navigator.of(context).pop();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.outlineVariant.withOpacity(0.5),
              ),
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              size: 18,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AUTH BACKGROUND BLOBS — three soft blobs matching the HTML design.
// ─────────────────────────────────────────────────────────────────────────────

class _AuthBlobs extends StatelessWidget {
  const _AuthBlobs();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Align(
            alignment: const Alignment(-1.5, -1.4),
            child: _Blob(380, AppColors.primaryContainer.withOpacity(0.35)),
          ),
          Align(
            alignment: const Alignment(1.6, 1.5),
            child: _Blob(460, AppColors.secondaryContainer.withOpacity(0.35)),
          ),
          Align(
            alignment: const Alignment(1.1, -0.1),
            child: _Blob(280, AppColors.tertiaryContainer.withOpacity(0.28)),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob(this.size, this.color);
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 72, sigmaY: 72),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
