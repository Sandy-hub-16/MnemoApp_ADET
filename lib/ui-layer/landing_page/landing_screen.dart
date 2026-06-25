import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../data-layer/landing_page/landing_data.dart';
import 'app_theme.dart';
import '../../main.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LANDING SCREEN
// The single screen that composes every section.
// ─────────────────────────────────────────────────────────────────────────────

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with SingleTickerProviderStateMixin {
  // One frame after mount we swap skeleton → real content with a fade.
  bool _ready = false;
  late final AnimationController _fadeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  late final Animation<double> _fade =
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

  @override
  void initState() {
    super.initState();
    // Wait for first frame so layout/images have a chance to begin loading,
    // then fade in the real content after a short breathing room.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) {
          setState(() => _ready = true);
          _fadeCtrl.forward();
        }
      });
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _ShimmerScope(
        child: Stack(
          children: [
            const _BackgroundBlobs(),
            // ── Skeleton layer (shown until _ready flips) ──────────────────────
            if (!_ready) const _FullPageSkeleton(),
            // ── Real content (fades in once ready) ────────────────────────────
            if (_ready)
              FadeTransition(
                opacity: _fade,
                child: CustomScrollView(
                  slivers: [
                    const SliverToBoxAdapter(child: SizedBox(height: 88)),
                    SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1280),
                          child: Column(
                            children: [
                              const _HeroSection(),
                              _LazyMount(
                                placeholder: const _FeaturesSectionSkeleton(),
                                builder: (_) => const _FeaturesSection(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _LazyMount(
                        placeholder: const _FooterSectionSkeleton(),
                        builder: (_) => const _FooterSection(),
                      ),
                    ),
                  ],
                ),
              ),
            // Glass nav always on top
            const Positioned(top: 0, left: 0, right: 0, child: _NavBar()),
          ],
        ),
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
            color: AppColors.surfaceContainerLow.withValues(alpha: 0.82),
            border: Border(
              bottom: BorderSide(
                  color: AppColors.outlineVariant.withValues(alpha: 0.12)),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                  _PillButton(
                    label: 'Sign In',
                    onTap: () =>
                        Navigator.of(context).pushNamed(AppRoutes.signIn),
                    small: true,
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer.withValues(alpha: 0.30),
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
                  child: Padding(
                    // Extra bottom room so ShaderMask never clips descenders (g, y, p…)
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      heroHeadlineHighlight,
                      style: AppTextStyles.heroDisplay(mobile: !wide)
                          .copyWith(color: Colors.white),
                    ),
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

        // CTA buttons — full-width stacked on mobile, inline on desktop
        if (!wide) ...[
          _PillButton(
            label: "Let's Get Started",
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.signUp1),
            fullWidth: true,
          ),
        ] else
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _PillButton(
                label: "Let's Get Started",
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.signUp1),
              )
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
                Text('Join us now and unlock your potential',
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
      vsync: this, duration: const Duration(milliseconds: 700));

  late final Animation<double> _tilt = Tween(begin: 0.017, end: 0.0)
      .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

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
                    color: AppColors.primary.withValues(alpha: 0.12),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: _LazyNetworkImage(
                url: heroImageUrl,
                height: 440,
                width: double.infinity,
                fit: BoxFit.cover,
                borderRadius: 12,
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
                        color: Colors.black.withValues(alpha: 0.12),
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
                                .withValues(alpha: 0.8),
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
      padding: EdgeInsets.symmetric(horizontal: wide ? 48 : 24, vertical: 96),
      child: Column(
        children: [
          // Header
          Text(featuresHeading,
              style: AppTextStyles.sectionHeading, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Text(featuresSubheading,
                style: AppTextStyles.bodyLarge, textAlign: TextAlign.center),
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
  ({
    Color bg,
    Color border,
    Color iconBg,
    Color iconColor,
    Color title,
    Color body
  }) get _tokens {
    switch (widget.item.variant) {
      case CardVariant.narrowAccentTertiary:
        return (
          bg: AppColors.tertiaryContainer.withValues(alpha: 0.22),
          border: AppColors.tertiaryContainer.withValues(alpha: 0.35),
          iconBg: AppColors.tertiaryContainer,
          iconColor: AppColors.tertiary,
          title: AppColors.onTertiaryContainer,
          body: AppColors.onTertiaryContainer.withValues(alpha: 0.8),
        );
      case CardVariant.narrowAccentSecondary:
        return (
          bg: AppColors.secondaryContainer.withValues(alpha: 0.22),
          border: AppColors.secondaryContainer.withValues(alpha: 0.35),
          iconBg: AppColors.secondaryContainer,
          iconColor: AppColors.secondary,
          title: AppColors.onSecondaryContainer,
          body: AppColors.onSecondaryContainer.withValues(alpha: 0.8),
        );
      default:
        return (
          bg: AppColors.surfaceContainerLowest,
          border: AppColors.outlineVariant.withValues(alpha: 0.12),
          iconBg: AppColors.primaryContainer.withValues(alpha: 0.5),
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
                color: AppColors.primary.withValues(alpha: 0.07),
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

            // Title — skeleton → real text
            _TextReveal(
              text: widget.item.title,
              style: AppTextStyles.cardHeading.copyWith(color: t.title),
              skeletonLines: const [1.0, 0.65],
              skeletonLineHeight: 20,
            ),
            const SizedBox(height: 12),

            // Description — skeleton → real text
            _TextReveal(
              text: widget.item.description,
              style: AppTextStyles.bodyBase.copyWith(color: t.body),
              skeletonLines: const [1.0, 1.0, 0.85, 0.70],
              skeletonLineHeight: 14,
            ),

            // Image (wideWithImage)
            if (widget.item.variant == CardVariant.wideWithImage &&
                widget.item.imageUrl != null) ...[
              const SizedBox(height: 32),
              AnimatedScale(
                scale: _hovered ? 1.04 : 1.0,
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOut,
                child: _LazyNetworkImage(
                  url: widget.item.imageUrl!,
                  height: 210,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  borderRadius: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TEXT REVEAL
// Generic scroll-triggered skeleton → real text widget used by every feature
// card title and description. Only starts counting down once the widget enters
// the viewport. After [delay] the shimmer bars crossfade into real text via
// AnimatedSwitcher — keeping only ONE child in the layout tree at all times.
//
// [skeletonLines]      — widthFactors (0.0–1.0), one bar per line.
// [skeletonLineHeight] — bar height in logical pixels; match the text style.
// ─────────────────────────────────────────────────────────────────────────────

class _TextReveal extends StatefulWidget {
  const _TextReveal({
    required this.text,
    required this.style,
    required this.skeletonLines,
    required this.skeletonLineHeight,
  });

  final String text;
  final TextStyle style;
  final List<double> skeletonLines;
  final double skeletonLineHeight;

  @override
  State<_TextReveal> createState() => _TextRevealState();
}

class _TextRevealState extends State<_TextReveal> {
  final _key = GlobalKey();
  ScrollPosition? _position;
  bool _visible = false;
  bool _revealed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newPos = Scrollable.maybeOf(context)?.position;
    if (newPos != _position) {
      _position?.removeListener(_checkVisibility);
      _position = newPos;
      _position?.addListener(_checkVisibility);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkVisibility());
  }

  void _checkVisibility() {
    if (_visible || !context.mounted) return;
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;

    final viewport = RenderAbstractViewport.of(box);
    final offsetToViewport = viewport.getOffsetToReveal(box, 0.0).offset;
    final scrollPos = _position;
    if (scrollPos == null) {
      _startCountdown();
      return;
    }

    final distanceIntoView =
        offsetToViewport - scrollPos.pixels - scrollPos.viewportDimension;
    if (distanceIntoView <= 200) _startCountdown();
  }

  void _startCountdown() {
    if (_visible) return;
    setState(() => _visible = true);
    _position?.removeListener(_checkVisibility);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _revealed = true);
    });
  }

  @override
  void dispose() {
    _position?.removeListener(_checkVisibility);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _key,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: _revealed ? _buildText() : _buildSkeleton(),
      ),
    );
  }

  Widget _buildText() {
    return SizedBox(
      key: const ValueKey('text'),
      width: double.infinity,
      child: Text(widget.text, style: widget.style),
    );
  }

  Widget _buildSkeleton() {
    return Column(
      key: const ValueKey('skeleton'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < widget.skeletonLines.length; i++) ...[
          FractionallySizedBox(
            widthFactor: widget.skeletonLines[i],
            alignment: Alignment.centerLeft,
            child: _SkeletonBlock(
                height: widget.skeletonLineHeight, borderRadius: 4),
          ),
          if (i < widget.skeletonLines.length - 1)
            SizedBox(height: (widget.skeletonLineHeight * 0.6).roundToDouble()),
        ],
      ],
    );
  }
}

class _FeaturesSectionSkeleton extends StatelessWidget {
  const _FeaturesSectionSkeleton();

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 768;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: wide ? 48 : 24, vertical: 96),
      child: Column(
        children: [
          _SkeletonBlock(width: 360, height: 40, borderRadius: 8),
          const SizedBox(height: 16),
          _SkeletonBlock(width: 480, height: 20, borderRadius: 6),
          const SizedBox(height: 64),
          // Rough stand-in for the card grid height so the page doesn't jump.
          _SkeletonBlock(height: wide ? 520 : 880, borderRadius: 20),
        ],
      ),
    );
  }
}

class _FooterSectionSkeleton extends StatelessWidget {
  const _FooterSectionSkeleton();

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 768;
    return Container(
      color: AppColors.surfaceContainerLow,
      padding: EdgeInsets.symmetric(horizontal: wide ? 48 : 24, vertical: 24),
      child: _SkeletonBlock(height: 28, borderRadius: 8),
    );
  }
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
      padding: EdgeInsets.symmetric(horizontal: wide ? 48 : 24, vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Brand wordmark + copyright — single compact line
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_stories,
                  color: AppColors.primary, size: 16),
              const SizedBox(width: 6),
              Text(
                'MnemoApp',
                style: AppTextStyles.navBrand.copyWith(
                  color: AppColors.primary,
                  fontSize: 15,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '© 2026',
                style: AppTextStyles.bodyBase.copyWith(fontSize: 12),
              ),
            ],
          ),
          // Links — always horizontal, condensed spacing
          Wrap(
            spacing: wide ? 24 : 16,
            children: footerLinks.map((l) => _FooterLink(label: l)).toList(),
          ),
        ],
      ),
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
            color: _hovered ? AppColors.primary : AppColors.onSurfaceVariant,
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
    this.fullWidth = false,
  });
  final String label;
  final VoidCallback onTap;
  final bool small;
  final bool fullWidth;

  @override
  State<_PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<_PillButton>
    with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 220));

  late final _scale = Tween(begin: 1.0, end: 0.95)
      .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

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
          width: widget.fullWidth ? double.infinity : null,
          alignment: widget.fullWidth ? Alignment.center : null,
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
                color: AppColors.primary.withValues(alpha: 0.22),
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
  const _OutlineButton({
    required this.label,
    required this.onTap,
    // ignore: unused_element_parameter
    this.fullWidth = false,
  });
  final String label;
  final VoidCallback onTap;
  final bool fullWidth;

  @override
  State<_OutlineButton> createState() => _OutlineButtonState();
}

