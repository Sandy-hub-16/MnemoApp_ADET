import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../data-layer/models/social/app_notification.dart';
import '../../landing_page/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFICATION TILE
//
// Displays a single AppNotification in a list tile. Shows:
//   • fromUsername — who triggered the notification
//   • deckTitle    — the deck that was shared
//   • createdAt    — human-readable time ago
//   • read/unread  — filled bell (unread) vs outlined bell (read)
//
// Tappable via [onTap] callback. Unread tiles have a subtle tinted background
// to draw attention.
//
// Requirements: 7.2, 7.3
// ─────────────────────────────────────────────────────────────────────────────

class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
    this.onLongPress,
    this.selectionMode = false,
    this.selected = false,
  });

  final AppNotification notification;
  final VoidCallback onTap;

  /// Fired on long-press — used by the parent screen to enter selection mode.
  final VoidCallback? onLongPress;

  /// When true, tapping the tile toggles [selected] instead of running the
  /// normal navigation/mark-read behavior, and a checkbox is shown in place
  /// of the leading icon.
  final bool selectionMode;
  final bool selected;

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return '$m ${m == 1 ? 'min' : 'mins'} ago';
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return '$h ${h == 1 ? 'hour' : 'hours'} ago';
    }
    if (diff.inDays < 30) {
      final d = diff.inDays;
      return '$d ${d == 1 ? 'day' : 'days'} ago';
    }
    if (diff.inDays < 365) {
      final mo = (diff.inDays / 30).floor();
      return '$mo ${mo == 1 ? 'month' : 'months'} ago';
    }
    final y = (diff.inDays / 365).floor();
    return '$y ${y == 1 ? 'year' : 'years'} ago';
  }

  /// Picks the icon for this notification's type and read state.
  IconData _iconFor(String type, bool isUnread) {
    switch (type) {
      case 'profile_viewed':
        return isUnread ? Icons.person_rounded : Icons.person_outline_rounded;
      case 'new_follower':
        return isUnread ? Icons.person_add_rounded : Icons.person_add_outlined;
      case 'deck_cloned':
        return isUnread
            ? Icons.content_copy_rounded
            : Icons.content_copy_outlined;
      default: // new_shared_deck and any future deck-related type
        return isUnread
            ? Icons.notifications_rounded
            : Icons.notifications_none_rounded;
    }
  }

  /// Picks the middle clause of the message line (after the bold username).
  String _messageFor(String type) {
    switch (type) {
      case 'profile_viewed':
        return ' viewed your profile';
      case 'new_follower':
        return ' started following you';
      case 'deck_cloned':
        return ' cloned your deck: ';
      default: // new_shared_deck and any future deck-related type
        return ' shared a new deck: ';
    }
  }

  /// Whether this notification type has an associated deck title to show.
  bool _hasDeckTitle(String type) =>
      type != 'profile_viewed' && type != 'new_follower';

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.read;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          // Selected tiles (in selection mode) get a stronger primary tint
          // so it's obvious at a glance which ones are checked.
          color: selectionMode && selected
              ? AppColors.primaryContainer.withValues(alpha: 0.35)
              : isUnread
                  ? AppColors.primaryContainer.withValues(alpha: 0.12)
                  : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: selectionMode && selected
              ? Border.all(color: AppColors.primary, width: 1.5)
              : Border.all(color: Colors.transparent, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.onSurface.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Bell icon (read/unread) or selection checkbox ──────────
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: selectionMode
                  ? AnimatedContainer(
                      key: const ValueKey('checkbox'),
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected
                            ? AppColors.primary
                            : AppColors.surfaceContainerLow,
                        border: selected
                            ? null
                            : Border.all(color: AppColors.outline, width: 1.5),
                      ),
                      child: selected
                          ? const Icon(Icons.check_rounded,
                              size: 20, color: Colors.white)
                          : null,
                    )
                  : Container(
                      key: const ValueKey('icon'),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isUnread
                            ? AppColors.primaryContainer
                            : AppColors.surfaceContainerLow,
                      ),
                      child: Icon(
                        _iconFor(notification.type, isUnread),
                        size: 20,
                        color: isUnread ? AppColors.primary : AppColors.outline,
                      ),
                    ),
            ),
            const SizedBox(width: 12),

            // ── Text content ──────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Message line
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: AppColors.onSurface,
                        height: 1.4,
                      ),
                      children: [
                        TextSpan(
                          text: notification.fromUsername,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                        ),
                        TextSpan(
                          text: _messageFor(notification.type),
                        ),
                        if (_hasDeckTitle(notification.type))
                          TextSpan(
                            text: notification.deckTitle,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Time ago
                  Text(
                    _timeAgo(notification.createdAt),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.outline,
                    ),
                  ),
                ],
              ),
            ),

            // ── Unread dot ────────────────────────────────────────────
            if (isUnread && !selectionMode) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
