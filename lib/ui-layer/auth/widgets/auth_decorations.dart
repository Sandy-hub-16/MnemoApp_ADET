import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../landing_page/app_theme.dart';

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
