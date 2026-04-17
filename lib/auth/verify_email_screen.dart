import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../landing_page/app_theme.dart';
import 'auth_widgets.dart';

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

// ─────────────────────────────────────────────────────────────

class _VerifyEmailBody extends StatefulWidget {
  const _VerifyEmailBody({required this.email});
  final String email;

  @override
  State<_VerifyEmailBody> createState() => _VerifyEmailBodyState();
}

class _VerifyEmailBodyState extends State<_VerifyEmailBody> {
  Timer? _timer;
  Timer? _resendTimer;

  int _resendSeconds = 0;

  //Account deletion after certain time
  int _deleteSeconds = 90; // change to 1800 for 30 mins later
  Timer? _deleteTimer;

  @override
  void initState() {
    super.initState();

    // 🔥 Start auto-checking every 5 seconds
    _timer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await _checkEmailVerifiedAuto();
    });

    _deleteTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_deleteSeconds > 0) {
        setState(() => _deleteSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int secs = seconds % 60;

    return "${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}";
  }

  Future<void> _handleResend() async {
    if (_resendSeconds > 0) return; // 🚫 prevent spam

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        await user.sendEmailVerification();

        _showError("Verification email sent.");

        // 🔥 Start cooldown (30 seconds)
        setState(() => _resendSeconds = 30);

        _resendTimer?.cancel();
        _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (_resendSeconds == 0) {
            timer.cancel();
          } else {
            setState(() => _resendSeconds--);
          }
        });
      } else {
        _showError("User not logged in.");
      }
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? "Failed to resend email.");
    } catch (e) {
      _showError("Something went wrong.");
    }
  }

  Future<void> _checkEmailVerifiedAuto() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _handleAccountDeleted();
        return;
      }

      await user.reload(); // refresh from Firebase
      final refreshedUser = FirebaseAuth.instance.currentUser;

      if (refreshedUser == null) {
        _handleAccountDeleted();
        return;
      }

      if (refreshedUser.emailVerified) {
        _timer?.cancel();

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'emailVerified': true,
        });

        if (mounted) {
          // Show success popup
          _showSuccess("Registered successfully!");

          // Wait for 3 seconds so user can see the message
          await Future.delayed(const Duration(seconds: 3));

          // Redirect to Home
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } on FirebaseAuthException catch (e) {
      // Triggers when user/account is deleted from firebase auth
      if (e.code == 'user-not-found') {
        _handleAccountDeleted();
      }
    } catch (e) {
      // fallback safety
      _handleAccountDeleted();
    }
  }

  void _handleAccountDeleted() async {
    _timer?.cancel();
    _deleteTimer?.cancel();

    // Show popup
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Account expired due to unverified email.",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: Colors.white,
            ),
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        ),
      );

      // Wait so user can read message
      await Future.delayed(const Duration(seconds: 3));

      //  Force logout (important)
      await FirebaseAuth.instance.signOut();

      //  Redirect to landing page
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/',
        (route) => false,
      );
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary, // success color
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

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
  void dispose() {
    _timer?.cancel();
    _resendTimer?.cancel();
    _deleteTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
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
                  text:
                      '. Click the link in your email to verify your account.'),
            ],
          ),
        ),
        const SizedBox(height: 36),
        AuthCard(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              Icon(
                Icons.mark_email_unread_rounded,
                size: 64,
                color: AppColors.primary,
              ),

              const SizedBox(height: 20),

              Text(
                "Waiting for verification...",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                "We’ll automatically continue once you verify your email.",
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: AppColors.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 28),

              // 🔄 Loading indicator
              const CircularProgressIndicator(),

              const SizedBox(height: 20),

              Text(
                "⏳ Account will be deleted in:",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                _formatTime(_deleteSeconds),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.red,
                ),
              ),

              if (_deleteSeconds == 0) ...[
                const SizedBox(height: 10),
                Text(
                  "Account expired. Please register again.",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: Colors.red,
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // 🔁 RESEND
              GestureDetector(
                onTap: _resendSeconds == 0 ? _handleResend : null,
                child: Text(
                  _resendSeconds == 0
                      ? "Didn't receive the email? Resend"
                      : "Resend in ${_resendSeconds}s",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _resendSeconds == 0
                        ? AppColors.secondary
                        : Colors.grey, // disabled look
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _BuddyTipCard(),
        const SizedBox(height: 36),
        _DevBypassButton(onBypass: () => Navigator.of(context).pop(true)),
        const SizedBox(height: 36),
      ],
    );
  }
}
// ─────────────────────────────────────────────────────────────

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
                  "Check your spam or junk folder if you don't see the email.",
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

// ─────────────────────────────────────────────────────────────

class _DevBypassButton extends StatelessWidget {
  const _DevBypassButton({required this.onBypass});
  final VoidCallback onBypass;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onBypass,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.orange.withOpacity(0.35)),
        ),
        child: Center(
          child: Text(
            'Bypass Email Verification (DEV)',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.orange.shade700,
            ),
          ),
        ),
      ),
    );
  }
}
