import 'dart:ui';
import 'package:flutter/material.dart';
import 'landing_data.dart';
import 'app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LANDING SCREEN
// The single screen that composes every section.
// ─────────────────────────────────────────────────────────────────────────────

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const _BackgroundBlobs(),
          CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 88)),
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1280),
                    child: const Column(
                      children: [
                        _HeroSection(),
                        _FeaturesSection(),
                      ],
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: _FooterSection()),
            ],
          ),
          // Glass nav always on top
          const Positioned(top: 0, left: 0, right: 0, child: _NavBar()),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NAV BAR
// ─────────────────────────────────────────────────────────────────────────────

class _NavBar extends StatelessWidget {
  const _NavBar();

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow.withOpacity(0.82),
            border: Border(
              bottom: BorderSide(
                  color: AppColors.outlineVariant.withOpacity(0.12)),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Brand logo
                  ShaderMask(
                    shaderCallback: (b) => const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryFixedDim],
                    ).createShader(b),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_stories,
                            color: Colors.white, size: 24),
                        const SizedBox(width: 8),
                        Text('MnemoApp',
                            style: AppTextStyles.navBrand
                                .copyWith(color: Colors.white)),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      // "Features" link — desktop only
                      if (MediaQuery.sizeOf(context).width >= 768)
                        Padding(
                          padding: const EdgeInsets.only(right: 24),
                          child: Text('Features',
                              style: AppTextStyles.labelCaps
                                  .copyWith(color: AppColors.primary)),
                        ),
                      _PillButton(
                        label: 'Sign In',
                        onTap: () {},
                        small: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO SECTION
// ─────────────────────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1024;
    final padding = EdgeInsets.symmetric(
      horizontal: wide ? 48 : 24,
      vertical: wide ? 96 : 48,
    );

    final copy = _HeroCopy(wide: wide);
    const visual = _HeroVisual();

    return Padding(
      padding: padding,
      child: wide
          ? IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: copy),
                  const SizedBox(width: 64),
                  const Expanded(child: visual),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [copy, const SizedBox(height: 48), visual],
            ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({required this.wide});
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // "Available Now" badge
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer.withOpacity(0.30),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.rocket_launch_outlined,
                  color: AppColors.primary, size: 16),
              const SizedBox(width: 8),
              Text('Available Now',
                  style: AppTextStyles.labelCaps
                      .copyWith(color: AppColors.primary)),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Headline — gradient on "breakthrough"
        Text.rich(
          TextSpan(
            style: AppTextStyles.heroDisplay(mobile: !wide),
            children: [
              const TextSpan(text: heroHeadlinePrefix),
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: ShaderMask(
                  shaderCallback: (b) => const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryFixedDim],
                  ).createShader(b),
                  child: Text(
                    heroHeadlineHighlight,
                    style: AppTextStyles.heroDisplay(mobile: !wide)
                        .copyWith(color: Colors.white),
                  ),
                ),
              ),
              const TextSpan(text: heroHeadlineSuffix),
            ],
          ),
        ),
        const SizedBox(height: 24),

        Text(heroBody,
            style: wide ? AppTextStyles.bodyLarge : AppTextStyles.bodyBase),
        const SizedBox(height: 40),

        // CTA buttons
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _PillButton(label: 'Get Started for Free', onTap: () {}),
            _OutlineButton(label: 'How it works', onTap: () {}),
          ],
        ),
        const SizedBox(height: 40),

        // Social proof
        Row(
          children: [
            const _AvatarStack(avatars: socialProofAvatars),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(socialProofLabel,
                    style: AppTextStyles.bodyBase.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w700)),
                Text(socialProofSub, style: AppTextStyles.bodyBase),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _HeroVisual extends StatefulWidget {
  const _HeroVisual();

  @override
  State<_HeroVisual> createState() => _HeroVisualState();
}

class _HeroVisualState extends State<_HeroVisual>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700));

  late final Animation<double> _tilt =
      Tween(begin: 0.017, end: 0.0).animate(
          CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _ctrl.forward(),
      onExit: (_) => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _tilt,
        builder: (_, child) =>
            Transform.rotate(angle: _tilt.value, child: child),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // White photo card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.12),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(heroImageUrl,
                    height: 440, width: double.infinity, fit: BoxFit.cover),
              ),
            ),
            // Floating chip
            Positioned(
              bottom: -28,
              right: -28,
              child: Transform.rotate(
                angle: -0.052,
                child: Container(
                  width: 215,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.tertiaryContainer,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.quiz_outlined,
                            color: AppColors.tertiary, size: 18),
                        const SizedBox(width: 8),
                        Text('Active Challenge',
                            style: AppTextStyles.bodyBase.copyWith(
                                color: AppColors.onTertiaryContainer,
                                fontWeight: FontWeight.w800,
                                fontSize: 13)),
                      ]),
                      const SizedBox(height: 6),
                      Text(
                        'Ready for your daily breakthrough? Start your session now.',
                        style: AppTextStyles.bodyBase.copyWith(
                            color: AppColors.onTertiaryContainer
                                .withOpacity(0.8),
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FEATURES SECTION
// ─────────────────────────────────────────────────────────────────────────────

class _FeaturesSection extends StatelessWidget {
  const _FeaturesSection();

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 768;

    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: wide ? 48 : 24, vertical: 96),
      child: Column(
        children: [
          // Header
          Text(featuresHeading,
              style: AppTextStyles.sectionHeading,
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Text(featuresSubheading,
                style: AppTextStyles.bodyLarge,
                textAlign: TextAlign.center),
          ),
          const SizedBox(height: 64),

          // Card grid
          wide ? const _WideGrid() : const _NarrowList(),
        ],
      ),
    );
  }
}