class _OutlineButtonState extends State<_OutlineButton>
    with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 220));

  late final _scale = Tween(begin: 1.0, end: 0.95)
      .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

  bool _hovered = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => _ctrl.forward(),
        onTapUp: (_) {
          _ctrl.reverse();
          widget.onTap();
        },
        onTapCancel: () => _ctrl.reverse(),
        child: ScaleTransition(
          scale: _scale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: widget.fullWidth ? double.infinity : null,
            alignment: widget.fullWidth ? Alignment.center : null,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            decoration: BoxDecoration(
              color: _hovered
                  ? AppColors.surfaceContainerLow
                  : AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.15), width: 2),
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

// ─────────────────────────────────────────────────────────────────────────────
// FULL-PAGE SKELETON
// Shown for ~350 ms on first load before real content fades in.
// Mirrors the rough shape of the hero + features + footer so there's zero
// layout jump when the real content appears.
// ─────────────────────────────────────────────────────────────────────────────

class _FullPageSkeleton extends StatelessWidget {
  const _FullPageSkeleton();

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1024;
    final hPad = wide ? 48.0 : 24.0;

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nav bar stand-in
          const SizedBox(height: 88),

          // ── Hero skeleton ────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: hPad, vertical: wide ? 96 : 48),
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Copy side
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SkeletonBlock(
                                width: 140, height: 36, borderRadius: 999),
                            const SizedBox(height: 32),
                            _SkeletonBlock(
                                width: double.infinity,
                                height: 56,
                                borderRadius: 10),
                            const SizedBox(height: 12),
                            _SkeletonBlock(
                                width: 320, height: 56, borderRadius: 10),
                            const SizedBox(height: 24),
                            _SkeletonBlock(
                                width: double.infinity,
                                height: 18,
                                borderRadius: 6),
                            const SizedBox(height: 8),
                            _SkeletonBlock(
                                width: double.infinity,
                                height: 18,
                                borderRadius: 6),
                            const SizedBox(height: 8),
                            _SkeletonBlock(
                                width: 200, height: 18, borderRadius: 6),
                            const SizedBox(height: 40),
                            _SkeletonBlock(
                                width: 200, height: 56, borderRadius: 999),
                            const SizedBox(height: 40),
                            _SkeletonBlock(
                                width: 240, height: 42, borderRadius: 8),
                          ],
                        ),
                      ),
                      const SizedBox(width: 64),
                      // Image side
                      Expanded(
                        child: _SkeletonBlock(height: 480, borderRadius: 16),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SkeletonBlock(width: 120, height: 34, borderRadius: 999),
                      const SizedBox(height: 32),
                      _SkeletonBlock(
                          width: double.infinity, height: 46, borderRadius: 10),
                      const SizedBox(height: 10),
                      _SkeletonBlock(width: 260, height: 46, borderRadius: 10),
                      const SizedBox(height: 24),
                      _SkeletonBlock(
                          width: double.infinity, height: 16, borderRadius: 6),
                      const SizedBox(height: 8),
                      _SkeletonBlock(
                          width: double.infinity, height: 16, borderRadius: 6),
                      const SizedBox(height: 8),
                      _SkeletonBlock(width: 180, height: 16, borderRadius: 6),
                      const SizedBox(height: 40),
                      _SkeletonBlock(
                          width: double.infinity,
                          height: 54,
                          borderRadius: 999),
                      const SizedBox(height: 48),
                      _SkeletonBlock(height: 300, borderRadius: 16),
                    ],
                  ),
          ),

          // ── Features skeleton ────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 96),
            child: Column(
              children: [
                _SkeletonBlock(width: 320, height: 40, borderRadius: 8),
                const SizedBox(height: 16),
                _SkeletonBlock(width: 420, height: 20, borderRadius: 6),
                const SizedBox(height: 64),
                _SkeletonBlock(height: wide ? 520 : 760, borderRadius: 20),
              ],
            ),
          ),

          // ── Footer skeleton ──────────────────────────────────────────────
          Container(
            color: AppColors.surfaceContainerLow,
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 24),
            child: const _SkeletonBlock(height: 28, borderRadius: 8),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LAZY MOUNT
