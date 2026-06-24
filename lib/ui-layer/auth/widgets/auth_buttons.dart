import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../landing_page/app_theme.dart';
import '../../../business-layer/services/auth_google_service.dart';

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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GOOGLE BUTTON — used on sign-in and step-3.
// ─────────────────────────────────────────────────────────────────────────────

class GoogleSignInButton extends StatefulWidget {
  const GoogleSignInButton({super.key, this.onTap});

  /// If provided, called instead of the default sign-in + navigate-to-home
  /// flow. Useful for custom post-auth logic (e.g. merging step data during
  /// multi-step sign-up).
  final VoidCallback? onTap;

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () async {
          if (widget.onTap != null) {
            widget.onTap!();
            return;
          }
          // Default behaviour — used on the sign-in screen.
          User? user = await AuthService().signInWithGoogle();
          if (user != null) {
            // ignore: avoid_print
            print("Logged in: ${user.displayName}");
            if (context.mounted) {
              Navigator.pushReplacementNamed(context, '/home');
            }
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

/// Paints the official Google "G" logo — traced directly from Google's own
/// four-path brand asset (the one used in their "Sign in with Google"
/// button guidelines), not an approximation built out of arcs.
class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // The source asset uses a 24x24 viewBox, so we scale the canvas to
    // match it and then draw in those exact coordinates.
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);

    final bluePaint = Paint()..color = const Color(0xFF4285F4);
    final greenPaint = Paint()..color = const Color(0xFF34A853);
    final yellowPaint = Paint()..color = const Color(0xFFFBBC05);
    final redPaint = Paint()..color = const Color(0xFFEA4335);

    // Blue — the right-hand lobe, including the crossbar of the "G".
    final blue = Path()
      ..moveTo(22.56, 12.25)
      ..relativeCubicTo(0, -0.78, -0.07, -1.53, -0.2, -2.25)
      ..lineTo(12, 10.00)
      ..relativeLineTo(0, 4.26)
      ..relativeLineTo(5.92, 0)
      ..relativeCubicTo(-0.26, 1.37, -1.04, 2.53, -2.21, 3.31)
      ..relativeLineTo(0, 2.77)
      ..relativeLineTo(3.57, 0)
      ..relativeCubicTo(2.08, -1.92, 3.28, -4.74, 3.28, -8.09)
      ..close();
    canvas.drawPath(blue, bluePaint);

    // Green — the bottom lobe.
    final green = Path()
      ..moveTo(12, 23)
      ..relativeCubicTo(2.97, 0, 5.46, -0.98, 7.28, -2.66)
      ..relativeLineTo(-3.57, -2.77)
      ..relativeCubicTo(-0.98, 0.66, -2.23, 1.06, -3.71, 1.06)
      ..relativeCubicTo(-2.86, 0, -5.29, -1.93, -6.16, -4.53)
      ..lineTo(2.18, 14.10)
      ..relativeLineTo(0, 2.84)
      ..cubicTo(3.99, 20.53, 7.7, 23, 12, 23)
      ..close();
    canvas.drawPath(green, greenPaint);

    // Yellow — the left lobe.
    final yellow = Path()
      ..moveTo(5.84, 14.09)
      ..relativeCubicTo(-0.22, -0.66, -0.35, -1.36, -0.35, -2.09)
      ..cubicTo(5.49, 11.27, 5.62, 10.57, 5.84, 9.91)
      ..lineTo(5.84, 7.07)
      ..lineTo(2.18, 7.07)
      ..cubicTo(1.43, 8.55, 1, 10.22, 1, 12)
      ..cubicTo(1, 13.78, 1.43, 15.45, 2.18, 16.93)
      ..relativeLineTo(2.85, -2.22)
      ..relativeLineTo(0.81, -0.62)
      ..close();
    canvas.drawPath(yellow, yellowPaint);

    // Red — the top lobe.
    final red = Path()
      ..moveTo(12, 5.38)
      ..relativeCubicTo(1.62, 0, 3.06, 0.56, 4.21, 1.64)
      ..relativeLineTo(3.15, -3.15)
      ..cubicTo(17.45, 2.09, 14.97, 1, 12, 1)
      ..cubicTo(7.7, 1, 3.99, 3.47, 2.18, 7.07)
      ..relativeLineTo(3.66, 2.84)
      ..relativeCubicTo(0.87, -2.6, 3.3, -4.53, 6.16, -4.53)
      ..close();
    canvas.drawPath(red, redPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
