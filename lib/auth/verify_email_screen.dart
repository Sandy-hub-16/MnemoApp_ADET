import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../landing_page/app_theme.dart';
import 'auth_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// VERIFY EMAIL SCREEN
// Shown after Step 3 "Complete Sign Up" is tapped.
// Pops back to Step 3 with result=true to trigger its loading/register state.
//
// "Verify & Create Account" — validates all 6 boxes are filled, then always
//   returns an "Incorrect code" error (no real OTP backend yet).
//
// Dev bypass — skips OTP entirely and pops(true) so Step 3 runs registerUser().
// ─────────────────────────────────────────────────────────────────────────────

class VerifyEmailScreen extends StatelessWidget {
  const VerifyEmailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final rawArgs = ModalRoute.of(context)?.settings.arguments;
    final Map<String, dynamic> args =
        rawArgs != null ? Map<String, dynamic>.from(rawArgs as Map) : {};

    final String email =
        args['email'] != null ? args['email'] as String : 'your email';

    return AuthScaffold(
      title: 'Verify Email',
      showBack: true,
      child: _VerifyEmailBody(email: email),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BODY
// ─────────────────────────────────────────────────────────────────────────────

class _VerifyEmailBody extends StatefulWidget {
  const _VerifyEmailBody({required this.email});
  final String email;

  @override
  State<_VerifyEmailBody> createState() => _VerifyEmailBodyState();
}

class _VerifyEmailBodyState extends State<_VerifyEmailBody> {
  // Six controllers + focus nodes for the OTP grid
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  // Countdown timer display — UI only, no real timer logic
  final String _countdown = '03:00';

  

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  /// When a digit is entered in box [index], auto-jump to the next box.
  void _onChanged(String value, int index) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    // Allow backspace to go back
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    setState(() {});
  }

  Future<void> checkEmailVerified() async {
    await FirebaseAuth.instance.currentUser?.reload();
    final user = FirebaseAuth.instance.currentUser;

    if (user != null && user.emailVerified) {
      Navigator.pop(context, true);
    } else {
      _showError("Email not verified yet.");
    }
  }

  /// Shared red snackbar used for all errors on this screen.
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),

        // ── Header ──────────────────────────────────────────────────────────
        Text(
          'Verify your email',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        RichText(
          text: TextSpan(
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              height: 1.6,
              color: AppColors.onSurfaceVariant,
            ),
            children: [
              const TextSpan(text: "We've sent a verification link to "),
              TextSpan(
                text: widget.email,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const TextSpan(
                  text: '. Enter it below to complete your sign-up.'),
            ],
          ),
        ),
        const SizedBox(height: 36),

        // ── OTP Input Grid ───────────────────────────────────────────────────
        AuthCard(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              // 6-box grid
              Row(
                children: List.generate(6, (i) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
                      child: _OtpBox(
                        controller: _controllers[i],
                        focusNode: _focusNodes[i],
                        onChanged: (v) => _onChanged(v, i),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),

              // ── Primary CTA ────────────────────────────────────────────────
              // Step 1: validates all 6 boxes are filled.
              // Step 2: shows "Incorrect code" — no real OTP backend yet.
              //         TODO (backend): replace with real OTP verification call.
              //         Only pop(true) once the server confirms the code.
              AuthPrimaryButton(
                label: 'Verify & Create Account',
                trailingIcon: Icons.rocket_launch_rounded,
                onTap: () async {
                  await checkEmailVerified();
                },
              ),
              const SizedBox(height: 24),

              // ── Resend + Countdown row ──────────────────────────────────────
              Column(
                children: [
                  GestureDetector(
                    onTap: () async {
                        await FirebaseAuth.instance.currentUser?.sendEmailVerification();
                        _showError("Verification email sent again.");
                    },
                    child: Text(
                      "Didn't receive the code? Resend",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 14,
                          color: AppColors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$_countdown remaining',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // ── Buddy Tip Card ───────────────────────────────────────────────────
        _BuddyTipCard(),
        const SizedBox(height: 36),

        // ═════════════════════════════════════════════════════════════════════
        // ██  DEV MODE — REMOVE THIS ENTIRE BLOCK BEFORE PRODUCTION DEPLOY  ██
        // Bypasses OTP entirely. Pops back to Step 3 with result=true, which
        // triggers Step 3's loading overlay and calls registerUser() for real.
        // ═════════════════════════════════════════════════════════════════════
        _DevBypassButton(onBypass: () => Navigator.of(context).pop(true)),
        // ═════════════════════════════════════════════════════════════════════

        const SizedBox(height: 36),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OTP BOX — single square digit input
// ─────────────────────────────────────────────────────────────────────────────

class _OtpBox extends StatefulWidget {
  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  State<_OtpBox> createState() => _OtpBoxState();
}

class _OtpBoxState extends State<_OtpBox> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(() {
      setState(() => _focused = widget.focusNode.hasFocus);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 56,
      decoration: BoxDecoration(
        color: _focused
            ? AppColors.surfaceContainerLowest
            : AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _focused
              ? AppColors.primary
              : AppColors.outlineVariant.withOpacity(0.35),
          width: _focused ? 2.0 : 1.2,
        ),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ]
            : [],
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        maxLength: 1,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: GoogleFonts.plusJakartaSans(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: AppColors.onSurface,
        ),
        decoration: InputDecoration(
          counterText: '',
          hintText: '·',
          hintStyle: GoogleFonts.plusJakartaSans(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.outlineVariant,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: widget.onChanged,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BUDDY TIP CARD — tertiary-tinted callout at the bottom
// ─────────────────────────────────────────────────────────────────────────────

class _BuddyTipCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.tertiaryContainer.withOpacity(0.28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.tertiaryContainer.withOpacity(0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon bubble
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.tertiaryContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lightbulb_rounded,
              color: AppColors.tertiary,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),

          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Buddy Tip',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onTertiaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Check your spam or junk folder if you don't see the email within a few minutes!",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    height: 1.55,
                    color: AppColors.onTertiaryContainer.withOpacity(0.8),
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

// ═════════════════════════════════════════════════════════════════════════════
// DEV BYPASS BUTTON
// Skips OTP verification entirely. Consolidated here so it's trivial to remove:
//   1. Delete this entire widget class below.
//   2. Delete the _DevBypassButton(...) call in _VerifyEmailBodyState.build().
// DO NOT ship this to production.
// ═════════════════════════════════════════════════════════════════════════════

class _DevBypassButton extends StatelessWidget {
  const _DevBypassButton({required this.onBypass});
  final VoidCallback onBypass;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Separator with DEV MODE label
        Row(
          children: [
            Expanded(
              child: Container(
                height: 1,
                color: AppColors.outlineVariant.withOpacity(0.25),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.orange.withOpacity(0.35)),
                ),
                child: Text(
                  '🚧  DEV MODE',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: Colors.orange.shade700,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Container(
                height: 1,
                color: AppColors.outlineVariant.withOpacity(0.25),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Bypass button
        GestureDetector(
          onTap: onBypass,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.08),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.orange.withOpacity(0.35)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.developer_mode_rounded,
                  size: 18,
                  color: Colors.orange.shade700,
                ),
                const SizedBox(width: 10),
                Text(
                  'Bypass Email Verification',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.orange.shade700,
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
// ═════════════════════════════════════════════════════════════════════════════
// END DEV MODE BLOCK
// ═════════════════════════════════════════════════════════════════════════════
