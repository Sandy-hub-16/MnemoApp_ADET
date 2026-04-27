import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../landing_page/app_theme.dart';
import '../../../main.dart';
import '../widgets_design.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SIGN UP — STEP 2: DEMOGRAPHICS
// Age (compact slider + stepper) + Education Level (selectable tiles).
// Country defaults to Philippines (ph) and is passed silently.
// ─────────────────────────────────────────────────────────────────────────────

class SignUpStep2Screen extends StatelessWidget {
  const SignUpStep2Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Create Account',
      showBack: true,
      child: const _Step2Body(),
    );
  }
}

class _Step2Body extends StatefulWidget {
  const _Step2Body();

  @override
  State<_Step2Body> createState() => _Step2BodyState();
}

class _Step2BodyState extends State<_Step2Body> {
  double _age = 21;
  String? _education;
  bool _showEducationError = false;

  static const List<_EducationLevel> _educationLevels = [
    _EducationLevel(
      key: 'elementary',
      icon: Icons.child_care_rounded,
      label: 'Elementary',
      sublabel: 'Grades 1 – 6',
    ),
    _EducationLevel(
      key: 'highschool',
      icon: Icons.school_rounded,
      label: 'Junior High School',
      sublabel: 'Grades 7 – 10',
    ),
    _EducationLevel(
      key: 'senior_highschool',
      icon: Icons.auto_stories_rounded,
      label: 'Senior High School',
      sublabel: 'Grades 11 – 12 or Tech-Voc',
    ),
    _EducationLevel(
      key: 'undergraduate',
      icon: Icons.account_balance_rounded,
      label: 'College Undergraduate',
      sublabel: 'Undergraduate or associate',
    ),
    _EducationLevel(
      key: 'graduate_working',
      icon: Icons.work_rounded,
      label: 'College Graduate & Working Professional',
      sublabel: 'Graduate or working',
    ),
  ];

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
        const StepProgressBar(current: 2, total: 3),
        const SizedBox(height: 36),

