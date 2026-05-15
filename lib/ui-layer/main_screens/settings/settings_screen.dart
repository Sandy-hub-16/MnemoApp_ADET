import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../landing_page/app_theme.dart';
import '../../../business-layer/services/progress_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SETTINGS SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
                final isCollapsed = constraints.maxHeight <= kToolbarHeight + 40;
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
            // Study Settings Section
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
                  subtitle: 'Set default time limit for quizzes',
                  trailing: Text(
                    'Off',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  onTap: () {},
                  isFirst: true,
                ),
                _SettingsTile(
                  icon: Icons.shuffle_rounded,
                  iconBg: AppColors.secondaryContainer.withOpacity(0.5),
                  iconColor: AppColors.onSecondaryContainer,
                  label: 'Shuffle Cards',
                  subtitle: 'Randomize card order in quizzes',
                  trailing: Switch(
                    value: true,
                    onChanged: (val) {},
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
                  isLast: true,
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Notifications Section
            _SectionHeader(
              icon: Icons.notifications_rounded,
              label: 'NOTIFICATIONS',
              color: AppColors.secondary,
            ),
            const SizedBox(height: 12),
            _SettingsGroup(
              children: [
                _SettingsTile(
                  icon: Icons.notifications_active_outlined,
                  iconBg: AppColors.secondaryContainer.withOpacity(0.5),
                  iconColor: AppColors.secondary,
                  label: 'Push Notifications',
                  subtitle: 'Receive study reminders',
                  trailing: Switch(
                    value: true,
                    onChanged: (val) {},
                    activeColor: AppColors.primary,
                  ),
                  onTap: null,
                  isFirst: true,
                ),
                _SettingsTile(
                  icon: Icons.schedule_rounded,
                  iconBg: AppColors.secondaryContainer.withOpacity(0.5),
                  iconColor: AppColors.secondary,
                  label: 'Daily Reminder',
                  subtitle: 'Get reminded to study every day',
                  trailing: Text(
                    '9:00 AM',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  onTap: () {},
                  isLast: true,
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Privacy & Data Section
            _SectionHeader(
              icon: Icons.shield_rounded,
              label: 'PRIVACY & DATA',
              color: AppColors.tertiary,
            ),
            const SizedBox(height: 12),
            _SettingsGroup(
              children: [
                _SettingsTile(
                  icon: Icons.cloud_sync_rounded,
                  iconBg: AppColors.tertiaryContainer.withOpacity(0.5),
                  iconColor: AppColors.tertiary,
                  label: 'Cloud Sync',
                  subtitle: 'Sync data across devices',
                  trailing: Switch(
                    value: true,
                    onChanged: (val) {},
                    activeColor: AppColors.primary,
                  ),
                  onTap: null,
                  isFirst: true,
                ),
                _SettingsTile(
                  icon: Icons.analytics_outlined,
                  iconBg: AppColors.tertiaryContainer.withOpacity(0.5),
                  iconColor: AppColors.tertiary,
                  label: 'Usage Analytics',
                  subtitle: 'Help improve the app',
                  trailing: Switch(
                    value: false,
                    onChanged: (val) {},
                    activeColor: AppColors.primary,
                  ),
                  onTap: null,
                  isLast: true,
                ),
              ],
            ),
            const SizedBox(height: 28),

            // About Section
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
                  onTap: () {},
                  isFirst: true,
                ),
                _SettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  iconBg: AppColors.surfaceContainerLow,
                  iconColor: AppColors.onSurfaceVariant,
                  label: 'Privacy Policy',
                  onTap: () {},
                ),
                _SettingsTile(
                  icon: Icons.code_rounded,
                  iconBg: AppColors.surfaceContainerLow,
                  iconColor: AppColors.onSurfaceVariant,
                  label: 'App Version',
                  trailing: Text(
                    '1.0.0',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  onTap: null,
                  isLast: true,
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Danger Zone Section
            _SectionHeader(
              icon: Icons.warning_rounded,
              label: 'DANGER ZONE',
              color: AppColors.error,
            ),
            const SizedBox(height: 12),
            _DangerZoneCard(
              onAmnesiaTap: () => _showAmnesiaConfirmation(context),
            ),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _showAmnesiaConfirmation(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _AmnesiaConfirmationDialog(),
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

class _DangerZoneCard extends StatelessWidget {
  const _DangerZoneCard({required this.onAmnesiaTap});

  final VoidCallback onAmnesiaTap;

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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onAmnesiaTap,
          borderRadius: BorderRadius.circular(20),
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
                    Icons.psychology_rounded,
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
                        'Amnesia',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.error,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Reset all progress data permanently',
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

  bool get _isConfirmationValid =>
      _controller.text == 'I am absolutely sure';

  Future<void> _handleReset() async {
    if (!_isConfirmationValid) {
      setState(() => _errorMessage = 'Please type the exact phrase');
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    // Close dialog first
    Navigator.pop(context);

    // Show full-screen loading overlay
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Container(
          color: Colors.black.withOpacity(0.7),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 20),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
      await ProgressService.resetAllProgress();

      if (!mounted) return;

      // Close loading dialog
      Navigator.pop(context);

      // Show success message
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
    } catch (e) {
      if (!mounted) return;
      
      // Close loading dialog
      Navigator.pop(context);
      
      // Show error dialog
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: AppColors.surfaceContainerLowest,
          title: Row(
            children: [
              Icon(Icons.error_outline_rounded, color: AppColors.error, size: 24),
              const SizedBox(width: 12),
              Text(
                'Reset Failed',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
          content: Text(
            'Failed to reset progress. Please check your connection and try again.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'OK',
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: AppColors.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
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
                  child: Icon(Icons.warning_rounded,
                      color: AppColors.error, size: 26),
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
              enabled: !_isProcessing,
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
                    color: _errorMessage != null
                        ? AppColors.error
                        : AppColors.primary,
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
                    onPressed: _isProcessing
                        ? null
                        : () => Navigator.pop(context),
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
                    onPressed: _isProcessing ? null : _handleReset,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppColors.error.withOpacity(0.5),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
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
        ),
      ),
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
