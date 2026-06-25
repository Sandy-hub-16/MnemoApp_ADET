import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../landing_page/app_theme.dart';
import '../../../business-layer/services/progress_service.dart';
import '../../../main.dart';
import 'delete_account_dialog.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SETTINGS SCREEN
// ─────────────────────────────────────────────────────────────────────────────

// SharedPreferences keys used by both SettingsScreen and QuizScreen.
const String kQuizTimerEnabledKey = 'quiz_timer_enabled';
const String kShuffleCardsKey = 'shuffle_cards_enabled';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _quizTimerEnabled = false;
  bool _shuffleCardsEnabled = true; // default on, matches original behaviour

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _quizTimerEnabled = prefs.getBool(kQuizTimerEnabledKey) ?? false;
      _shuffleCardsEnabled = prefs.getBool(kShuffleCardsKey) ?? true;
    });
  }

  Future<void> _setQuizTimer(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kQuizTimerEnabledKey, value);
    if (!mounted) return;
    setState(() => _quizTimerEnabled = value);
  }

  Future<void> _setShuffleCards(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kShuffleCardsKey, value);
    if (!mounted) return;
    setState(() => _shuffleCardsEnabled = value);
  }

  void _showAmnesiaConfirmation(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _AmnesiaConfirmationDialog(),
    );
  }

  void _showDeleteAccountConfirmation(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const DeleteAccountConfirmationDialog(),
    );
  }

  void _showStudyRemindersDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const _StudyRemindersDialog(),
    );
  }

  void _showLegalModal(
    BuildContext context,
    String title,
    IconData icon,
    List<_LegalSection> sections,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LegalBottomSheet(
        title: title,
        icon: icon,
        sections: sections,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            backgroundColor: AppColors.background,
            elevation: 0,
            pinned: true,
            expandedHeight: 80,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: AppColors.onSurface),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: LayoutBuilder(
              builder: (context, constraints) {
                final isCollapsed =
                    constraints.maxHeight <= kToolbarHeight + 40;
                return FlexibleSpaceBar(
                  centerTitle: false,
                  titlePadding: EdgeInsets.only(
                    left: isCollapsed ? 56 : 20,
                    bottom: isCollapsed ? 16 : 16,
                  ),
                  title: Text(
                    'Settings',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: isCollapsed ? 20 : 28,
                      fontWeight: FontWeight.w900,
                      color: AppColors.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                );
              },
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Study Settings ────────────────────────────────────────────
                _SectionHeader(
                  icon: Icons.school_rounded,
                  label: 'STUDY SETTINGS',
                  color: AppColors.primary,
                ),
                const SizedBox(height: 12),
                _SettingsGroup(
                  children: [
                    _SettingsTile(
                      icon: Icons.timer_outlined,
                      iconBg: AppColors.primaryContainer.withOpacity(0.5),
                      iconColor: AppColors.primary,
                      label: 'Quiz Timer',
                      subtitle: '15-second countdown per card',
                      trailing: Switch(
                        value: _quizTimerEnabled,
                        onChanged: _setQuizTimer,
                        activeColor: AppColors.primary,
                      ),
                      onTap: null,
                      isFirst: true,
                    ),
                    _SettingsTile(
                      icon: Icons.shuffle_rounded,
                      iconBg: AppColors.secondaryContainer.withOpacity(0.5),
                      iconColor: AppColors.onSecondaryContainer,
                      label: 'Shuffle Cards',
                      subtitle: 'Randomize card order in quizzes',
                      trailing: Switch(
                        value: _shuffleCardsEnabled,
                        onChanged: _setShuffleCards,
                        activeColor: AppColors.primary,
                      ),
                      onTap: null,
                    ),
                    _SettingsTile(
                      icon: Icons.auto_awesome_rounded,
                      iconBg: AppColors.tertiaryContainer.withOpacity(0.5),
                      iconColor: AppColors.onTertiaryContainer,
                      label: 'Smart Review',
                      subtitle: 'Prioritize cards you struggle with',
                      trailing: Switch(
                        value: false,
                        onChanged: (val) {},
                        activeColor: AppColors.primary,
                      ),
                      onTap: null,
                    ),
                    _SettingsTile(
                      icon: Icons.notifications_outlined,
                      iconBg: AppColors.tertiaryContainer.withOpacity(0.5),
                      iconColor: AppColors.onTertiaryContainer,
                      label: 'Study Reminders',
                      subtitle: 'Set daily study notifications',
                      onTap: () => _showStudyRemindersDialog(context),
                      isLast: true,
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // ── About ─────────────────────────────────────────────────────
                _SectionHeader(
                  icon: Icons.info_rounded,
                  label: 'ABOUT',
                  color: AppColors.outline,
                ),
                const SizedBox(height: 12),
                _SettingsGroup(
                  children: [
                    _SettingsTile(
                      icon: Icons.description_outlined,
                      iconBg: AppColors.surfaceContainerLow,
                      iconColor: AppColors.onSurfaceVariant,
                      label: 'Terms of Service',
                      onTap: () => _showLegalModal(
                        context,
                        'Terms of Service',
                        Icons.description_outlined,
                        _LegalContent.termsOfService,
                      ),
                      isFirst: true,
                    ),
                    _SettingsTile(
                      icon: Icons.privacy_tip_outlined,
                      iconBg: AppColors.surfaceContainerLow,
                      iconColor: AppColors.onSurfaceVariant,
                      label: 'Privacy Policy',
                      onTap: () => _showLegalModal(
                        context,
                        'Privacy Policy',
                        Icons.privacy_tip_outlined,
                        _LegalContent.privacyPolicy,
                      ),
                      isLast: true,
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // ── Danger Zone ───────────────────────────────────────────────
                _SectionHeader(
                  icon: Icons.warning_rounded,
                  label: 'DANGER ZONE',
                  color: AppColors.error,
                ),
                const SizedBox(height: 12),
                _DangerZoneCard(
                  onAmnesiaTap: () => _showAmnesiaConfirmation(context),
                  onDeleteAccountTap: () =>
                      _showDeleteAccountConfirmation(context),
                ),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.onSurfaceVariant,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SETTINGS GROUP - Groups tiles together
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SETTINGS TILE
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    this.subtitle,
    this.trailing,
    required this.onTap,
    this.isFirst = false,
    this.isLast = false,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(20) : Radius.zero,
          bottom: isLast ? const Radius.circular(20) : Radius.zero,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            border: !isLast
                ? Border(
                    bottom: BorderSide(
                      color: AppColors.outlineVariant.withOpacity(0.3),
                      width: 0.5,
                    ),
                  )
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.onSurfaceVariant,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DANGER ZONE CARD
// ─────────────────────────────────────────────────────────────────────────────

class _DangerZoneCard extends StatefulWidget {
  const _DangerZoneCard({
    required this.onAmnesiaTap,
    required this.onDeleteAccountTap,
  });

  final VoidCallback onAmnesiaTap;
  final VoidCallback onDeleteAccountTap;

  @override
  State<_DangerZoneCard> createState() => _DangerZoneCardState();
}

class _DangerZoneCardState extends State<_DangerZoneCard> {
  // Collapsed by default — the user must deliberately expand this section
  // before either destructive action becomes tappable at all.
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.errorContainer.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.error.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.error.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ── Expand/collapse header — neutral styling on purpose, so it
          // reads as "reveal this section" rather than as a destructive
          // action itself. ───────────────────────────────────────────────
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(20),
                bottom: _expanded ? Radius.zero : const Radius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.error,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sensitive Actions',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _expanded
                                ? 'Tap to hide'
                                : 'Tap to reveal irreversible actions',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.onSurfaceVariant,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Collapsible body ────────────────────────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Column(
                    children: [
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: AppColors.error.withOpacity(0.15),
                        indent: 20,
                        endIndent: 20,
                      ),
                      _DangerZoneRow(
                        icon: Icons.psychology_rounded,
                        title: 'Amnesia',
                        subtitle: 'Reset all progress data permanently',
                        onTap: widget.onAmnesiaTap,
                        topRounded: false,
                        bottomRounded: false,
                      ),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: AppColors.error.withOpacity(0.15),
                        indent: 20,
                        endIndent: 20,
                      ),
                      _DangerZoneRow(
                        icon: Icons.no_accounts_rounded,
                        title: 'Delete Account',
                        subtitle:
                            'Permanently delete your account and all your data',
                        onTap: widget.onDeleteAccountTap,
                        topRounded: false,
                        bottomRounded: true,
                      ),
                    ],
                  )
                : const SizedBox(width: double.infinity, height: 0),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DANGER ZONE ROW — a single tappable row inside the Danger Zone card
// ─────────────────────────────────────────────────────────────────────────────

class _DangerZoneRow extends StatelessWidget {
  const _DangerZoneRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.topRounded,
    required this.bottomRounded,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool topRounded;
  final bool bottomRounded;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.vertical(
          top: topRounded ? const Radius.circular(20) : Radius.zero,
          bottom: bottomRounded ? const Radius.circular(20) : Radius.zero,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: AppColors.error,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.error,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AMNESIA CONFIRMATION DIALOG
// ─────────────────────────────────────────────────────────────────────────────

class _AmnesiaConfirmationDialog extends StatefulWidget {
  const _AmnesiaConfirmationDialog();

  @override
  State<_AmnesiaConfirmationDialog> createState() =>
      _AmnesiaConfirmationDialogState();
}

class _AmnesiaConfirmationDialogState
    extends State<_AmnesiaConfirmationDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isConfirmationValid => _controller.text == 'I am absolutely sure';

  Future<void> _handleReset() async {
    if (!_isConfirmationValid) {
      setState(() => _errorMessage = 'Please type the exact phrase');
      return;
    }

    // Flip to loading state IN PLACE — never pop this dialog until we are
    // completely done. Popping the dialog early detaches its BuildContext,
    // so any subsequent Navigator / ScaffoldMessenger calls on that context
    // are no-ops or exceptions, which is exactly what caused the stuck screen.
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      await ProgressService.resetAllProgress();

      if (!mounted) return;

      // Capture navigator + messenger BEFORE popping this dialog.
      // Once pop() is called the dialog's context is detached, so any
      // Navigator/ScaffoldMessenger calls after that point must use
      // these pre-captured references — not `context`.
      final nav = Navigator.of(context, rootNavigator: true);
      final messenger = ScaffoldMessenger.of(context);

      nav.pop(); // dismiss the amnesia dialog

      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'All progress data has been reset',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          duration: const Duration(seconds: 3),
        ),
      );

      // Wait for snackbar, then rebuild the whole widget tree from scratch
      // using the pre-captured navigator (dialog context is already dead).
      await Future.delayed(const Duration(seconds: 3));
      nav.pushNamedAndRemoveUntil(
        AppRoutes.progress,
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      print('[AmnesiaConfirmation] Reset failed with error: $e');

      // Re-enable the form so the user can try again.
      setState(() {
        _isProcessing = false;
        _errorMessage =
            'Failed to reset progress. Please check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: AppColors.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _isProcessing ? _buildLoadingBody() : _buildConfirmBody(),
      ),
    );
  }

  // ── Loading state — shown in-place while resetAllProgress() runs ──────────
  Widget _buildLoadingBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        const CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 3,
        ),
        const SizedBox(height: 24),
        Text(
          'Resetting all progress...',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Please wait, do not close the app',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ── Confirmation form — shown before the user commits ─────────────────────
  Widget _buildConfirmBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.errorContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(14),
              ),
              child:
                  Icon(Icons.warning_rounded, color: AppColors.error, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Amnesia',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onSurface,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    'This action cannot be undone',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Warning message
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.errorContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.error.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will permanently delete:',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              ..._buildWarningItem('All quiz attempt history'),
              ..._buildWarningItem('All mastery percentages'),
              ..._buildWarningItem('Study streak data'),
              ..._buildWarningItem('Weak spots and forgotten cards'),
              const SizedBox(height: 8),
              Text(
                'Your decks and cards will remain intact.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: AppColors.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Confirmation input
        Text(
          'Type "I am absolutely sure" to confirm:',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _controller,
          onChanged: (_) => setState(() => _errorMessage = null),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: AppColors.onSurface,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: 'I am absolutely sure',
            hintStyle: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: AppColors.outline.withOpacity(0.5),
            ),
            filled: true,
            fillColor: AppColors.surfaceContainerLow,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: _errorMessage != null
                    ? AppColors.error
                    : AppColors.outlineVariant,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: _errorMessage != null
                    ? AppColors.error
                    : AppColors.outlineVariant,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color:
                    _errorMessage != null ? AppColors.error : AppColors.primary,
                width: 2,
              ),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.error_outline_rounded,
                  color: AppColors.error, size: 14),
              const SizedBox(width: 6),
              Text(
                _errorMessage!,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),

        // Action buttons
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _handleReset,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  'Reset All Progress',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildWarningItem(String text) {
    return [
      Row(
        children: [
          Icon(Icons.close_rounded, color: AppColors.error, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppColors.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
    ];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STUDY REMINDERS DIALOG
// ─────────────────────────────────────────────────────────────────────────────

class _StudyRemindersDialog extends StatefulWidget {
  const _StudyRemindersDialog();

  @override
  State<_StudyRemindersDialog> createState() => _StudyRemindersDialogState();
}

class _StudyRemindersDialogState extends State<_StudyRemindersDialog> {
  bool _enabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFromFirestore();
  }

  Future<void> _loadFromFirestore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data();
      if (data != null && mounted) {
        final hourUTC = (data['reminderHourUTC'] as num?)?.toInt();
        final minuteUTC = (data['reminderMinuteUTC'] as num?)?.toInt() ?? 0;
        setState(() {
          _enabled = data['reminderEnabled'] == true;
          if (hourUTC != null) {
            final localOffset = DateTime.now().timeZoneOffset;
            final utcMinutes = hourUTC * 60 + minuteUTC;
            final localMinutes = utcMinutes + localOffset.inMinutes;
            final localHour = (localMinutes ~/ 60) % 24;
            final localMinute = (localMinutes % 60).toInt();
            _reminderTime = TimeOfDay(hour: localHour, minute: localMinute);
          }
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveToFirestore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final now = DateTime.now();
    final localDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      _reminderTime.hour,
      _reminderTime.minute,
    );
    final utcDateTime = localDateTime.toUtc();
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'reminderEnabled': _enabled,
      'reminderHourUTC': utcDateTime.hour,
      'reminderMinuteUTC': utcDateTime.minute,
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Dialog(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: AppColors.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.tertiaryContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.notifications_outlined,
                      color: AppColors.tertiary, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Study Reminders',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onSurface,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Daily study notifications',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Enable Reminders',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Get notified to study daily',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: _enabled,
                        onChanged: (value) => setState(() => _enabled = value),
                        activeColor: AppColors.primary,
                      ),
                    ],
                  ),
                  if (_enabled) ...[
                    const SizedBox(height: 16),
                    Divider(color: AppColors.outlineVariant.withOpacity(0.3)),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: _reminderTime,
                        );
                        if (time != null) {
                          setState(() => _reminderTime = time);
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.outlineVariant),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.access_time_rounded,
                                    color: AppColors.primary, size: 20),
                                const SizedBox(width: 12),
                                Text(
                                  'Reminder Time',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.onSurface,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              _reminderTime.format(context),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () async {
                      await _saveToFirestore();
                      if (!mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.20),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check_rounded,
                                    color: Colors.white, size: 16),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _enabled
                                      ? 'Reminder set for ${_reminderTime.format(context)}'
                                      : 'Reminders disabled',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: const Color(0xFF16A34A),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      'Save Settings',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LEGAL CONTENT DATA
// ─────────────────────────────────────────────────────────────────────────────

class _LegalSection {
  const _LegalSection({required this.heading, required this.body});
  final String heading;
  final String body;
}

abstract final class _LegalContent {
  static const String _effectiveDate = 'Effective Date: June 1, 2025';

  // ── Terms of Service ──────────────────────────────────────────────────────
  static const List<_LegalSection> termsOfService = [
    _LegalSection(
      heading: '',
      body: 'Welcome to Mnemo. By downloading, accessing, or using the Mnemo '
          'mobile application ("App"), you agree to be bound by these Terms of '
          'Service ("Terms"). If you do not agree, please uninstall and stop '
          'using the App.\n\n$_effectiveDate',
    ),
    _LegalSection(
      heading: '1. Use of the App',
      body: 'Mnemo is a personal flashcard and spaced-repetition study tool '
          'intended for individual, non-commercial use. You must be at least '
          '13 years old to create an account. You are responsible for '
          'maintaining the confidentiality of your login credentials and for '
          'all activity that occurs under your account.',
    ),
    _LegalSection(
      heading: '2. User Content',
      body: 'You retain ownership of any decks, cards, or other content you '
          'create ("User Content"). By using Mnemo, you grant us a limited, '
          'non-exclusive, royalty-free license to store and process your User '
          'Content solely to provide and improve the service. You agree not to '
          'upload content that is unlawful, harmful, or infringes the '
          'intellectual property rights of others.',
    ),
    _LegalSection(
      heading: '3. Acceptable Use',
      body: 'You agree not to (a) reverse-engineer, decompile, or disassemble '
          'the App; (b) use the App to transmit spam or malicious code; '
          '(c) attempt to gain unauthorized access to any part of our '
          'infrastructure; or (d) use the App in any way that violates '
          'applicable laws or regulations.',
    ),
    _LegalSection(
      heading: '4. Intellectual Property',
      body: 'All design, code, branding, and non-user content in the App is '
          'owned by Mnemo or its licensors and is protected by applicable '
          'intellectual property laws. You may not reproduce or redistribute '
          'any part of the App without our prior written permission.',
    ),
    _LegalSection(
      heading: '5. Disclaimers',
      body: 'The App is provided "as is" without warranties of any kind, '
          'express or implied. We do not guarantee that the App will be '
          'error-free, uninterrupted, or that any data you store will never '
          'be lost. Use of the App is at your own risk.',
    ),
    _LegalSection(
      heading: '6. Limitation of Liability',
      body: 'To the fullest extent permitted by law, Mnemo and its developers '
          'shall not be liable for any indirect, incidental, special, or '
          'consequential damages arising from your use of or inability to use '
          'the App, even if we have been advised of the possibility of such '
          'damages.',
    ),
    _LegalSection(
      heading: '7. Changes to These Terms',
      body: 'We may update these Terms from time to time. When we do, we will '
          'revise the Effective Date above and, where required by law, notify '
          'you in-app or by email. Continued use of the App after changes '
          'constitutes your acceptance of the updated Terms.',
    ),
    _LegalSection(
      heading: '8. Termination',
      body: 'We reserve the right to suspend or terminate your account at our '
          'discretion if we believe you have violated these Terms. You may '
          'delete your account at any time from the Profile settings.',
    ),
    _LegalSection(
      heading: '9. Contact',
      body:
          'If you have questions about these Terms, please reach out to us at '
          'support@mnemoapp.com.',
    ),
  ];

  // ── Privacy Policy ────────────────────────────────────────────────────────
  static const List<_LegalSection> privacyPolicy = [
    _LegalSection(
      heading: '',
      body: 'Your privacy matters to us. This Privacy Policy explains what '
          'information Mnemo collects, how we use it, and your rights '
          'regarding that information.\n\n$_effectiveDate',
    ),
    _LegalSection(
      heading: '1. Information We Collect',
      body: 'Account Information — When you register, we collect your email '
          'address, display name, and an encrypted password hash.\n\n'
          'Study Data — Decks, flashcards, quiz scores, mastery percentages, '
          'and study-streak data that you create or generate while using '
          'the App.\n\n'
          'Usage Analytics (optional) — Aggregate, anonymized data about '
          'feature usage to help us improve the App. This is off by default '
          'and can be toggled in Settings → Privacy & Data.',
    ),
    _LegalSection(
      heading: '2. How We Use Your Information',
      body: 'We use the information we collect to:\n'
          '• Provide, maintain, and improve the App.\n'
          '• Sync your data across devices via Firebase.\n'
          '• Send study reminders if you have enabled push notifications.\n'
          '• Respond to support requests.\n\n'
          'We do not sell, rent, or share your personal information with '
          'third parties for their own marketing purposes.',
    ),
    _LegalSection(
      heading: '3. Data Storage & Security',
      body: 'Your data is stored on Google Firebase (Firestore and '
          'Authentication), which is protected by industry-standard '
          'encryption in transit (TLS) and at rest. We enforce strict access '
          'controls so that only you — and our backend services — can access '
          'your study data.',
    ),
    _LegalSection(
      heading: '4. Offline Data',
      body:
          'Mnemo caches a copy of your data locally on your device to support '
          'offline study. This local cache is stored in the app sandbox and '
          'is not accessible to other apps. It is removed when you log out '
          'or uninstall the App.',
    ),
    _LegalSection(
      heading: '5. Children\'s Privacy',
      body: 'Mnemo is not directed to children under 13. We do not knowingly '
          'collect personal information from children under 13. If we '
          'discover that a child under 13 has provided us with personal '
          'information, we will promptly delete it.',
    ),
    _LegalSection(
      heading: '6. Your Rights',
      body: 'You may request access to, correction of, or deletion of your '
          'personal data at any time. To delete your account and all '
          'associated data, go to Profile → Delete Account, or email us at '
          'privacy@mnemoapp.com. We will process your request within 30 days.',
    ),
    _LegalSection(
      heading: '7. Third-Party Services',
      body: 'The App uses the following third-party services, each governed by '
          'their own privacy policies:\n'
          '• Google Firebase (authentication & database)\n'
          '• Google Fonts (typeface rendering)\n\n'
          'We encourage you to review their policies.',
    ),
    _LegalSection(
      heading: '8. Changes to This Policy',
      body: 'We may update this Privacy Policy from time to time. We will '
          'notify you of material changes by updating the Effective Date and, '
          'where required, through an in-app notice or email.',
    ),
    _LegalSection(
      heading: '9. Contact',
      body: 'For privacy-related questions or requests, please contact us at '
          'privacy@mnemoapp.com.',
    ),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// LEGAL BOTTOM SHEET — modal for both ToS and Privacy Policy
// ─────────────────────────────────────────────────────────────────────────────

class _LegalBottomSheet extends StatelessWidget {
  const _LegalBottomSheet({
    required this.title,
    required this.icon,
    required this.sections,
  });

  final String title;
  final IconData icon;
  final List<_LegalSection> sections;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      snap: true,
      snapSizes: const [0.75, 0.95],
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // ── Drag handle ───────────────────────────────────────────────
              const SizedBox(height: 14),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // ── Title row ─────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon,
                          color: AppColors.onSurfaceVariant, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.onSurface,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded,
                          color: AppColors.onSurfaceVariant, size: 22),
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surfaceContainerLow,
                        padding: const EdgeInsets.all(8),
                        minimumSize: const Size(36, 36),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Divider(
                  color: AppColors.outlineVariant.withOpacity(0.35),
                  height: 1,
                ),
              ),

              // ── Scrollable content ────────────────────────────────────────
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  itemCount: sections.length,
                  itemBuilder: (context, index) {
                    final section = sections[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (section.heading.isNotEmpty) ...[
                            Text(
                              section.heading,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.onSurface,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          Text(
                            section.body,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              height: 1.65,
                              color: section.heading.isEmpty
                                  ? AppColors.onSurfaceVariant
                                  : AppColors.onSurface,
                              fontWeight: section.heading.isEmpty
                                  ? FontWeight.w500
                                  : FontWeight.w400,
                            ),
                          ),
                          if (section.heading.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 20),
                              child: Divider(
                                color:
                                    AppColors.outlineVariant.withOpacity(0.4),
                                height: 1,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
