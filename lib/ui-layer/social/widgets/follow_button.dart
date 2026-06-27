import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../landing_page/app_theme.dart';
import '../../widgets/app_spinner.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FOLLOW BUTTON
//
// Stateless widget that renders a Follow / Following toggle button.
//
//   isFollowing == false  →  outlined "Follow" button
//   isFollowing == true   →  filled primary "Following" button
//   isLoading == true     →  button is disabled and shows a small spinner
//
// The caller is responsible for all state management; this widget is purely
// presentational.
//
// Requirements: 4.5, 4.6
// ─────────────────────────────────────────────────────────────────────────────

class FollowButton extends StatelessWidget {
  const FollowButton({
    super.key,
    required this.isFollowing,
    required this.isLoading,
    required this.onPressed,
  });

  final bool isFollowing;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    // Disable the button while a follow/unfollow operation is in progress
    final effectiveOnPressed = isLoading ? null : onPressed;

    if (isFollowing) {
      // ── "Following" — filled primary button ──────────────────────────
      return ElevatedButton(
        onPressed: effectiveOnPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
          disabledForegroundColor: AppColors.onPrimary.withValues(alpha: 0.6),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        child: _ButtonContent(
          isLoading: isLoading,
          label: 'Following',
          icon: Icons.check_rounded,
        ),
      );
    }

    // ── "Follow" — outlined button ──────────────────────────────────────
    return OutlinedButton(
      onPressed: effectiveOnPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        disabledForegroundColor: AppColors.outline.withValues(alpha: 0.5),
        side: BorderSide(
          color: isLoading
              ? AppColors.outline.withValues(alpha: 0.3)
              : AppColors.primary,
          width: 1.5,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      child: _ButtonContent(
        isLoading: isLoading,
        label: 'Follow',
        icon: Icons.person_add_rounded,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BUTTON CONTENT
//
// Internal helper that renders either a spinner (while loading) or an icon +
// label pair. Keeps the two button variants DRY.
// ─────────────────────────────────────────────────────────────────────────────

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({
    required this.isLoading,
    required this.label,
    required this.icon,
  });

  final bool isLoading;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: AppSpinnerSmall(),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
