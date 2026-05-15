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
  });

  final AppNotification notification;
  final VoidCallback onTap;

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

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.read;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          // Unread tiles get a faint primary tint; read tiles are plain white
          color: isUnread
              ? AppColors.primaryContainer.withValues(alpha: 0.12)
              : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
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
            // ── Bell icon (read/unread indicator) ─────────────────────
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isUnread
                    ? AppColors.primaryContainer
                    : AppColors.surfaceContainerLow,
              ),
              child: Icon(
                notification.type == 'profile_viewed'
                    ? (isUnread
                        ? Icons.person_rounded
                        : Icons.person_outline_rounded)
                    : (isUnread
                        ? Icons.notifications_rounded
                        : Icons.notifications_none_rounded),
                size: 20,
                color: isUnread ? AppColors.primary : AppColors.outline,
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
                          text: notification.type == 'profile_viewed'
                              ? ' viewed your profile'
                              : ' shared a new deck: ',
                        ),
                        if (notification.type != 'profile_viewed')
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
            if (isUnread) ...[
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
