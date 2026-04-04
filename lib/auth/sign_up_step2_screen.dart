import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../landing_page/app_theme.dart';
import '../main.dart';
import 'auth_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SIGN UP — STEP 2: DEMOGRAPHICS
// Age (slider + number input) + Nationality (dropdown).
// ─────────────────────────────────────────────────────────────────────────────

class SignUpStep2Screen extends StatelessWidget {
  const SignUpStep2Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Create Account',
      showBack: true,
      trailing: const StepBadge(current: 2, total: 3),
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
  String? _country;

  static const List<_Country> _countries = [
    _Country('us', '🇺🇸', 'United States'),
    _Country('gb', '🇬🇧', 'United Kingdom'),
    _Country('ca', '🇨🇦', 'Canada'),
    _Country('au', '🇦🇺', 'Australia'),
    _Country('de', '🇩🇪', 'Germany'),
    _Country('fr', '🇫🇷', 'France'),
    _Country('jp', '🇯🇵', 'Japan'),
    _Country('ph', '🇵🇭', 'Philippines'),
    _Country('in', '🇮🇳', 'India'),
    _Country('br', '🇧🇷', 'Brazil'),
    _Country('other', '🌍', 'Other'),
  ];

  @override
  Widget build(BuildContext context) {
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
          'We use this to personalise your learning journey and suggest '
          'relevant study sets.',
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Age section
              _SectionLabel(icon: Icons.cake_outlined, label: 'Your Age'),
              const SizedBox(height: 16),
              _AgeRow(age: _age, onChanged: (v) => setState(() => _age = v)),
              const SizedBox(height: 8),
              _AgeSlider(
                age: _age,
                onChanged: (v) => setState(() => _age = v),
              ),
              const SizedBox(height: 8),
              // Age range note
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _AgeTag(
                    label: 'Restricted',
                    color: const Color(0xFFBA1A1A).withOpacity(0.12),
                    textColor: const Color(0xFFBA1A1A),
                    dot: const Color(0xFFBA1A1A),
                  ),
                  _AgeTag(
                    label: 'Allowed',
                    color: AppColors.primaryContainer.withOpacity(0.3),
                    textColor: AppColors.primary,
                    dot: AppColors.primary,
                    dotRight: true,
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Nationality section
              _SectionLabel(
                  icon: Icons.public_rounded, label: 'Nationality'),
              const SizedBox(height: 16),
              _CountryDropdown(
                selected: _country,
                countries: _countries,
                onChanged: (v) => setState(() => _country = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Tip blob ──────────────────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.tertiaryContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lightbulb_outline_rounded,
                  color: AppColors.onTertiaryContainer, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '"Sharing your demographics helps us match you with study '
                  'groups in your timezone and academic level."',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    height: 1.6,
                    fontStyle: FontStyle.italic,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 36),

        // ── Continue CTA ──────────────────────────────────────────────────
        AuthPrimaryButton(
          label: 'Continue to Final Step',
          onTap: () => Navigator.of(context).pushNamed(AppRoutes.signUp3),
        ),
        const SizedBox(height: 16),

        // ── Skip ──────────────────────────────────────────────────────────
        Center(
          child: GestureDetector(
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.signUp3),
            child: Text(
              'Skip for now',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.outline,
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUB-WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            color: AppColors.outline,
          ),
        ),
      ],
    );
  }
}

class _AgeRow extends StatelessWidget {
  const _AgeRow({required this.age, required this.onChanged});
  final double age;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'How old are you?',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AppColors.outlineVariant.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Text(
                age.round().toString(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'yrs',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AgeSlider extends StatelessWidget {
  const _AgeSlider({required this.age, required this.onChanged});
  final double age;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: AppColors.outlineVariant.withOpacity(0.3),
        thumbColor: AppColors.primary,
        overlayColor: AppColors.primary.withOpacity(0.12),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
        trackHeight: 4,
      ),
      child: Slider(
        value: age,
        min: 13,
        max: 80,
        onChanged: onChanged,
      ),
    );
  }
}

class _AgeTag extends StatelessWidget {
  const _AgeTag({
    required this.label,
    required this.color,
    required this.textColor,
    required this.dot,
    this.dotRight = false,
  });

  final String label;
  final Color color;
  final Color textColor;
  final Color dot;
  final bool dotRight;

  @override
  Widget build(BuildContext context) {
    final dotWidget = Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: dotRight
            ? [
                Text(label, style: _style(textColor)),
                const SizedBox(width: 5),
                dotWidget,
              ]
            : [
                dotWidget,
                const SizedBox(width: 5),
                Text(label, style: _style(textColor)),
              ],
      ),
    );
  }

  TextStyle _style(Color c) => GoogleFonts.plusJakartaSans(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: c,
        letterSpacing: 0.3,
      );
}

class _Country {
  const _Country(this.code, this.flag, this.name);
  final String code;
  final String flag;
  final String name;
}

class _CountryDropdown extends StatelessWidget {
  const _CountryDropdown({
    required this.selected,
    required this.countries,
    required this.onChanged,
  });
  final String? selected;
  final List<_Country> countries;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected,
          hint: Text(
            'Select your country',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              color: AppColors.outlineVariant,
            ),
          ),
          icon: const Icon(Icons.expand_more_rounded,
              color: AppColors.outline, size: 22),
          isExpanded: true,
          dropdownColor: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            color: AppColors.onSurface,
          ),
          items: countries
              .map(
                (c) => DropdownMenuItem(
                  value: c.code,
                  child: Row(
                    children: [
                      Text(c.flag, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 12),
                      Text(c.name),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
