import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../landing_page/app_theme.dart';
import 'services/auth_google_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AUTH SCAFFOLD
// Reused by SignIn, Step1, Step2, Step3.
// Provides: blobs, frosted header bar, scrollable body slot.
// ─────────────────────────────────────────────────────────────────────────────

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.child,
    this.title = 'Create Account',
    this.showBack = true,
    this.trailing,
  });

  final Widget child;
  final String title;
  final bool showBack;

  /// Optional widget in the top-right (e.g. step counter).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Background blobs ─────────────────────────────────────────────
          const Positioned.fill(child: _AuthBlobs()),

          // ── Scrollable page content ──────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _AuthTopBar(
                  title: title,
                  showBack: showBack,
                  trailing: trailing,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(
                      left: 24,
                      right: 24,
                      top: 8,
                      bottom: 40,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: child,
                      ),
                    ),
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
// TOP BAR — frosted glass, back arrow, title, optional trailing slot.
// ─────────────────────────────────────────────────────────────────────────────

class _AuthTopBar extends StatelessWidget {
  const _AuthTopBar({
    required this.title,
    required this.showBack,
    this.trailing,
  });

  final String title;
  final bool showBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFECF5F1).withOpacity(0.78),
            border: Border(
              bottom: BorderSide(
                color: AppColors.outlineVariant.withOpacity(0.14),
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              // Back button
              if (showBack) _BackButton() else const SizedBox(width: 48),

              // Title — centred
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    letterSpacing: -0.2,
                  ),
                ),
              ),

              // Trailing
              SizedBox(
                width: 72,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: trailing ?? const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatefulWidget {
  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        Navigator.of(context).pop();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.outlineVariant.withOpacity(0.5),
              ),
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              size: 18,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP BADGE — "Step X of 3" shown in the trailing slot.
// ─────────────────────────────────────────────────────────────────────────────

class StepBadge extends StatelessWidget {
  const StepBadge({super.key, required this.current, required this.total});
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Text(
        'Step $current of $total',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: AppColors.primary.withOpacity(0.6),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROGRESS BAR — thin animated indicator at the top of multi-step screens.
// ─────────────────────────────────────────────────────────────────────────────

class StepProgressBar extends StatelessWidget {
  const StepProgressBar({
    super.key,
    required this.current,
    required this.total,
  });
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Step label — sits just above the pills, low-key but clear
        Text(
          'Step $current of $total',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: AppColors.primary.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 8),

        // Segmented pill row
        Row(
          children: List.generate(total, (i) {
            final filled = i < current;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: i == 0 ? 0 : 4),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: filled ? 1.0 : 0.0),
                  duration: Duration(milliseconds: 380 + i * 60),
                  curve: Curves.easeOutCubic,
                  builder: (_, t, __) => Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: Color.lerp(
                        AppColors.outlineVariant.withOpacity(0.28),
                        AppColors.primary,
                        t,
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED FORM FIELD — rounded pill/rect input, matching HTML design.
// ─────────────────────────────────────────────────────────────────────────────

class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.label,
    this.prefixIcon,
    this.prefixText,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.onSuffixTap,
    this.helperText,
    this.errorText,
    this.shape = AuthFieldShape.pill,
  });

  final TextEditingController controller;
  final String hint;
  final String? label;
  final IconData? prefixIcon;
  final String? prefixText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final String? helperText;
  final String? errorText;
  final AuthFieldShape shape;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

enum AuthFieldShape { pill, rounded }

class _AuthTextFieldState extends State<AuthTextField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final radius = widget.shape == AuthFieldShape.pill ? 999.0 : 14.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              widget.label!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ],
        Focus(
          onFocusChange: (f) => setState(() => _focused = f),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              boxShadow: _focused
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.10),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: TextField(
              controller: widget.controller,
              keyboardType: widget.keyboardType,
              obscureText: widget.obscureText,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                color: AppColors.onSurface,
              ),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  color: AppColors.outlineVariant,
                ),
                filled: true,
                fillColor: _focused
                    ? AppColors.surfaceContainerLowest
                    : AppColors.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(radius),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(radius),
                  borderSide: BorderSide(
                    // Soft outline so the field is always visible,
                    // but doesn't compete with the focused primary stroke.
                    color: AppColors.outlineVariant.withOpacity(0.55),
                    width: 1.2,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(radius),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.8,
                  ),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal:
                      widget.prefixIcon != null || widget.prefixText != null
                          ? 0
                          : 22,
                  vertical: 18,
                ),
                prefixIcon: widget.prefixIcon != null
                    ? Icon(
                        widget.prefixIcon,
                        size: 20,
                        color: _focused ? AppColors.primary : AppColors.outline,
                      )
                    : widget.prefixText != null
                        ? Padding(
                            padding: const EdgeInsets.only(left: 18, right: 4),
                            child: Text(
                              widget.prefixText!,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 17,
                                color: AppColors.outline,
                              ),
                            ),
                          )
                        : null,
                suffixIcon: widget.suffixIcon != null
                    ? GestureDetector(
                        onTap: widget.onSuffixTap,
                        child: Icon(
                          widget.suffixIcon,
                          size: 20,
                          color: AppColors.outline,
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ),
        if (widget.helperText != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Text(
              widget.helperText!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: AppColors.outline,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GRADIENT PILL BUTTON — primary CTA, reused across all auth screens.
// ─────────────────────────────────────────────────────────────────────────────

class AuthPrimaryButton extends StatefulWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.trailingIcon = Icons.arrow_forward_rounded,
    this.showIcon = true,
  });

  final String label;
  final VoidCallback onTap;
  final IconData trailingIcon;
  final bool showIcon;

  @override
  State<AuthPrimaryButton> createState() => _AuthPrimaryButtonState();
}

