import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../landing_page/app_theme.dart';
import '../main.dart';
import 'services/auth_google_service.dart';
import 'widgets_design.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LOGIN ATTEMPT TRACKER  (singleton — survives widget rebuilds)
//
// Rules:
//   • Each failed login attempt is timestamped.
//   • Attempts older than 10 minutes are discarded on every check.
//   • If 10 failures accumulate within that 10-minute window the device is
//     locked out for 30 minutes, counted from the moment of the 10th failure.
// ─────────────────────────────────────────────────────────────────────────────

class _LoginAttemptTracker {
  _LoginAttemptTracker._();
  static final _LoginAttemptTracker instance = _LoginAttemptTracker._();

  static const int _maxAttempts = 10;
  static const int _windowMinutes = 20; // sliding 20-minute window
  static const int _lockoutMinutes = 30;

  final List<DateTime> _failedAttempts = [];
  DateTime? _lockedUntil;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns null when the device is NOT locked out; otherwise returns the
  /// [DateTime] at which the lockout expires.
  DateTime? get lockedUntil {
    if (_lockedUntil == null) return null;
    if (DateTime.now().isAfter(_lockedUntil!)) {
      // Lockout has expired — clear everything.
      _lockedUntil = null;
      _failedAttempts.clear();
      return null;
    }
    return _lockedUntil;
  }

  bool get isLocked => lockedUntil != null;

  /// Remaining lockout in whole seconds (0 when not locked).
  int get remainingSeconds {
    final until = lockedUntil;
    if (until == null) return 0;
    return until.difference(DateTime.now()).inSeconds.clamp(0, 99999);
  }

  /// Call this after every failed login attempt.
  void recordFailure() {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(minutes: _windowMinutes));

    // Discard stale attempts.
    _failedAttempts.removeWhere((t) => t.isBefore(cutoff));
    _failedAttempts.add(now);

    if (_failedAttempts.length >= _maxAttempts) {
      _lockedUntil = now.add(const Duration(minutes: _lockoutMinutes));
      _failedAttempts.clear(); // reset counter so next window is fresh
    }
  }

  /// Call this on a successful login to reset state.
  void recordSuccess() {
    _failedAttempts.clear();
    _lockedUntil = null;
  }

  /// How many failures are still within the current window.
  int get recentFailures {
    final cutoff =
        DateTime.now().subtract(const Duration(minutes: _windowMinutes));
    return _failedAttempts.where((t) => t.isAfter(cutoff)).length;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SIGN IN SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'MnemoApp',
      showBack: true,
      child: const _SignInBody(),
    );
  }
}

class _SignInBody extends StatefulWidget {
  const _SignInBody();

  @override
  State<_SignInBody> createState() => _SignInBodyState();
}