// Defers building an expensive subtree until it's about to enter the
// viewport, then keeps it mounted permanently (no rebuild thrashing on
// scroll back up). Zero external dependencies — just a global key + RenderBox
// position check, hooked to the ambient Scrollable's position via
// Scrollable.of + a post-frame/scroll listener.
// ─────────────────────────────────────────────────────────────────────────────

class _LazyMount extends StatefulWidget {
  const _LazyMount({
    required this.builder,
    required this.placeholder,
    // ignore: unused_element_parameter
    this.preloadExtent = 400.0,
  });

  /// Builds the real (expensive) content once visible.
  final WidgetBuilder builder;

  /// Shown (and sized) before the real content mounts.
  final Widget placeholder;

  /// How many pixels before entering the viewport we should start building.
  final double preloadExtent;

  @override
  State<_LazyMount> createState() => _LazyMountState();
}

class _LazyMountState extends State<_LazyMount> {
  final _key = GlobalKey();
  bool _mounted = false;
  ScrollPosition? _position;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newPosition = Scrollable.maybeOf(context)?.position;
    if (newPosition != _position) {
      _position?.removeListener(_checkVisibility);
      _position = newPosition;
      _position?.addListener(_checkVisibility);
    }
    // Always check once after layout, in case we're already on-screen
    // (e.g. on a short page, or after a hot-reload/resize).
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkVisibility());
  }

  void _checkVisibility() {
    if (_mounted || !context.mounted) return;
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;

    final viewport = RenderAbstractViewport.of(box);
    final offsetToViewport = viewport.getOffsetToReveal(box, 0.0).offset;
    final scrollPos = _position;
    if (scrollPos == null) {
      // No ancestor Scrollable (shouldn't happen here) — just mount.
      _markMounted();
      return;
    }

    final viewportHeight = scrollPos.viewportDimension;
    final distanceIntoView =
        offsetToViewport - scrollPos.pixels - viewportHeight;

    if (distanceIntoView <= widget.preloadExtent) {
      _markMounted();
    }
  }

  void _markMounted() {
    if (!_mounted && mounted) {
      setState(() => _mounted = true);
    }
  }

  @override
  void dispose() {
    _position?.removeListener(_checkVisibility);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _key,
      child: _mounted ? widget.builder(context) : widget.placeholder,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHIMMER SKELETON
// One AnimationController for the entire page, shared via _ShimmerScope.
// Previously every _SkeletonBlock had its own controller — with 30+ bars
// active simultaneously that was 30+ tickers all rebuilding independently
// on every frame. Now there is exactly one ticker; all bars read the same
// animation value through the InheritedWidget and rebuild together.
// ─────────────────────────────────────────────────────────────────────────────

/// Holds the single shared shimmer animation for the whole subtree.
class _ShimmerScope extends StatefulWidget {
  const _ShimmerScope({required this.child, super.key});
  final Widget child;

  @override
  State<_ShimmerScope> createState() => _ShimmerScopeState();

  static Animation<double>? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_ShimmerInherited>()
        ?.animation;
  }
}