class _WideGrid extends StatelessWidget {
  const _WideGrid();

  @override
  Widget build(BuildContext context) {
    const gap = 28.0;
    return Column(
      children: [
        // Row 1: wide + narrow
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(flex: 2, child: _FeatureCard(item: features[0])),
            const SizedBox(width: gap),
            Expanded(flex: 1, child: _FeatureCard(item: features[1])),
          ]),
        ),
        const SizedBox(height: gap),
        // Row 2: narrow + wide
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(flex: 1, child: _FeatureCard(item: features[2])),
            const SizedBox(width: gap),
            Expanded(flex: 2, child: _FeatureCard(item: features[3])),
          ]),
        ),
      ],
    );
  }
}

class _NarrowList extends StatelessWidget {
  const _NarrowList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < features.length; i++) ...[
          _FeatureCard(item: features[i]),
          if (i < features.length - 1) const SizedBox(height: 20),
        ],
      ],
    );
  }
}

class _FeatureCard extends StatefulWidget {
  const _FeatureCard({required this.item});
  final FeatureItem item;

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _hovered = false;

  // Returns colors based on variant
  ({Color bg, Color border, Color iconBg, Color iconColor, Color title, Color body})
      get _tokens {
    switch (widget.item.variant) {
      case CardVariant.narrowAccentTertiary:
        return (
          bg: AppColors.tertiaryContainer.withOpacity(0.22),
          border: AppColors.tertiaryContainer.withOpacity(0.35),
          iconBg: AppColors.tertiaryContainer,
          iconColor: AppColors.tertiary,
          title: AppColors.onTertiaryContainer,
          body: AppColors.onTertiaryContainer.withOpacity(0.8),
        );
      case CardVariant.narrowAccentSecondary:
        return (
          bg: AppColors.secondaryContainer.withOpacity(0.22),
          border: AppColors.secondaryContainer.withOpacity(0.35),
          iconBg: AppColors.secondaryContainer,
          iconColor: AppColors.secondary,
          title: AppColors.onSecondaryContainer,
          body: AppColors.onSecondaryContainer.withOpacity(0.8),
        );
      default:
        return (
          bg: AppColors.surfaceContainerLowest,
          border: AppColors.outlineVariant.withOpacity(0.12),
          iconBg: AppColors.primaryContainer.withOpacity(0.5),
          iconColor: AppColors.primary,
          title: AppColors.onSurface,
          body: AppColors.onSurfaceVariant,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _tokens;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(
          color: t.bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: t.border),
          boxShadow: [
            if (widget.item.variant == CardVariant.wideWithImage ||
                widget.item.variant == CardVariant.wideWithSkeleton)
              BoxShadow(
                color: AppColors.primary.withOpacity(0.07),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon badge
            Container(
              width: 52,
              height: 52,
              decoration:
                  BoxDecoration(color: t.iconBg, shape: BoxShape.circle),
              child: Icon(widget.item.icon, color: t.iconColor, size: 26),
            ),
            const SizedBox(height: 16),
            Text(widget.item.title,
                style:
                    AppTextStyles.cardHeading.copyWith(color: t.title)),
            const SizedBox(height: 12),
            Text(widget.item.description,
                style: AppTextStyles.bodyBase.copyWith(color: t.body)),

            // Image (wideWithImage)
            if (widget.item.variant == CardVariant.wideWithImage &&
                widget.item.imageUrl != null) ...[
              const SizedBox(height: 32),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AnimatedScale(
                  scale: _hovered ? 1.04 : 1.0,
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOut,
                  child: Image.network(widget.item.imageUrl!,
                      height: 210,
                      width: double.infinity,
                      fit: BoxFit.cover),
                ),
              ),
            ],

            // Skeleton lines (wideWithSkeleton)
            if (widget.item.variant == CardVariant.wideWithSkeleton) ...[
              const SizedBox(height: 32),
              _skeletonLine(0.83, 0.20),
              const SizedBox(height: 10),
              _skeletonLine(1.0, 0.10),
              const SizedBox(height: 10),
              _skeletonLine(0.67, 0.10),
              const SizedBox(height: 10),
              _skeletonLine(0.55, 0.15),
            ],
          ],
        ),
      ),
    );
  }

  Widget _skeletonLine(double widthFactor, double opacity) =>
      FractionallySizedBox(
        widthFactor: widthFactor,
        alignment: Alignment.centerLeft,
        child: Container(
          height: 10,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(opacity),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// FOOTER SECTION
// ─────────────────────────────────────────────────────────────────────────────

class _FooterSection extends StatelessWidget {
  const _FooterSection();

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 768;

    return Container(
      color: AppColors.surfaceContainerLow,
      padding: EdgeInsets.symmetric(
          horizontal: wide ? 48 : 24, vertical: 64),
      child: wide
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [_Brand(), _Links()],
            )
          : Column(children: [_Brand(), const SizedBox(height: 32), _Links()]),
    );
  }
}

