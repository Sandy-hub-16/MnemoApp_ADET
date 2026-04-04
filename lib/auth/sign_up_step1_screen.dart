import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../landing_page/app_theme.dart';
import '../main.dart';
import 'auth_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SIGN UP — STEP 1: IDENTITY
// Full Name + Unique Username.
// ─────────────────────────────────────────────────────────────────────────────

class SignUpStep1Screen extends StatelessWidget {
  const SignUpStep1Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Create Account',
      showBack: true,
      child: const _Step1Body(),
    );
  }
}

class _Step1Body extends StatefulWidget {
  const _Step1Body();

  @override
  State<_Step1Body> createState() => _Step1BodyState();
}

class _Step1BodyState extends State<_Step1Body> {
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),

        // ── Progress bar ──────────────────────────────────────────────────
        const StepProgressBar(current: 1, total: 3),
        const SizedBox(height: 36),

        // ── Section header ────────────────────────────────────────────────
        Text(
          'Your Identity',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Let's start with the basics. How should MnemoApp address you?",
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            height: 1.6,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 32),

        // ── Form fields ───────────────────────────────────────────────────
        AuthTextField(
          controller: _nameCtrl,
          hint: 'Alex Kindred',
          label: 'Full Name',
          prefixIcon: Icons.person_outline_rounded,
          shape: AuthFieldShape.rounded,
        ),
        const SizedBox(height: 20),
        AuthTextField(
          controller: _usernameCtrl,
          hint: 'alex_studies',
          label: 'Unique Username',
          prefixText: '@',
          shape: AuthFieldShape.rounded,
          helperText: "This is how you'll appear in study groups.",
        ),
        const SizedBox(height: 36),

        // ── Info blob ─────────────────────────────────────────────────────
        InfoBlob(
          icon: Icons.info_outline_rounded,
          text: 'Your name and username will be visible to your study buddies '
              'and in collaborative flashcard decks.',
          color: AppColors.secondaryContainer.withOpacity(0.35),
          iconColor: AppColors.secondary,
          textColor: AppColors.onSecondaryContainer,
        ),
        const SizedBox(height: 36),

        // ── Next CTA ──────────────────────────────────────────────────────
        AuthPrimaryButton(
          label: 'Next Step',
          onTap: () => Navigator.of(context).pushNamed(AppRoutes.signUp2),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}