class _AuthPrimaryButtonState extends State<AuthPrimaryButton>
    with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 80),
    reverseDuration: const Duration(milliseconds: 200),
  );
  late final _scale = Tween(begin: 1.0, end: 0.96).animate(
    CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, Color(0xFF00513C)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.28),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  softWrap: true,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              if (widget.showIcon) ...[
                const SizedBox(width: 10),
                Icon(widget.trailingIcon, size: 20, color: Colors.white),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GOOGLE BUTTON — used on sign-in and step-3.
// ─────────────────────────────────────────────────────────────────────────────

class GoogleSignInButton extends StatefulWidget {
  const GoogleSignInButton({super.key});

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () async {
          User? user = await AuthService().signInWithGoogle();

          if (user != null) {
            // ignore: avoid_print
            print("Logged in: ${user.displayName}");

            Navigator.pushReplacementNamed(context, '/profile');
          } else {
            // ignore: avoid_print
            print("Login Failed");
          }
        },
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 90),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: _hovered
                  ? AppColors.surfaceContainerLow
                  : AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppColors.outlineVariant.withOpacity(0.5),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CustomPaint(
                    size: const Size(20, 20), painter: _GoogleGPainter()),
                const SizedBox(width: 12),
                Text(
                  'Connect with Google',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the Google "G" logo with four quadrant colours.
class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 * 0.82;
    final rect = Rect.fromCircle(center: c, radius: r);
    final sw = size.width * 0.18;

    void arc(double start, double sweep, Color color) {
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..strokeCap = StrokeCap.butt,
      );
    }

    arc(-1.05, 2.09, const Color(0xFF4285F4)); // blue — right
    arc(-3.14, 2.09, const Color(0xFFEA4335)); // red  — left top
    arc(1.05, 1.05, const Color(0xFF34A853)); // green — bottom right
    arc(2.09, 1.05, const Color(0xFFFBBC05)); // yellow — bottom left

    // Horizontal bar of the G
    canvas.drawLine(
      Offset(c.dx, c.dy),
      Offset(c.dx + r * 0.72, c.dy),
      Paint()
        ..color = const Color(0xFF4285F4)
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.square,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// OR DIVIDER
// ─────────────────────────────────────────────────────────────────────────────

class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
              height: 1, color: AppColors.outlineVariant.withOpacity(0.35)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              color: AppColors.outline,
            ),
          ),
        ),
        Expanded(
          child: Container(
              height: 1, color: AppColors.outlineVariant.withOpacity(0.35)),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WHITE CARD CONTAINER — the glass card on sign-in and step-3.
// ─────────────────────────────────────────────────────────────────────────────

class AuthCard extends StatelessWidget {
  const AuthCard({super.key, required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withOpacity(0.055),
            blurRadius: 48,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INFO BLOB — tertiary/secondary tinted callout boxes.
// ─────────────────────────────────────────────────────────────────────────────

class InfoBlob extends StatelessWidget {
  const InfoBlob({
    super.key,
    required this.icon,
    required this.text,
    this.color,
    this.iconColor,
    this.textColor,
  });

  final IconData icon;
  final String text;
  final Color? color;
  final Color? iconColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: color ?? AppColors.secondaryContainer.withOpacity(0.35),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: iconColor ?? AppColors.secondary,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                height: 1.55,
                color: textColor ?? AppColors.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AUTH BACKGROUND BLOBS — three soft blobs matching the HTML design.
// ─────────────────────────────────────────────────────────────────────────────

class _AuthBlobs extends StatelessWidget {
  const _AuthBlobs();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Align(
            alignment: const Alignment(-1.5, -1.4),
            child: _Blob(380, AppColors.primaryContainer.withOpacity(0.35)),
          ),
          Align(
            alignment: const Alignment(1.6, 1.5),
            child: _Blob(460, AppColors.secondaryContainer.withOpacity(0.35)),
          ),
          Align(
            alignment: const Alignment(1.1, -0.1),
            child: _Blob(280, AppColors.tertiaryContainer.withOpacity(0.28)),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob(this.size, this.color);
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 72, sigmaY: 72),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