class _Brand extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.auto_stories,
              color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Text('MnemoApp',
              style: AppTextStyles.navBrand
                  .copyWith(color: AppColors.primary, fontSize: 18)),
        ]),
        const SizedBox(height: 6),
        Text('© 2024 MnemoApp. Built for the curious.',
            style:
                AppTextStyles.bodyBase.copyWith(fontSize: 13)),
      ],
    );
  }
}

class _Links extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 32,
      runSpacing: 12,
      children: footerLinks
          .map((l) => _FooterLink(label: l))
          .toList(),
    );
  }
}

class _FooterLink extends StatefulWidget {
  const _FooterLink({required this.label});
  final String label;

  @override
  State<_FooterLink> createState() => _FooterLinkState();
}

class _FooterLinkState extends State<_FooterLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () {},
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 150),
          style: AppTextStyles.bodyBase.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _hovered
                ? AppColors.primary
                : AppColors.onSurfaceVariant,
          ),
          child: Text(widget.label),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED SMALL WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

/// Gradient pill button — primary CTA.
class _PillButton extends StatefulWidget {
  const _PillButton({
    required this.label,
    required this.onTap,
    this.small = false,
  });
  final String label;
  final VoidCallback onTap;
  final bool small;

  @override
  State<_PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<_PillButton>
    with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 220));

  late final _scale = Tween(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: widget.small ? 26 : 40,
            vertical: widget.small ? 10 : 20,
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.primaryContainer],
            ),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.22),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Text(
            widget.label,
            style: AppTextStyles.buttonLabel.copyWith(
              color: AppColors.onPrimary,
              fontSize: widget.small ? 13 : 17,
            ),
          ),
        ),
      ),
    );
  }
}

/// Ghost pill button — secondary CTA.
class _OutlineButton extends StatefulWidget {
  const _OutlineButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  State<_OutlineButton> createState() => _OutlineButtonState();
}

class _OutlineButtonState extends State<_OutlineButton>
    with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 220));

  late final _scale = Tween(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

  bool _hovered = false;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => _ctrl.forward(),
        onTapUp: (_) { _ctrl.reverse(); widget.onTap(); },
        onTapCancel: () => _ctrl.reverse(),
        child: ScaleTransition(
          scale: _scale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding:
                const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            decoration: BoxDecoration(
              color: _hovered
                  ? AppColors.surfaceContainerLow
                  : AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                  color: AppColors.primary.withOpacity(0.15), width: 2),
            ),
            child: Text(widget.label,
                style: AppTextStyles.buttonLabel
                    .copyWith(color: AppColors.primary)),
          ),
        ),
      ),
    );
  }
}

/// Overlapping avatar stack for social proof.
class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.avatars});
  final List<StudentAvatar> avatars;

  static const double _size = 42;
  static const double _overlap = 12;

  @override
  Widget build(BuildContext context) {
    final w = _size + (_size - _overlap) * (avatars.length - 1);
    return SizedBox(
      width: w,
      height: _size,
      child: Stack(
        children: List.generate(
          avatars.length,
          (i) => Positioned(
            left: i * (_size - _overlap),
            child: Container(
              width: _size,
              height: _size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.surfaceContainerLowest, width: 2),
                image: DecorationImage(
                  image: NetworkImage(avatars[i].url),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Decorative blurred colour blobs in the background.
class _BackgroundBlobs extends StatelessWidget {
  const _BackgroundBlobs();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(children: [
          Positioned(
            top: 80, left: -80,
            child: _Blob(380, AppColors.secondaryFixedDim.withOpacity(0.18)),
          ),
          Positioned(
            top: 320, right: -80,
            child: _Blob(500, AppColors.tertiaryContainer.withOpacity(0.16)),
          ),
        ]),
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
      imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