        // ── Section header ────────────────────────────────────────────────
        Text(
          'Tell us about yourself',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'We use this to personalise your learning journey and suggest relevant study sets.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            height: 1.6,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 28),

        // ── Compact age picker ────────────────────────────────────────────
        _AgeCard(
          age: _age,
          onChanged: (v) => setState(() => _age = v),
        ),
        const SizedBox(height: 16),

        // ── Education level dropdown ──────────────────────────────────────
        _EducationDropdown(
          selected: _education,
          levels: _educationLevels,
          hasError: _showEducationError,
          onChanged: (v) => setState(() {
            _education = v;
            _showEducationError = false;
          }),
        ),
        const SizedBox(height: 36),

        // ── Continue CTA ──────────────────────────────────────────────────
        AuthPrimaryButton(
          label: 'Continue to Final Step',
          onTap: () {
            if (_education == null) {
              setState(() => _showEducationError = true);
              return;
            }
            Navigator.of(context).pushNamed(
              AppRoutes.signUp3,
              arguments: Map<String, dynamic>.from({
                ...args,
                'age': _age.toInt(),
                'education': _education!,
                'country': 'ph',
              }),
            );
          },
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AGE PICKER CARD — compact horizontal layout.
// Smaller number (44 px vs original 72 px) with tighter padding.
// ─────────────────────────────────────────────────────────────────────────────

class _AgeCard extends StatelessWidget {
  const _AgeCard({required this.age, required this.onChanged});
  final double age;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final ageInt = age.round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withOpacity(0.05),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          Text(
            'YOUR AGE',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppColors.onSurfaceVariant.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 10),

          // Number + stepper row — all inline, compact
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Decrement
              _StepperButton(
                icon: Icons.remove_rounded,
                onTap: ageInt > 13
                    ? () => onChanged((ageInt - 1).toDouble())
                    : null,
              ),

              // Age number (smaller: 44 px)
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ShaderMask(
                      shaderCallback: (b) => const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primary, AppColors.primaryFixedDim],
                      ).createShader(b),
                      child: Text(
                        '$ageInt',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 44,
                          fontWeight: FontWeight.w800,
                          height: 1,
                          color: Colors.white, // masked by shader
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'years old',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.onSurfaceVariant.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),

              // Increment
              _StepperButton(
                icon: Icons.add_rounded,
                onTap: ageInt < 80
                    ? () => onChanged((ageInt + 1).toDouble())
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Slim slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: AppColors.outlineVariant.withOpacity(0.25),
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withOpacity(0.10),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
              trackHeight: 3,
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
            ),
            child: Slider(
              value: age,
              min: 13,
              max: 80,
              onChanged: onChanged,
            ),
          ),

          // Min / Max labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '13',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    color: AppColors.outlineVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '80',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    color: AppColors.outlineVariant,
                    fontWeight: FontWeight.w600,
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

class _StepperButton extends StatefulWidget {
  const _StepperButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  State<_StepperButton> createState() => _StepperButtonState();
}

class _StepperButtonState extends State<_StepperButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap!();
            }
          : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: enabled
                ? AppColors.primaryContainer.withOpacity(0.25)
                : AppColors.surfaceContainerLow,
            shape: BoxShape.circle,
            border: Border.all(
              color: enabled
                  ? AppColors.primary.withOpacity(0.18)
                  : AppColors.outlineVariant.withOpacity(0.2),
            ),
          ),
          child: Icon(
            widget.icon,
            size: 20,
            color: enabled ? AppColors.primary : AppColors.outlineVariant,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EDUCATION DROPDOWN — tap to open a bottom-sheet picker.
// Shows the selected level inline; validates that a choice was made.
// ─────────────────────────────────────────────────────────────────────────────

class _EducationDropdown extends StatefulWidget {
  const _EducationDropdown({
    required this.selected,
    required this.levels,
    required this.hasError,
    required this.onChanged,
  });
  final String? selected;
  final List<_EducationLevel> levels;
  final bool hasError;
  final ValueChanged<String> onChanged;

  @override
  State<_EducationDropdown> createState() => _EducationDropdownState();
}

class _EducationDropdownState extends State<_EducationDropdown> {
  bool _pressed = false;

  _EducationLevel? get _selectedLevel => widget.selected == null
      ? null
      : widget.levels.firstWhere((l) => l.key == widget.selected);

  void _openSheet() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _EducationBottomSheet(
        levels: widget.levels,
        selected: widget.selected,
      ),
    );
    if (result != null) widget.onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final sel = _selectedLevel;
    final hasError = widget.hasError;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: hasError
              ? Colors.red.withOpacity(0.55)
              : AppColors.outlineVariant.withOpacity(0.18),
          width: hasError ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withOpacity(0.05),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label row
          Text(
            'EDUCATION LEVEL',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: hasError
                  ? Colors.red.withOpacity(0.7)
                  : AppColors.onSurfaceVariant.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'What is your educational background?',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 14),

          // Tappable selector field
          GestureDetector(
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) {
              setState(() => _pressed = false);
              _openSheet();
            },
            onTapCancel: () => setState(() => _pressed = false),
            child: AnimatedScale(
              scale: _pressed ? 0.98 : 1.0,
              duration: const Duration(milliseconds: 90),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: sel != null
                      ? AppColors.primary.withOpacity(0.07)
                      : AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: hasError
                        ? Colors.red.withOpacity(0.4)
                        : sel != null
                            ? AppColors.primary.withOpacity(0.45)
                            : AppColors.outlineVariant.withOpacity(0.28),
                    width: sel != null ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    // Icon badge
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: sel != null
                            ? AppColors.primary.withOpacity(0.14)
                            : AppColors.outlineVariant.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        sel?.icon ?? Icons.school_outlined,
                        size: 18,
                        color: sel != null
                            ? AppColors.primary
                            : AppColors.onSurfaceVariant.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Label or placeholder
                    Expanded(
                      child: sel != null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  sel.label,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  sel.sublabel,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.primary.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              'Select your education level',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: hasError
                                    ? Colors.red.withOpacity(0.7)
                                    : AppColors.onSurfaceVariant
                                        .withOpacity(0.45),
                              ),
                            ),
                    ),

                    // Chevron
                    Icon(
                      Icons.expand_less_rounded,
                      size: 20,
                      color: sel != null
                          ? AppColors.primary
                          : AppColors.onSurfaceVariant.withOpacity(0.4),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Error hint
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: hasError
                ? Padding(
                    padding: const EdgeInsets.only(top: 8, left: 4),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline_rounded,
                            size: 13, color: Colors.red.withOpacity(0.8)),
                        const SizedBox(width: 5),
                        Text(
                          'Please select your education level to continue.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.red.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EDUCATION BOTTOM SHEET — slides up with the list of options.
// ─────────────────────────────────────────────────────────────────────────────

class _EducationBottomSheet extends StatelessWidget {
  const _EducationBottomSheet({
    required this.levels,
    required this.selected,
  });
  final List<_EducationLevel> levels;
  final String? selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withOpacity(0.10),
            blurRadius: 48,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outlineVariant.withOpacity(0.45),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 6),
            child: Row(
              children: [
                Text(
                  'Education Level',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: AppColors.onSurface,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppColors.outlineVariant.withOpacity(0.35)),
                    ),
                    child: const Icon(Icons.close_rounded,
                        size: 16, color: AppColors.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Options list
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: levels.asMap().entries.map((entry) {
                final level = entry.value;
                final isSelected = selected == level.key;
                final isLast = entry.key == levels.length - 1;

                return Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
                  child: _SheetTile(
                    level: level,
                    isSelected: isSelected,
                    onTap: () => Navigator.of(context).pop(level.key),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetTile extends StatefulWidget {
  const _SheetTile({
    required this.level,
    required this.isSelected,
    required this.onTap,
  });
  final _EducationLevel level;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_SheetTile> createState() => _SheetTileState();
}

class _SheetTileState extends State<_SheetTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final sel = widget.isSelected;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: sel
                ? AppColors.primary.withOpacity(0.07)
                : AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: sel
                  ? AppColors.primary.withOpacity(0.45)
                  : AppColors.outlineVariant.withOpacity(0.28),
              width: sel ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: sel
                      ? AppColors.primary.withOpacity(0.14)
                      : AppColors.outlineVariant.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  widget.level.icon,
                  size: 18,
                  color: sel
                      ? AppColors.primary
                      : AppColors.onSurfaceVariant.withOpacity(0.7),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.level.label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                        color: sel ? AppColors.primary : AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      widget.level.sublabel,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: sel
                            ? AppColors.primary.withOpacity(0.6)
                            : AppColors.onSurfaceVariant.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedOpacity(
                opacity: sel ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 180),
                child: const Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────────────────────────────────────

class _EducationLevel {
  const _EducationLevel({
    required this.key,
    required this.icon,
    required this.label,
    required this.sublabel,
  });
  final String key;
  final IconData icon;
  final String label;
  final String sublabel;
}

