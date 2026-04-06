import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../landing_page/app_theme.dart';
import '../services/auth_service.dart';
import 'auth_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SIGN UP — STEP 3: SECURITY
// Email, Password, Confirm Password, Data privacy note, Complete Sign Up CTA.
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
  final _pwCtrl = TextEditingController();
  final _pw2Ctrl = TextEditingController();

  String? _errorMessage;
  bool _isLoading = false;
  
  bool _obscure1 = true;
  bool _obscure2 = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    _pw2Ctrl.dispose();
    super.dispose();
  }

  String? validateFields() {
  if (_emailCtrl.text.isEmpty ||
      _pwCtrl.text.isEmpty ||
      _pw2Ctrl.text.isEmpty) {
    return "Please fill all fields";
  }

  if (!_emailCtrl.text.contains('@')) {
    return "Invalid email";
  }

  if (_pwCtrl.text.length < 12) {
    return "Password must be at least 12 characters";
  }

  if (_pwCtrl.text != _pw2Ctrl.text) {
    return "Passwords do not match";
  }

  return null;
}

Future<void> registerUser(Map<String, dynamic> args) async {
  setState(() {
    _isLoading = true;
    _errorMessage = null;
  });

  try {
    final user = await AuthService().registerWithDetails(
      email: _emailCtrl.text.trim(),
      password: _pwCtrl.text.trim(),
      fullName: args['fullName']  ?? '',
      username: args['username'] ?? '',
      age: args['age'] ?? 0,
      country: args['country'] ?? '',
    );

    if (user == null) {
      setState(() {
        _errorMessage = "Registration failed";
      });
    } 

  } catch (e) {
    setState(() {
      _errorMessage = e.toString();
    });
  }

  setState(() {
    _isLoading = false;
  });
}

  @override
  Widget build(BuildContext context) {
    final rawArgs = ModalRoute.of(context)!.settings.arguments;

    final Map<String, dynamic> args =
        rawArgs != null ? Map<String, dynamic>.from(rawArgs as Map) : {};
      
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),

        // ── Progress bar ──────────────────────────────────────────────────
        const StepProgressBar(current: 3, total: 3),
        const SizedBox(height: 36),

        // ── Header ────────────────────────────────────────────────────────
        // Container(
        //   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        //   decoration: BoxDecoration(
        //     color: AppColors.primaryContainer.withOpacity(0.28),
        //     borderRadius: BorderRadius.circular(999),
        //   ),
        //   child: Text(
        //     'SECURITY FIRST',
        //     style: GoogleFonts.plusJakartaSans(
        //       fontSize: 10,
        //       fontWeight: FontWeight.w800,
        //       letterSpacing: 2,
        //       color: AppColors.primary,
        //     ),
        //   ),
        // ),
        const SizedBox(height: 12),
        Text(
          'Secure your study journey.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Set up your credentials to protect your progress and personalised decks.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            height: 1.6,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 28),

        // ── Main card ─────────────────────────────────────────────────────
        AuthCard(
          child: Column(
            children: [
              // Google button
              const GoogleSignInButton(),
              const SizedBox(height: 24),
              const OrDivider(),
              const SizedBox(height: 24),

              // Email
              AuthTextField(
                controller: _emailCtrl,
                hint: 'hello@mnemoapp.com',
                label: 'Email Address',
                prefixIcon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                shape: AuthFieldShape.rounded,
              ),
              const SizedBox(height: 18),

              // Password
              AuthTextField(
                controller: _pwCtrl,
                hint: '••••••••',
                label: 'Password',
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: _obscure1,
                suffixIcon: _obscure1
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                onSuffixTap: () => setState(() => _obscure1 = !_obscure1),
                shape: AuthFieldShape.rounded,
              ),
              const SizedBox(height: 18),

              // Confirm Password
              AuthTextField(
                controller: _pw2Ctrl,
                hint: '••••••••',
                label: 'Confirm Password',
                prefixIcon: Icons.lock_reset_rounded,
                obscureText: _obscure2,
                suffixIcon: _obscure2
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                onSuffixTap: () => setState(() => _obscure2 = !_obscure2),
                shape: AuthFieldShape.rounded,
              ),
              const SizedBox(height: 20),

              // Password requirements
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.outlineVariant.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'At least 12 characters with uppercase letters, '
                        'numbers, and symbols for maximum security.',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            height: 1.55,
                            color: AppColors.onSurfaceVariant.withOpacity(0.35)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              // Complete Sign Up CTA — UI only
              AuthPrimaryButton(
                label: 'Complete Sign Up',
                trailingIcon: Icons.check_rounded,
                onTap: () async {
                  final error = validateFields();

                  if (error != null) {
                    setState(() => _errorMessage = error);
                    return;
                  }

                  await registerUser(args);

                  if (_errorMessage == null) {
                    _showSuccessSheet(context);
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Data privacy bento ────────────────────────────────────────────
        _PrivacyBento(),
        const SizedBox(height: 28),

        // ── Terms note ────────────────────────────────────────────────────
        Center(
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppColors.outline,
              ),
              children: [
                const TextSpan(
                    text: 'By completing sign up, you agree to our '),
                _linkSpan('Terms of Service'),
                const TextSpan(text: ' and '),
                _linkSpan('Privacy Policy'),
                const TextSpan(text: '.'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 36),
      ],
    );
  }

  TextSpan _linkSpan(String text) => TextSpan(
        text: text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
          decoration: TextDecoration.underline,
          decorationColor: AppColors.primary.withOpacity(0.4),
        ),
      );

  /// Temporary success sheet — replace with real post-signup navigation.
  void _showSuccessSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SuccessSheet(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRIVACY BENTO CARD
// ─────────────────────────────────────────────────────────────────────────────

class _PrivacyBento extends StatelessWidget {
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
        children: [
          // Icon + text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified_user_rounded,
                        color: AppColors.tertiary, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'Data Privacy',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onTertiaryContainer,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'We encrypt all study data with AES-256 standards.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    height: 1.5,
                    color: AppColors.onTertiaryContainer.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Decorative shield icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.tertiaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.shield_outlined,
                color: AppColors.tertiary, size: 30),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUCCESS SHEET — placeholder UI that shows after "Complete Sign Up".
// Replace with real navigation once auth is wired.
// ─────────────────────────────────────────────────────────────────────────────

class _SuccessSheet extends StatelessWidget {
  const _SuccessSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.outlineVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 32),

          // Success icon
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: AppColors.primary,
              size: 40,
            ),
          ),
          const SizedBox(height: 20),

          Text(
            "You're all set!",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your account is ready. Start building your\npersonal knowledge base today.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              height: 1.6,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),

          // Go to app CTA (placeholder — navigates back to landing for now)
          AuthPrimaryButton(
            label: 'Start Learning',
            trailingIcon: Icons.auto_stories_rounded,
            onTap: () {
              // Pop all routes back to landing once the user "signs up".
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
