import 'package:flutter/material.dart';
import '../landing_page/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// APP SPINNER — single source of truth for all loading indicators.
//
// Use [AppSpinner] for full-screen / centred loading states.
// Use [AppSpinnerSmall] for inline / button-sized loading states.
//
// Both variants use AppColors.primary and a consistent stroke weight so the
// app looks cohesive across every screen.
// ─────────────────────────────────────────────────────────────────────────────

/// Standard loading spinner for full-screen and section-level loading states.
///
/// Wraps [CircularProgressIndicator] with a fixed size (36 dp) and the app's
/// primary brand colour.  Drop it inside a [Center] at the call-site.
///
/// ```dart
/// // Full-screen page load
/// body: const Center(child: AppSpinner()),
///
/// // Conditional — swap with content when ready
/// _loading ? const Center(child: AppSpinner()) : _buildContent(),
/// ```
class AppSpinner extends StatelessWidget {
  const AppSpinner({super.key, this.color});

  /// Override colour only when the spinner appears on a coloured/dark surface.
  /// Defaults to [AppColors.primary].
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: CircularProgressIndicator(
        strokeWidth: 3,
        color: color ?? AppColors.primary,
        strokeCap: StrokeCap.round,
      ),
    );
  }
}

/// Small inline spinner for use inside buttons, tiles, and compact UI.
///
/// Fixed at 18 × 18 dp with a thinner stroke to suit tight spaces such as
/// follow buttons, toggle rows, and action chips.
///
/// ```dart
/// // Inside a button child
/// isLoading
///   ? const AppSpinnerSmall()
///   : const Text('Save')
/// ```
class AppSpinnerSmall extends StatelessWidget {
  const AppSpinnerSmall({super.key, this.color});

  /// Override colour for small spinners on dark/coloured backgrounds.
  /// Defaults to [AppColors.primary].
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: color ?? AppColors.primary,
        strokeCap: StrokeCap.round,
      ),
    );
  }
}
