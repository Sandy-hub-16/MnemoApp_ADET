import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../landing_page/app_theme.dart';
import '../main.dart';
import 'services/auth_google_service.dart';
import 'widgets_design.dart';

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
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 24),

        // ── Branding block ────────────────────────────────────────────────
        const _SignInBranding(),
        const SizedBox(height: 32),

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

              // Sign In CTA — UI only
              AuthPrimaryButton(
                label: 'Sign In',
                showIcon: false,
                onTap: () async {
                  String email = _emailCtrl.text.trim();
                  String password = _passwordCtrl.text.trim();


                  if (email.isEmpty || password.isEmpty) {
                    print("Please fill all fields");
                    return;
                  }

                  var user = await AuthService().login(email, password);

                  if (user != null) {
                    print("Logged in: ${user.email}");

                    //  CHECK EMAIL VERIFICATION HERE
                    if (!user.emailVerified) {
                      await FirebaseAuth.instance.signOut();

                      Navigator.pushNamed(context, '/verify-email');
                      return;
                    }

                    //  VERIFIED → go to profile
                    Navigator.pushReplacementNamed(context, '/profile');

                  } else {
                    print("Login Failed");
                  }
                },
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
// SUB-WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _SignInBranding extends StatelessWidget {
  const _SignInBranding();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Rotated icon badge
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
