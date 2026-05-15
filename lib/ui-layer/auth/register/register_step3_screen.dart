import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../landing_page/app_theme.dart';
import '../../../business-layer/services/auth_google_service.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/auth_buttons.dart';
import '../widgets/auth_decorations.dart';
import '../widgets/step_progress.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SIGN UP — STEP 3: CREDENTIALS
// Email + Password + Confirm Password.
// Calls AuthService.registerWithDetails and shows a success modal.
// ─────────────────────────────────────────────────────────────────────────────

class SignUpStep3Screen extends StatelessWidget {
  const SignUpStep3Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Create Account',
      showBack: true,
      child: const _Step3Body(),
    );
  }
}

class _Step3Body extends StatefulWidget {
  const _Step3Body();

  @override
  State<_Step3Body> createState() => _Step3BodyState();
}

class _Step3BodyState extends State<_Step3Body> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    final rawArgs = ModalRoute.of(context)!.settings.arguments;
    final Map<String, dynamic> args =
        rawArgs != null ? Map<String, dynamic>.from(rawArgs as Map) : {};

    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();

    // ── Validation ────────────────────────────────────────────────────────
    if (email.isEmpty || password.isEmpty || confirm.isEmpty) {
      _showError('Please fill in all fields.');
      return;
    }

    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(email)) {
      _showError('Please enter a valid email address.');
      return;
    }

    if (password.length < 8) {
      _showError('Password must be at least 8 characters long.');
      return;
    }

    if (password != confirm) {
      _showError('Passwords do not match.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await AuthService().registerWithDetails(
        email: email,
        password: password,
        fullName: args['fullName'] ?? '',
        username: args['username'] ?? '',
        age: args['age'] ?? 0,
        country: args['country'] ?? '',
      );

      if (user != null) {
        _showSuccessModal(context);
      } else {
        _showError('Registration failed. Please try again.');
      }
    } catch (e) {
      _showError('An error occurred: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccessModal(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mark_email_read_rounded,
                color: AppColors.primary,
                size: 36,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Verify your email',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'We\'ve sent a verification link to your email. Please check your inbox and click the link to activate your account.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                height: 1.6,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            AuthPrimaryButton(
              label: 'Got it',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacementNamed('/sign-in');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),

        // ── Progress bar ──────────────────────────────────────────────────
        const StepProgressBar(current: 3, total: 3),
        const SizedBox(height: 36),

        // ── Section header ────────────────────────────────────────────────
        Text(
          'Secure your account',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Create a strong password to keep your study data safe.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            height: 1.6,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 32),

        // ── Form fields ───────────────────────────────────────────────────
        AuthTextField(
          controller: _emailCtrl,
          hint: 'alex@study.com',
          label: 'Email Address',
          prefixIcon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          shape: AuthFieldShape.rounded,
        ),
        const SizedBox(height: 20),
        AuthTextField(
          controller: _passwordCtrl,
          hint: '••••••••',
          label: 'Password',
          prefixIcon: Icons.lock_outline_rounded,
          obscureText: _obscurePassword,
          suffixIcon: _obscurePassword
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          onSuffixTap: () => setState(() => _obscurePassword = !_obscurePassword),
          shape: AuthFieldShape.rounded,
          helperText: 'Must be at least 8 characters',
        ),
        const SizedBox(height: 20),
        AuthTextField(
          controller: _confirmCtrl,
          hint: '••••••••',
          label: 'Confirm Password',
          prefixIcon: Icons.lock_outline_rounded,
          obscureText: _obscureConfirm,
          suffixIcon: _obscureConfirm
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          onSuffixTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
          shape: AuthFieldShape.rounded,
        ),
        const SizedBox(height: 36),

        // ── Info blob ─────────────────────────────────────────────────────
        InfoBlob(
          icon: Icons.shield_outlined,
          text: 'Your password is encrypted and never shared. We recommend using a unique password with letters, numbers, and symbols.',
          color: AppColors.secondaryContainer.withOpacity(0.35),
          iconColor: AppColors.secondary,
          textColor: AppColors.onSecondaryContainer,
        ),
        const SizedBox(height: 36),

        // ── Sign Up CTA ───────────────────────────────────────────────────
        _isLoading
            ? const Center(child: CircularProgressIndicator())
            : AuthPrimaryButton(
                label: 'Create Account',
                onTap: _handleSignUp,
              ),
        const SizedBox(height: 32),
      ],
    );
  }
}

