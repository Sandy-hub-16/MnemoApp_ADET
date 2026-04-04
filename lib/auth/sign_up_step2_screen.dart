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
          'We use this to personalise your learning journey and suggest relevant study sets.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            height: 1.6,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 28),

        // ── Age picker card ───────────────────────────────────────────────
        _AgeCard(
          age: _age,
          onChanged: (v) => setState(() => _age = v),
        ),
        const SizedBox(height: 16),

        // ── Nationality card ──────────────────────────────────────────────
        _NationalityCard(
          selected: _country,
          countries: _countries,
          onChanged: (v) => setState(() => _country = v),
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
// AGE PICKER CARD
// Large centred number + decrement/increment buttons + slim slider.
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
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
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
            'Your Age',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              color: AppColors.onSurfaceVariant.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 20),

          // Number + stepper row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Decrement
              _StepperButton(
                icon: Icons.remove_rounded,
                onTap: ageInt > 13
                    ? () => onChanged((ageInt - 1).toDouble())
                    : null,
              ),

              // Large age number
              Column(
                children: [
                  ShaderMask(
                    shaderCallback: (b) => const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primary, AppColors.primaryFixedDim],
                    ).createShader(b),
                    child: Text(
                      '$ageInt',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 72,
                        fontWeight: FontWeight.w800,
                        height: 1,
                        color: Colors.white, // masked by shader
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'years old',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.onSurfaceVariant.withOpacity(0.5),
                    ),
                  ),
                ],
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
          const SizedBox(height: 20),

          // Slim slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: AppColors.outlineVariant.withOpacity(0.25),
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withOpacity(0.10),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              trackHeight: 3,
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
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
          width: 48,
          height: 48,
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
            size: 22,
            color: enabled ? AppColors.primary : AppColors.outlineVariant,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NATIONALITY CARD
// ─────────────────────────────────────────────────────────────────────────────

class _NationalityCard extends StatelessWidget {
  const _NationalityCard({
    required this.selected,
    required this.countries,
    required this.onChanged,
  });
  final String? selected;
  final List<_Country> countries;
  final ValueChanged<String?> onChanged;

  _Country? get _selectedCountry =>
      selected == null ? null : countries.firstWhere((c) => c.code == selected);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
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
            'Nationality',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              color: AppColors.onSurfaceVariant.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Where are you from?',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 18),

          // Dropdown
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.outlineVariant.withOpacity(0.4),
              ),
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
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppColors.outline, size: 22),
                isExpanded: true,
                dropdownColor: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  color: AppColors.onSurface,
                ),
                items: countries
                    .map(
                      (c) => DropdownMenuItem(
                        value: c.code,
                        child: Row(children: [
                          Text(c.flag, style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 12),
                          Text(c.name),
                        ]),
                      ),
                    )
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          ),

          // Subtle flag preview when a country is selected
          if (_selectedCountry != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  _selectedCountry!.flag,
                  style: const TextStyle(fontSize: 22),
                ),
                const SizedBox(width: 10),
                Text(
                  _selectedCountry!.name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.check_circle_rounded,
                    size: 14, color: AppColors.primary),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Country {
  const _Country(this.code, this.flag, this.name);
  final String code;
  final String flag;
  final String name;
}
