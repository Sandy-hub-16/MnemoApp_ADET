import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../landing_page/app_theme.dart';
import '../widgets_design.dart';

// ─────────────────────────────────────────────────────────────────────────────
// VERIFY EMAIL SCREEN
// Shown after registration or when an unverified user tries to log in.
// ─────────────────────────────────────────────────────────────────────────────

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _isLoading = false;
  bool _emailSent = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _sendVerificationEmail();
    _startEmailCheckTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _sendVerificationEmail() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.sendEmailVerification();
      setState(() => _emailSent = true);
    } catch (e) {
      // ignore: avoid_print
      print('Error sending verification email: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startEmailCheckTimer() {
    _timer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final user = FirebaseAuth.instance.currentUser;
      await user?.reload();
      if (user != null && user.emailVerified) {
        _timer?.cancel();
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    final email = args?['email'] ?? 'your email';

    return AuthScaffold(
      title: 'Verify Email',
      showBack: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),

          // ── Icon ────────────────────────────────────────────────────────
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_email_unread_rounded,
              color: AppColors.primary,
              size: 48,
            ),
          ),
          const SizedBox(height: 32),

          // ── Title ───────────────────────────────────────────────────────
          Text(
            'Check your inbox',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 12),

          // ── Subtitle ────────────────────────────────────────────────────
          Text(
            'We\'ve sent a verification link to',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              height: 1.6,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 32),

          // ── Info blob ───────────────────────────────────────────────────
          InfoBlob(
            icon: Icons.info_outline_rounded,
            text: 'Click the link in the email to verify your account. This page will automatically redirect you once verified.',
            color: AppColors.secondaryContainer.withOpacity(0.35),
            iconColor: AppColors.secondary,
            textColor: AppColors.onSecondaryContainer,
          ),
          const SizedBox(height: 36),

          // ── Resend button ───────────────────────────────────────────────
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : AuthPrimaryButton(
                  label: _emailSent ? 'Resend Email' : 'Send Verification Email',
                  onTap: _sendVerificationEmail,
                ),
          const SizedBox(height: 20),

          // ── Back to sign in ─────────────────────────────────────────────
          TextButton(
            onPressed: () {
              _timer?.cancel();
              FirebaseAuth.instance.signOut();
              Navigator.pushReplacementNamed(context, '/sign-in');
            },
            child: Text(
              'Back to Sign In',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

