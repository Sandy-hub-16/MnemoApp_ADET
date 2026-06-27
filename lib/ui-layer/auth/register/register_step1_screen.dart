import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../landing_page/app_theme.dart';
import '../../../main.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/auth_buttons.dart';
import '../widgets/auth_decorations.dart';
import '../widgets/step_progress.dart';
import '../../widgets/app_spinner.dart';

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
  final _nameFocus = FocusNode();
  final _usernameFocus = FocusNode();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _nameFocus.dispose();
    _usernameFocus.dispose();
    super.dispose();
  }

  Future<void> _handleNext() async {
    // Validate form fields
    final name = _nameCtrl.text.trim();
    final username = _usernameCtrl.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Full name is required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Username is required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (username.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Username must be at least 6 characters'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This username is already taken. Please choose another one.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
        return;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error checking username: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    Navigator.of(context).pushNamed(
      AppRoutes.signUp2,
      arguments: {
        'fullName': name,
        'username': username,
      },
    );
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
          focusNode: _nameFocus,
          hint: 'Alex Kindred',
          label: 'Full Name',
          prefixIcon: Icons.person_outline_rounded,
          shape: AuthFieldShape.rounded,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _usernameFocus.requestFocus(),
        ),
        const SizedBox(height: 20),
        AuthTextField(
          controller: _usernameCtrl,
          focusNode: _usernameFocus,
          hint: 'alex_studies',
          label: 'Unique Username',
          prefixIcon: Icons.alternate_email_rounded,
          shape: AuthFieldShape.rounded,
          helperText: "This is how you'll appear in study groups.",
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _handleNext(),
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
        _isLoading
            ? const Center(child: AppSpinner())
            : AuthPrimaryButton(
                label: 'Next Step',
                onTap: _handleNext,
              ),
        const SizedBox(height: 32),
      ],
    );
  }
}