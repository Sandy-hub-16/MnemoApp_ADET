import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../landing_page/app_theme.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_buttons.dart';
import '../widgets/auth_decorations.dart';

// ─────────────────────────────────────────────────────────────────────────────
// VERIFY EMAIL SCREEN
// Shown after registration or when an unverified user tries to log in.
//
// • 8-minute countdown — account is deleted on expiry.
// • 60-second resend cooldown between emails.
// • Polls Firebase every 3 s; auto-redirects to /home on success.
// ─────────────────────────────────────────────────────────────────────────────

const int _kVerifyWindowSeconds = 480; // 8 minutes
const int _kResendCooldownSeconds = 60; // 1 minute

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _isSending = false;
  bool _emailSent = false;

  // Countdown starts locked so the UI never shows an enabled Resend button
  // before the first email has even finished sending.
  int _secondsRemaining = _kVerifyWindowSeconds;
  int _resendCooldown = _kResendCooldownSeconds;

  Timer? _emailCheckTimer;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _sendVerificationEmail();
    _startEmailCheckTimer();
    _startCountdownTimer();
  }

  @override
  void dispose() {
    _emailCheckTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ── Send / resend ───────────────────────────────────────────────────────

  Future<void> _sendVerificationEmail() async {
    if (_isSending) return;
    setState(() {
      _isSending = true;
      _resendCooldown = _kResendCooldownSeconds; // re-lock on every send
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.sendEmailVerification();
      if (mounted) setState(() => _emailSent = true);
    } catch (e) {
      // ignore: avoid_print
      print('Error sending verification email: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ── Poll Firebase for email-verified flag (every 3 s) ──────────────────

  void _startEmailCheckTimer() {
    _emailCheckTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final user = FirebaseAuth.instance.currentUser;
      await user?.reload();
      if (user != null && user.emailVerified) {
        _emailCheckTimer?.cancel();
        _countdownTimer?.cancel();
        if (mounted) Navigator.pushReplacementNamed(context, '/home');
      }
    });
  }

  // ── 1-second tick: main countdown + resend cooldown ────────────────────

  void _startCountdownTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_resendCooldown > 0) _resendCooldown--;
        if (_secondsRemaining > 0) _secondsRemaining--;
      });

      if (_secondsRemaining == 0) {
        timer.cancel();
        _emailCheckTimer?.cancel();
        _onVerificationExpired();
      }
    });
  }

  // ── Expiry handler ──────────────────────────────────────────────────────

  Future<void> _onVerificationExpired() async {
    // Best-effort delete — the account is unverified so we treat it as
    // abandoned. Silently ignore errors (e.g. if the account was already
    // deleted or requires re-auth).
    try {
      await FirebaseAuth.instance.currentUser?.delete();
    } catch (_) {}

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.timer_off_rounded,
                color: Colors.red,
                size: 36,
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              'Verification expired',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 12),

            // Body
            Text(
              'The 8-minute verification window has closed and your '
              'registration has been cancelled. Please sign up again to '
              'create a new account.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                height: 1.6,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),

            // CTA
            AuthPrimaryButton(
              label: 'Sign Up Again',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.pushReplacementNamed(context, '/sign-up/step-1');
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  String get _timeString {
    final m = _secondsRemaining ~/ 60;
    final s = _secondsRemaining % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Shifts green → orange → red as time runs out.
  Color get _timerColor {
    final fraction = _secondsRemaining / _kVerifyWindowSeconds;
    if (fraction > 0.50) return AppColors.primary;
    if (fraction > 0.25) return Colors.orange.shade700;
    return Colors.red.shade600;
  }

  // ── Build ────────────────────────────────────────────────────────────────

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

          // ── Countdown card ──────────────────────────────────────────────
          _CountdownCard(
            timeString: _timeString,
            timerColor: _timerColor,
            progress: _secondsRemaining / _kVerifyWindowSeconds,
          ),
          const SizedBox(height: 32),

          // ── Info blob ───────────────────────────────────────────────────
          InfoBlob(
            icon: Icons.info_outline_rounded,
            text: 'Click the link in the email to verify your account. '
                'This page checks every few seconds and will redirect you '
                'automatically once verified.',
            color: AppColors.secondaryContainer.withOpacity(0.35),
            iconColor: AppColors.secondary,
            textColor: AppColors.onSecondaryContainer,
          ),
          const SizedBox(height: 36),

          // ── Resend / Cooldown / Sending ─────────────────────────────────
          if (_isSending)
            const Center(child: CircularProgressIndicator())
          else if (_resendCooldown > 0)
            _ResendCooldownButton(secondsLeft: _resendCooldown)
          else
            AuthPrimaryButton(
              label: _emailSent ? 'Resend Email' : 'Send Verification Email',
              showIcon: false,
              onTap: _sendVerificationEmail,
            ),
          const SizedBox(height: 20),

          // ── Back to sign in ─────────────────────────────────────────────
          TextButton(
            onPressed: () {
              _emailCheckTimer?.cancel();
              _countdownTimer?.cancel();
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

// ─────────────────────────────────────────────────────────────────────────────
// COUNTDOWN CARD
// AnimatedContainer smoothly cross-fades the background and border whenever
// timerColor shifts (primary → orange → red).
// ─────────────────────────────────────────────────────────────────────────────

class _CountdownCard extends StatelessWidget {
  const _CountdownCard({
    required this.timeString,
    required this.timerColor,
    required this.progress,
  });

  final String timeString;
  final Color timerColor;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      decoration: BoxDecoration(
        color: timerColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: timerColor.withOpacity(0.22),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // Label row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.timer_outlined,
                size: 14,
                color: timerColor.withOpacity(0.60),
              ),
              const SizedBox(width: 6),
              Text(
                'TIME REMAINING',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: timerColor.withOpacity(0.60),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Large MM:SS display
          Text(
            timeString,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 54,
              fontWeight: FontWeight.w800,
              letterSpacing: -2,
              height: 1.0,
              color: timerColor,
            ),
          ),
          const SizedBox(height: 16),

          // Depleting progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: timerColor.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation<Color>(timerColor),
            ),
          ),
          const SizedBox(height: 10),

          // Warning label
          Text(
            'Your registration will be cancelled when the timer reaches 0:00',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              height: 1.5,
              color: timerColor.withOpacity(0.55),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RESEND COOLDOWN BUTTON
// Greyed-out pill that shows seconds left until resend is unlocked.
// ─────────────────────────────────────────────────────────────────────────────

class _ResendCooldownButton extends StatelessWidget {
  const _ResendCooldownButton({required this.secondsLeft});
  final int secondsLeft;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.hourglass_top_rounded,
            size: 18,
            color: AppColors.outline,
          ),
          const SizedBox(width: 10),
          Text(
            'Resend available in ${secondsLeft}s',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.outline,
            ),
          ),
        ],
      ),
    );
  }
}