class _SignInBodyState extends State<_SignInBody> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _isLoading = false;

  // Lockout countdown
  Timer? _lockoutTicker;

  final _tracker = _LoginAttemptTracker.instance;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _startLockoutTickerIfNeeded();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _lockoutTicker?.cancel();
    super.dispose();
  }

  // ── Lockout helpers ────────────────────────────────────────────────────────

  void _startLockoutTickerIfNeeded() {
    if (_tracker.isLocked) {
      _lockoutTicker?.cancel();
      _lockoutTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!_tracker.isLocked) {
          _lockoutTicker?.cancel();
        }
        if (mounted) setState(() {});
      });
    }
  }

  String _formatLockoutTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Error helpers ──────────────────────────────────────────────────────────

  /// Converts a FirebaseAuthException code into a user-friendly message.
  /// Note: 'invalid-credential' and 'user-not-found' are NOT handled here —
  /// they go through an async email-existence check in [_handleSignIn] first.
  String _friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      // ── Email problems ───────────────────────────────────────────────────
      case 'invalid-email':
        return 'That doesn\'t look like a valid email address.';

      // ── Password problems ────────────────────────────────────────────────
      case 'wrong-password':
        return 'Incorrect password. Please try again.';

      // ── Account state ────────────────────────────────────────────────────
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';

      // ── Rate limiting (Firebase-side) ────────────────────────────────────
      case 'too-many-requests':
        return 'Too many sign-in attempts detected by Firebase. '
            'Please wait a few minutes before trying again.';

      // ── Network ──────────────────────────────────────────────────────────
      case 'network-request-failed':
        return 'Network error. Check your internet connection and try again.';

      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }

  void _showError(String message) {
    if (!mounted) return;
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Sign-in logic ──────────────────────────────────────────────────────────

  Future<void> _handleSignIn() async {
    // 1. Client-side lockout check
    if (_tracker.isLocked) {
      _showError(
        'Account locked. Too many failed attempts. '
        'Please wait ${_formatLockoutTime(_tracker.remainingSeconds)}.',
      );
      return;
    }

    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    // 2. Basic empty-field check
    if (email.isEmpty && password.isEmpty) {
      _showError('Please enter your email and password.');
      return;
    }
    if (email.isEmpty) {
      _showError('Please enter your email address.');
      return;
    }
    if (password.isEmpty) {
      _showError('Please enter your password.');
      return;
    }

    // 3. Basic format check (catches obvious typos before hitting Firebase)
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(email)) {
      _showError('That doesn\'t look like a valid email address.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await AuthService().login(email, password);

      if (user != null) {
        _tracker.recordSuccess();

        // Email verification gate
        if (!user.emailVerified) {
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            Navigator.pushNamed(
              context,
              '/verify-email',
              arguments: {'email': email},
            );
          }
          return;
        }

        _showSuccess('Welcome back!');
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) Navigator.pushReplacementNamed(context, '/profile');
      }
    } on FirebaseAuthException catch (e) {
      // ── Disambiguate the generic "invalid-credential" / "user-not-found"
      // codes. fetchSignInMethodsForEmail was removed in Firebase Auth v5+.
      // Instead we do a silent Firestore lookup — no emails sent, no side
      // effects — to check whether the address is registered at all.
      String errorMessage;

      if (e.code == 'invalid-credential' || e.code == 'user-not-found') {
        try {
          final snapshot = await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: email)
              .limit(1)
              .get();

          if (snapshot.docs.isEmpty) {
            errorMessage = 'No account found with that email address. '
                'Please check the email or sign up.';
          } else {
            errorMessage = 'Incorrect password. Please try again.';
          }
        } catch (_) {
          // Firestore lookup failed (offline, rules, etc.) — safe fallback.
          errorMessage =
              'No account found with that email, or the password is incorrect.';
        }
      } else {
        errorMessage = _friendlyError(e);
      }

      // Record the failure and check whether lockout just triggered.
      _tracker.recordFailure();
      _startLockoutTickerIfNeeded();

      if (_tracker.isLocked) {
        _showError(
          'Too many failed attempts. '
          'Your account is locked for 30 minutes.',
        );
      } else {
        final remaining =
            _LoginAttemptTracker._maxAttempts - _tracker.recentFailures;
        final suffix = remaining > 0
            ? ' ($remaining attempt${remaining == 1 ? '' : 's'} remaining before lockout)'
            : '';
        _showError('$errorMessage$suffix');
      }
    } catch (_) {
      _showError('An unexpected error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final locked = _tracker.isLocked;
    final remainingSeconds = _tracker.remainingSeconds;

    return Column(
      children: [
        const SizedBox(height: 24),

        // ── Branding block ────────────────────────────────────────────────
        const _SignInBranding(),
        const SizedBox(height: 32),

        // ── Lockout banner ────────────────────────────────────────────────
        if (locked) ...[
          _LockoutBanner(
            remainingTime: _formatLockoutTime(remainingSeconds),
          ),
          const SizedBox(height: 20),
        ],

        // ── Main card ─────────────────────────────────────────────────────
        AuthCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Google
              const GoogleSignInButton(),
              const SizedBox(height: 28),
              const OrDivider(),
              const SizedBox(height: 28),

              // Email
              AuthTextField(
                controller: _emailCtrl,
                hint: 'alex@study.com',
                prefixIcon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),

              // Password row — label + forgot link
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox.shrink(),
                  GestureDetector(
                    onTap: () {},
                    child: Text(
                      'Forgot password?',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AuthTextField(
                controller: _passwordCtrl,
                hint: '••••••••',
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: _obscure,
                suffixIcon: _obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                onSuffixTap: () => setState(() => _obscure = !_obscure),
              ),
              const SizedBox(height: 28),

              // ── Sign In CTA ──────────────────────────────────────────────
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : AuthPrimaryButton(
                      label: locked
                          ? 'Locked — ${_formatLockoutTime(remainingSeconds)}'
                          : 'Sign In',
                      showIcon: false,
                      onTap: _handleSignIn,
                    ),
              const SizedBox(height: 24),

              // Sign Up link
              Center(
                child: RichText(
                  text: TextSpan(
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: AppColors.onSurfaceVariant,
                    ),
                    children: [
                      const TextSpan(text: 'New to MnemoApp? '),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: GestureDetector(
                          onTap: () => Navigator.of(context)
                              .pushNamed(AppRoutes.signUp1),
                          child: Text(
                            'Sign Up',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                              decoration: TextDecoration.underline,
                              decorationColor:
                                  AppColors.primary.withOpacity(0.4),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Daily goal chip ───────────────────────────────────────────────
        const _DailyGoalChip(),
        const SizedBox(height: 32),

        // ── Footer links ──────────────────────────────────────────────────
        const _SignInFooter(),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOCKOUT BANNER
// ─────────────────────────────────────────────────────────────────────────────

class _LockoutBanner extends StatelessWidget {
  const _LockoutBanner({required this.remainingTime});
  final String remainingTime;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_rounded, color: Colors.red.shade600, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Account Temporarily Locked',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.red.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Too many failed sign-in attempts. '
                  'Please try again in:',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    height: 1.5,
                    color: Colors.red.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  remainingTime,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.red.shade700,
                    letterSpacing: 1,
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
// SUB-WIDGETS  (unchanged from original)
// ─────────────────────────────────────────────────────────────────────────────

class _SignInBranding extends StatelessWidget {
  const _SignInBranding();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Transform.rotate(
          angle: 0.052,
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_stories_rounded,
              color: AppColors.primary,
              size: 34,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Welcome back',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Your journey to mastery continues',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _DailyGoalChip extends StatelessWidget {
  const _DailyGoalChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.tertiaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.tertiaryContainer.withOpacity(0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome_rounded,
              size: 18, color: AppColors.tertiary),
          const SizedBox(width: 10),
          Text(
            "Today's goal: Master 10 new cards!",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.onTertiaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _SignInFooter extends StatelessWidget {
  const _SignInFooter();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 24,
      runSpacing: 8,
      children: [
        Text(
          '© 2024 MnemoApp',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.primary.withOpacity(0.6),
          ),
        ),
        ...[
          'Privacy Policy',
          'Terms of Service',
          'Help Center',
        ].map(
          (l) => GestureDetector(
            onTap: () {},
            child: Text(
              l,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurfaceVariant.withOpacity(0.55),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