class _ShimmerScopeState extends State<_ShimmerScope>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ShimmerInherited(
      animation: _ctrl,
      child: widget.child,
    );
  }
}

class _ShimmerInherited extends InheritedWidget {
  const _ShimmerInherited({
    required this.animation,
    required super.child,
  });
  final Animation<double> animation;

  @override
  bool updateShouldNotify(_ShimmerInherited old) => false;
}

/// A solid-colour block sized to [width]/[height], pulsing via the shared
/// _ShimmerScope animation. Falls back to a static block if no scope is found.
class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({
    this.width,
    this.height,
    this.borderRadius = 12,
  });
  final double? width;
  final double? height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final animation = _ShimmerScope.of(context);
    final block = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.outlineVariant.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
    if (animation == null) return block;
    return AnimatedBuilder(
      animation: animation,
      builder: (_, child) =>
          Opacity(opacity: 0.45 + (animation.value * 0.35), child: child),
      child: block,
    );
  }
}

/// Drop-in replacement for Image.network that shows a shimmering skeleton
/// (matching the image's own dimensions, so layout never jumps) until the
/// first frame has decoded.
class _LazyNetworkImage extends StatelessWidget {
  const _LazyNetworkImage({
    required this.url,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
    this.borderRadius = 0,
  });

  final String url;
  final double? height;
  final double? width;
  final BoxFit fit;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.network(
        url,
        height: height,
        width: width,
        fit: fit,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) return child;
          return _SkeletonBlock(
            width: width,
            height: height,
            borderRadius: borderRadius,
          );
        },
        errorBuilder: (context, error, stackTrace) => Container(
          height: height,
          width: width,
          color: AppColors.outlineVariant.withValues(alpha: 0.18),
          alignment: Alignment.center,
          child: Icon(Icons.image_not_supported_outlined,
              color: AppColors.outline, size: 28),
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
            top: 80,
            left: -80,
            child:
                _Blob(380, AppColors.secondaryFixedDim.withValues(alpha: 0.18)),
          ),
          Positioned(
            top: 320,
            right: -80,
            child:
                _Blob(500, AppColors.tertiaryContainer.withValues(alpha: 0.16)),
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
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
