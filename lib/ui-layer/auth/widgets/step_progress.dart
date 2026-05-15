import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../landing_page/app_theme.dart';

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
