import 'dart:async';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../landing_page/app_theme.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_buttons.dart';
import '../widgets/auth_decorations.dart';

// ─────────────────────────────────────────────────────────────────────────────
// VERIFY EMAIL SCREEN
//
// States  loading → countdown → verified | declined
//
// • Timer starts from Firestore createdAt so it survives app restarts.
// • Polls Firebase every 3 s; stops + shows success screen on emailVerified.
// • At 0:00 → deletes Firestore doc + Auth account → shows declined screen.
// • Resend button locked for 60 s after each send (1-min cooldown).
// • Warning blob appears at ≤ 2 min; turns red at ≤ 1 min.
// ─────────────────────────────────────────────────────────────────────────────

const int _kWindowSecs = 480; // 8 minutes total
const int _kResendSecs = 60; // 1 minute between resends

enum _VerifyState { loading, countdown, verified, declined }

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen>
    with TickerProviderStateMixin {
  // ── State machine ──────────────────────────────────────────────────────────
  _VerifyState _uiState = _VerifyState.loading;

  // ── Timers ─────────────────────────────────────────────────────────────────
  int _secondsLeft = _kWindowSecs;
  int _resendLeft = _kResendSecs; // cooldown; starts at 60 s because the
  // registration flow just sent an email
  bool _isSending = false;
  bool _emailSent = false; // becomes true after manual resend
  String? _userEmail;

  Timer? _tickTimer;
  Timer? _pollTimer;

  // ── Animations ─────────────────────────────────────────────────────────────
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseScale;

  late final AnimationController _resultCtrl;
  late final Animation<double> _resultScale;
  late final Animation<double> _resultFade;

  // ── Guard against double-expiry calls ─────────────────────────────────────
  bool _expiring = false;

  // ────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _userEmail = FirebaseAuth.instance.currentUser?.email;

    // Slow pulse on the envelope icon while in countdown
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulseScale = Tween(begin: 0.93, end: 1.07).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Springy entrance for the result card
    _resultCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _resultScale = CurvedAnimation(
      parent: _resultCtrl,
      curve: Curves.elasticOut,
    );
    _resultFade = CurvedAnimation(
      parent: _resultCtrl,
      curve: Curves.easeOut,
    );

    _initialize();
  }

  // ── Bootstrap ──────────────────────────────────────────────────────────────

  Future<void> _initialize() async {
    // 1. Quick check — maybe already verified before the screen even loads.
    try {
      await FirebaseAuth.instance.currentUser?.reload();
    } catch (_) {}

    if (FirebaseAuth.instance.currentUser?.emailVerified == true) {
      _onVerified();
      return;
    }

    // 2. Calculate remaining seconds from Firestore createdAt so the
    //    countdown is accurate even if the user backgrounded the app.
    int remaining = _kWindowSecs;
    int resendElapsed = 0;

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final doc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final ts = doc.data()?['createdAt'] as Timestamp?;
        if (ts != null) {
          final elapsed = DateTime.now().difference(ts.toDate()).inSeconds;
          remaining = (_kWindowSecs - elapsed).clamp(0, _kWindowSecs);
          resendElapsed = elapsed;
        }
      }
    } catch (_) {}

    if (!mounted) return;

    // Already expired while the app was closed
    if (remaining == 0) {
      await _onExpired();
      return;
    }

    setState(() {
      _secondsLeft = remaining;
      // If the initial email was sent less than 60 s ago, keep the cooldown.
      _resendLeft = (_kResendSecs - resendElapsed).clamp(0, _kResendSecs);
      _uiState = _VerifyState.countdown;
    });

    _startTimers();
  }

  // ── Timers ─────────────────────────────────────────────────────────────────

  void _startTimers() {
    // One-second tick for countdown + resend cooldown
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _uiState != _VerifyState.countdown) return;
      setState(() {
        if (_resendLeft > 0) _resendLeft--;
        if (_secondsLeft > 0) _secondsLeft--;
      });
      if (_secondsLeft == 0 && !_expiring) _onExpired();
    });

    // Poll Firebase for emailVerified every 3 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_uiState != _VerifyState.countdown) return;
      try {
        await FirebaseAuth.instance.currentUser?.reload();
        if (FirebaseAuth.instance.currentUser?.emailVerified == true) {
          _onVerified();
        }
      } catch (_) {}
    });
  }

  // ── Verified ───────────────────────────────────────────────────────────────

  void _onVerified() {
    _tickTimer?.cancel();
    _pollTimer?.cancel();
    _pulseCtrl.stop();

    if (!mounted) return;
    setState(() => _uiState = _VerifyState.verified);
    _resultCtrl.forward();

    // Auto-navigate to home after the success animation settles
    Future.delayed(const Duration(milliseconds: 3200), () {
      if (mounted) Navigator.of(context).pushReplacementNamed('/home');
    });
  }

  // ── Expired ────────────────────────────────────────────────────────────────

  Future<void> _onExpired() async {
    if (_expiring) return;
    _expiring = true;

    _tickTimer?.cancel();
    _pollTimer?.cancel();
    _pulseCtrl.stop();

    // Clean up the unverified account from both Auth and Firestore.
    // Deletion may fail if the session is stale (requires-recent-login);
    // we sign out instead so the account cannot be used.
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .delete()
            .catchError((_) {});
        await user.delete();
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        await FirebaseAuth.instance.signOut().catchError((_) {});
      }
    } catch (_) {
      await FirebaseAuth.instance.signOut().catchError((_) {});
    }

    if (!mounted) return;
    setState(() => _uiState = _VerifyState.declined);
    _resultCtrl.forward();
  }

  // ── Resend ─────────────────────────────────────────────────────────────────

  Future<void> _resendEmail() async {
    if (_resendLeft > 0 || _isSending) return;
    setState(() => _isSending = true);
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      if (mounted) {
        setState(() {
          _resendLeft = _kResendSecs;
          _emailSent = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Verification email resent.'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not resend: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ── Dispose ────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _tickTimer?.cancel();
    _pollTimer?.cancel();
    _pulseCtrl.dispose();
    _resultCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String get _timeString {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Green → orange → red as time runs out.
  Color get _timerColor {
    final frac = _secondsLeft / _kWindowSecs;
    if (frac > 0.50) return AppColors.primary;
    if (frac > 0.125) return const Color(0xFFD97706); // amber-600
    return Colors.red.shade600;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Verify Email',
      showBack: false,
      child: switch (_uiState) {
        _VerifyState.loading => _buildLoading(),
        _VerifyState.countdown => _buildCountdown(),
        _VerifyState.verified => _buildResult(success: true),
        _VerifyState.declined => _buildResult(success: false),
      },
    );
  }

  // ── Loading ────────────────────────────────────────────────────────────────

  Widget _buildLoading() {
    return const SizedBox(
      height: 480,
      child: Center(child: CircularProgressIndicator()),
    );
  }

  // ── Countdown ──────────────────────────────────────────────────────────────

  Widget _buildCountdown() {
    final timeIsLow = _secondsLeft <= 120;
    final timeIsUrgent = _secondsLeft <= 60;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 36),

        // ── Pulsing envelope icon ────────────────────────────────────────
        ScaleTransition(
          scale: _pulseScale,
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withOpacity(0.28),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_email_unread_rounded,
              size: 44,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // ── Heading ──────────────────────────────────────────────────────
        Text(
          'Check Your Inbox',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: AppColors.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        // ── Email address ────────────────────────────────────────────────
        if (_userEmail != null) ...[
          Text(
            "We've sent a link to",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _userEmail!,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ] else ...[
          Text(
            'Click the verification link in your email\nto activate your account.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              height: 1.55,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 36),

        // ── Countdown card ───────────────────────────────────────────────
        _CountdownCard(
          timeString: _timeString,
          timerColor: _timerColor,
          progress: _secondsLeft / _kWindowSecs,
        ),
        const SizedBox(height: 24),

        // ── Urgency warning (animates in) ────────────────────────────────
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SizeTransition(sizeFactor: anim, child: child),
          ),
          child: timeIsLow
              ? Padding(
                  key: const ValueKey('warn'),
                  padding: const EdgeInsets.only(bottom: 20),
                  child: _WarningBlob(urgent: timeIsUrgent),
                )
              : const SizedBox.shrink(key: ValueKey('none')),
        ),

        // ── Info blob ────────────────────────────────────────────────────
        InfoBlob(
          icon: Icons.info_outline_rounded,
          text: 'Click the link in the email to verify your account. '
              'This page automatically checks every few seconds and '
              'will redirect you once verified.',
          color: AppColors.secondaryContainer.withOpacity(0.35),
          iconColor: AppColors.secondary,
          textColor: AppColors.onSecondaryContainer,
        ),
        const SizedBox(height: 32),

        // ── Resend / cooldown button ─────────────────────────────────────
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _isSending
              ? const Padding(
                  key: ValueKey('spin'),
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(child: CircularProgressIndicator()),
                )
              : _resendLeft > 0
                  ? _ResendCooldownButton(
                      key: const ValueKey('cool'),
                      secondsLeft: _resendLeft,
                    )
                  : AuthPrimaryButton(
                      key: const ValueKey('resend'),
                      label: _emailSent
                          ? 'Resend Verification Email'
                          : 'Send Verification Email',
                      showIcon: false,
                      onTap: _resendEmail,
                    ),
        ),
        const SizedBox(height: 20),

        // ── Bail-out link ─────────────────────────────────────────────────
        TextButton(
          onPressed: () async {
            _tickTimer?.cancel();
            _pollTimer?.cancel();
            await FirebaseAuth.instance.signOut();
            if (mounted) {
              Navigator.of(context).pushReplacementNamed('/sign-in');
            }
          },
          child: Text(
            'Use a different account',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.outline,
            ),
          ),
        ),
        const SizedBox(height: 36),
      ],
    );
  }

  // ── Result screen (success / declined) ────────────────────────────────────

  Widget _buildResult({required bool success}) {
    return FadeTransition(
      opacity: _resultFade,
      child: ScaleTransition(
        scale: _resultScale,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 64),

            // Icon circle
            Container(
              width: 108,
              height: 108,
              decoration: BoxDecoration(
                color: success
                    ? AppColors.primaryContainer.withOpacity(0.28)
                    : Colors.red.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                success ? Icons.verified_rounded : Icons.timer_off_rounded,
                size: 56,
                color: success ? AppColors.primary : Colors.red.shade600,
              ),
            ),
            const SizedBox(height: 28),

            // Title
            Text(
              success ? 'Email Verified!' : 'Verification Expired',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: success ? AppColors.primary : Colors.red.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Body
            Text(
              success
                  ? 'Your account is now active.\nLogging you in to Mnemo…'
                  : 'The 8-minute verification window has closed.\n'
                      'Your account has been removed for security.\n'
                      'Please sign up again to create a new account.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                height: 1.65,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 40),

            // CTA
            if (success)
              // Spinner while auto-navigation is pending
              const CircularProgressIndicator()
            else
              AuthPrimaryButton(
                label: 'Sign Up Again',
                trailingIcon: Icons.restart_alt_rounded,
                onTap: () => Navigator.of(context)
                    .pushReplacementNamed('/sign-up/step-1'),
              ),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COUNTDOWN CARD
// Large MM:SS display with depleting linear bar and colour-shifting border.
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
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
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
          // Label
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.timer_outlined,
                size: 13,
                color: timerColor.withOpacity(0.60),
              ),
              const SizedBox(width: 6),
              Text(
                'TIME REMAINING',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                  color: timerColor.withOpacity(0.60),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Large MM:SS
          Text(
            timeString,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 58,
              fontWeight: FontWeight.w800,
              letterSpacing: -3,
              height: 1.0,
              color: timerColor,
            ),
          ),
          const SizedBox(height: 18),

          // Depleting bar
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: timerColor.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation<Color>(timerColor),
            ),
          ),
          const SizedBox(height: 12),

          // Sub-label
          Text(
            'Registration will be cancelled when the timer reaches 0:00',
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
// Shows a hourglass and the seconds left until the user can resend.
// ─────────────────────────────────────────────────────────────────────────────

class _ResendCooldownButton extends StatelessWidget {
  const _ResendCooldownButton({super.key, required this.secondsLeft});
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
          color: AppColors.outlineVariant.withOpacity(0.45),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.hourglass_top_rounded,
            size: 17,
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

// ─────────────────────────────────────────────────────────────────────────────
// WARNING BLOB
// Slides in at ≤ 2 min, switches to red at ≤ 1 min.
// ─────────────────────────────────────────────────────────────────────────────

class _WarningBlob extends StatelessWidget {
  const _WarningBlob({required this.urgent});
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final bg = urgent ? Colors.red.shade50 : Colors.amber.shade50;
    final border = urgent ? Colors.red.shade200 : Colors.amber.shade200;
    final icon = urgent ? Colors.red.shade600 : Colors.amber.shade700;
    final text = urgent ? Colors.red.shade700 : Colors.amber.shade800;
    final msg = urgent
        ? 'Under 1 minute left — verify now or your account will be removed!'
        : 'Under 2 minutes remaining. Please check your inbox quickly.';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: icon),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              msg,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                height: 1.5,
                color: text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
