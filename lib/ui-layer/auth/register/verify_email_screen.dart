import 'dart:async';
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
// Responsibilities (deliberately limited):
//   1. Show a countdown timer so the user knows how long they have.
//   2. Poll Firebase every 3 s to detect when emailVerified becomes true.
//   3. On verified  → show success UI, then trigger a token refresh so
//      AuthGate's idTokenChanges() stream transitions to MainShell.
//   4. On expired   → delete the unverified account, then sign out.
//      AuthGate will react to the sign-out and show LandingScreen.
//
// What this screen does NOT do:
//   • Navigate via Navigator — AuthGate owns all routing.
//   • Delete accounts that are already verified.
//   • Delete accounts whose createdAt is older than 2× the window.
// ─────────────────────────────────────────────────────────────────────────────

const int _kWindowSecs = 480; // 8 minutes
const int _kResendSecs = 60; // 1 minute cooldown between resends

enum _VerifyState { loading, countdown, verified, expired }

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen>
    with TickerProviderStateMixin {
  _VerifyState _uiState = _VerifyState.loading;

  int _secondsLeft = _kWindowSecs;
  int _resendLeft = _kResendSecs;
  bool _isSending = false;
  bool _emailSent = false;
  String? _userEmail;

  // Single source of truth — only one of these can become true.
  bool _isVerified = false;
  bool _isExpired = false;

  Timer? _tickTimer;
  Timer? _pollTimer;

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseScale;
  late final AnimationController _resultCtrl;
  late final Animation<double> _resultScale;
  late final Animation<double> _resultFade;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _userEmail = FirebaseAuth.instance.currentUser?.email;

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulseScale = Tween(begin: 0.93, end: 1.07).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

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

  @override
  void dispose() {
    _tickTimer?.cancel();
    _pollTimer?.cancel();
    _pulseCtrl.dispose();
    _resultCtrl.dispose();
    super.dispose();
  }

  // ── Bootstrap ──────────────────────────────────────────────────────────────

  Future<void> _initialize() async {
    // Reload first so we have a fresh emailVerified value.
    try {
      await FirebaseAuth.instance.currentUser?.reload();
    } catch (_) {}

    // If already verified (e.g. user reopened app after clicking link),
    // go straight to success.
    if (FirebaseAuth.instance.currentUser?.emailVerified == true) {
      _handleVerified();
      return;
    }

    // Work out how much time is left based on Firestore createdAt.
    // This makes the countdown survive app restarts.
    int remaining = _kWindowSecs;
    int resendElapsed = 0;

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        final ts = doc.data()?['createdAt'] as Timestamp?;
        if (ts != null) {
          final elapsed = DateTime.now().difference(ts.toDate()).inSeconds;
          remaining = (_kWindowSecs - elapsed).clamp(0, _kWindowSecs);
          resendElapsed = elapsed;
        }
      }
    } catch (_) {}

    if (!mounted) return;

    // Window already closed while the app was away.
    if (remaining == 0) {
      // One last chance — maybe they verified while the app was closed.
      try {
        await FirebaseAuth.instance.currentUser?.reload();
      } catch (_) {}
      if (FirebaseAuth.instance.currentUser?.emailVerified == true) {
        _handleVerified();
        return;
      }
      _handleExpired();
      return;
    }

    if (!mounted) return;
    setState(() {
      _secondsLeft = remaining;
      _resendLeft = (_kResendSecs - resendElapsed).clamp(0, _kResendSecs);
      _uiState = _VerifyState.countdown;
    });

    _startTimers();
  }

  // ── Timers ─────────────────────────────────────────────────────────────────

  void _startTimers() {
    print('[VerifyEmail] Starting timers. secondsLeft=$_secondsLeft');
    
    // Tick every second: decrement counters, trigger expiry at 0.
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _uiState != _VerifyState.countdown) return;
      if (_isVerified || _isExpired) return;

      setState(() {
        if (_resendLeft > 0) _resendLeft--;
        if (_secondsLeft > 0) _secondsLeft--;
      });

      if (_secondsLeft == 0) {
        print('[VerifyEmail] Timer hit zero, calling _handleExpired');
        _handleExpired();
      }
    });

    // Poll Firebase every 3 s to detect email verification.
    // We use reload() here — NOT getIdToken(true). getIdToken forces a
    // token refresh which would immediately trigger idTokenChanges() in
    // AuthGate before _handleVerified() has a chance to show the animation.
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted || _uiState != _VerifyState.countdown) return;
      if (_isVerified || _isExpired) return;
      try {
        await FirebaseAuth.instance.currentUser?.reload();
        final isVerified = FirebaseAuth.instance.currentUser?.emailVerified == true;
        if (isVerified) {
          print('[VerifyEmail] Poll detected verification');
          _handleVerified();
        }
      } catch (_) {}
    });
  }

  // ── Verified ───────────────────────────────────────────────────────────────

  void _handleVerified() {
    // Guard: only run once; never run if we've already expired.
    if (_isVerified || _isExpired) return;
    _isVerified = true;

    print('[VerifyEmail] _handleVerified called. _isExpired=$_isExpired');

    _tickTimer?.cancel();
    _pollTimer?.cancel();
    _pulseCtrl.stop();

    if (!mounted) return;
    setState(() => _uiState = _VerifyState.verified);
    _resultCtrl.forward();

    // CRITICAL: Update Firestore emailVerified field so Cloud Function doesn't delete us
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'emailVerified': true})
          .catchError((_) {});
    }

    // Show success animation for 2 seconds, then manually navigate.
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (!mounted) return;
      print('[VerifyEmail] Navigating to /home');
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    });
  }

  // ── Expired ────────────────────────────────────────────────────────────────

  Future<void> _handleExpired() async {
    // Guard: only run once; never run if already verified.
    if (_isExpired || _isVerified) return;
    _isExpired = true;

    print('[VerifyEmail] _handleExpired called. _isVerified=$_isVerified');

    _tickTimer?.cancel();
    _pollTimer?.cancel();
    _pulseCtrl.stop();

    // ── CRITICAL: Do a final reload before touching anything. ──────────────
    // There is a real race between the 1-second tick and the 3-second poll.
    // The tick can hit 0 in the same window the poll is mid-await. We must
    // re-check emailVerified here before doing any deletion.
    try {
      await FirebaseAuth.instance.currentUser?.reload();
    } catch (_) {}

    final isVerified = FirebaseAuth.instance.currentUser?.emailVerified == true;
    print('[VerifyEmail] After reload, emailVerified=$isVerified');

    if (isVerified) {
      // Verified just as the timer hit zero — treat as success, not expiry.
      print('[VerifyEmail] User verified just in time, calling _handleVerified');
      _isExpired = false;
      _handleVerified();
      return;
    }

    // ── Account age check ──────────────────────────────────────────────────
    // Only delete accounts created within the verification window (+ buffer).
    // If the account is older, this screen was shown incorrectly — sign out
    // safely instead of destroying user data.
    bool safeToDelete = false;
    int? accountAgeSeconds;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        final ts = doc.data()?['createdAt'] as Timestamp?;
        if (ts != null) {
          accountAgeSeconds =
              DateTime.now().difference(ts.toDate()).inSeconds;
          // Only delete if account is within 2× the verification window.
          safeToDelete = accountAgeSeconds <= (_kWindowSecs * 2);
        }
      }
    } catch (_) {}

    print('[VerifyEmail] Account age: ${accountAgeSeconds}s, safeToDelete=$safeToDelete');

    if (safeToDelete) {
      print('[VerifyEmail] Deleting unverified account');
      // Delete the Firestore document first, then the Auth account.
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .delete()
              .catchError((_) {});
          await user.delete();
          print('[VerifyEmail] Account deleted successfully');
          // user.delete() signs the user out automatically, which triggers
          // idTokenChanges() → AuthGate shows LandingScreen. Done.
          return;
        }
      } on FirebaseAuthException catch (e) {
        print('[VerifyEmail] Delete failed: ${e.code}');
        if (e.code == 'requires-recent-login') {
          // Can't delete — session too old. Just sign out.
          await FirebaseAuth.instance.signOut().catchError((_) {});
          return;
        }
      } catch (e) {
        print('[VerifyEmail] Delete failed with exception: $e');
        await FirebaseAuth.instance.signOut().catchError((_) {});
        return;
      }
    } else {
      print('[VerifyEmail] Account too old to delete, signing out instead');
      // Account is too old to be a fresh registration — don't delete it.
      // Just sign out. The user can log back in.
      await FirebaseAuth.instance.signOut().catchError((_) {});
      return;
    }

    // Fallback: if we're still here, sign out.
    print('[VerifyEmail] Fallback: signing out');
    await FirebaseAuth.instance.signOut().catchError((_) {});
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

  // ── Helpers ────────────────────────────────────────────────────────────────

  String get _timeString {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Color get _timerColor {
    final frac = _secondsLeft / _kWindowSecs;
    if (frac > 0.50) return AppColors.primary;
    if (frac > 0.125) return const Color(0xFFD97706);
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
        _VerifyState.expired => _buildResult(success: false),
      },
    );
  }

  Widget _buildLoading() {
    return const SizedBox(
      height: 480,
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildCountdown() {
    final timeIsLow = _secondsLeft <= 120;
    final timeIsUrgent = _secondsLeft <= 60;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 36),
        ScaleTransition(
          scale: _pulseScale,
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.28),
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
        _CountdownCard(
          timeString: _timeString,
          timerColor: _timerColor,
          progress: _secondsLeft / _kWindowSecs,
        ),
        const SizedBox(height: 24),
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
        InfoBlob(
          icon: Icons.info_outline_rounded,
          text: 'Click the link in the email to verify your account. '
              'This page automatically checks every few seconds and '
              'will redirect you once verified.',
          color: AppColors.secondaryContainer.withValues(alpha: 0.35),
          iconColor: AppColors.secondary,
          textColor: AppColors.onSecondaryContainer,
        ),
        const SizedBox(height: 32),
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
        TextButton(
          onPressed: () async {
            _tickTimer?.cancel();
            _pollTimer?.cancel();
            await FirebaseAuth.instance.signOut();
            // AuthGate will handle routing to LandingScreen automatically.
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

  Widget _buildResult({required bool success}) {
    return FadeTransition(
      opacity: _resultFade,
      child: ScaleTransition(
        scale: _resultScale,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 64),
            Container(
              width: 108,
              height: 108,
              decoration: BoxDecoration(
                color: success
                    ? AppColors.primaryContainer.withValues(alpha: 0.28)
                    : Colors.red.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                success ? Icons.verified_rounded : Icons.timer_off_rounded,
                size: 56,
                color: success ? AppColors.primary : Colors.red.shade600,
              ),
            ),
            const SizedBox(height: 28),
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
            Text(
              success
                  ? 'Your account is now active.\nLogging you in to Mnemo…'
                  : 'The 8-minute verification window has closed.\n'
                      'Your account has been removed.\n'
                      'Please sign up again to create a new account.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                height: 1.65,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 40),
            // In the success case, AuthGate handles navigation automatically
            // once the token refresh fires. Show a spinner while waiting.
            if (success) const CircularProgressIndicator(),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COUNTDOWN CARD
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
        color: timerColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: timerColor.withValues(alpha: 0.22),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.timer_outlined,
                  size: 13, color: timerColor.withValues(alpha: 0.60)),
              const SizedBox(width: 6),
              Text(
                'TIME REMAINING',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                  color: timerColor.withValues(alpha: 0.60),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: timerColor.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(timerColor),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Registration will be cancelled when the timer reaches 0:00',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              height: 1.5,
              color: timerColor.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RESEND COOLDOWN BUTTON
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
          color: AppColors.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hourglass_top_rounded, size: 17, color: AppColors.outline),
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
