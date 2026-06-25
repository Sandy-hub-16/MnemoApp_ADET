import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data-layer/models/social/app_notification.dart';
import '../../data-layer/route_args/social_route_args.dart';
import '../../main.dart';
import '../landing_page/app_theme.dart';
import 'widgets/notification_tile.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFICATION SCREEN  —  route: /notifications
//
// Displays a real-time stream of in-app notifications for the current user,
// ordered by createdAt descending.
//
// DATA PATH
// ─────────
//   users/{currentUid}/notifications  (real-time listener, ordered by createdAt desc)
//
// STATES
// ──────
//   loading  — CircularProgressIndicator while stream awaits first event
//   empty    — icon + message when no notifications exist
//   data     — scrollable list of NotificationTile widgets
//   error    — brief error message
//
// ACTIONS
// ───────
//   Tap tile       → mark read: true; check public_decks/{deckId} exists;
//                    navigate to sharedDeckDetail or show SnackBar
//   Mark all read  → batch-update all unread docs with read: true
//
// Requirements: 7.2, 7.3, 7.4, 7.5
// ─────────────────────────────────────────────────────────────────────────────

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _NotificationBody();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BODY
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationBody extends StatefulWidget {
  const _NotificationBody();

  @override
  State<_NotificationBody> createState() => _NotificationBodyState();
}

class _NotificationBodyState extends State<_NotificationBody> {
  // ── State ─────────────────────────────────────────────────────────────────

  late final String _currentUid;
  bool _isMarkingAll = false;

  @override
  void initState() {
    super.initState();
    _currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  // ── Firestore helpers ─────────────────────────────────────────────────────

  /// Stream of notification documents ordered by createdAt descending.
  Stream<QuerySnapshot<Map<String, dynamic>>> _notificationsStream() {
    if (_currentUid.isEmpty) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Marks a single notification as read.
  Future<void> _markRead(String notificationId) async {
    if (_currentUid.isEmpty) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUid)
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true});
  }

  /// Batch-updates all unread notifications to read: true.
  Future<void> _markAllRead(List<AppNotification> notifications) async {
    if (_currentUid.isEmpty) return;
    final unread = notifications.where((n) => !n.read).toList();
    if (unread.isEmpty) return;

    setState(() => _isMarkingAll = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final n in unread) {
        final ref = FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUid)
            .collection('notifications')
            .doc(n.notificationId);
        batch.update(ref, {'read': true});
      }
      await batch.commit();
    } catch (e) {
      if (mounted) _showErrorSnackBar('Failed to mark all as read.');
    } finally {
      if (mounted) setState(() => _isMarkingAll = false);
    }
  }

  // ── Tile tap handler ──────────────────────────────────────────────────────

  Future<void> _onTileTap(AppNotification notification) async {
    // 1. Mark as read (fire-and-forget; UI updates via stream)
    await _markRead(notification.notificationId);

    if (!mounted) return;

    // 2. Handle by notification type
    if (notification.type == 'profile_viewed') {
      // Navigate to the viewer's public profile only if we have a valid UID.
      // suppressViewNotification: true prevents PublicProfileScreen from
      // firing another profile_viewed notification back at the viewer, which
      // would create an infinite ping-pong loop between the two users.
      if (notification.fromUid.isNotEmpty) {
        Navigator.of(context).pushNamed(
          AppRoutes.publicProfile,
          arguments: PublicProfileArgs(
            targetUid: notification.fromUid,
            suppressViewNotification: true,
          ),
        );
      }
      return;
    }

    // 3. new_shared_deck — check whether the deck still exists
    final deckDoc = await FirebaseFirestore.instance
        .collection('public_decks')
        .doc(notification.deckId)
        .get();

    if (!mounted) return;

    if (deckDoc.exists) {
      Navigator.of(context).pushNamed(
        AppRoutes.sharedDeckDetail,
        arguments: SharedDeckDetailArgs(
          deckId: notification.deckId,
          ownerUid: deckDoc.data()?['ownerUid'] as String? ?? '',
        ),
      );
    } else {
      _showErrorSnackBar('This deck is no longer available');
    }
  }

  // ── SnackBar helper ───────────────────────────────────────────────────────

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: Stack(
        children: [
          // ── Decorative blobs ─────────────────────────────────────────────
          Positioned(
            top: -60,
            left: -80,
            child: _Blob(
              size: 300,
              color: AppColors.primaryContainer.withValues(alpha: 0.15),
            ),
          ),
          Positioned(
            bottom: 200,
            right: -100,
            child: _Blob(
              size: 260,
              color: AppColors.secondaryContainer.withValues(alpha: 0.18),
            ),
          ),

          // ── Main content ─────────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: _currentUid.isEmpty
                ? Column(
                    children: [
                      _NotificationTopBar(
                        notifications: const [],
                        isMarkingAll: false,
                        onMarkAllRead: null,
                        onBack: () => Navigator.of(context).pop(),
                      ),
                      Expanded(child: _buildEmptyState()),
                    ],
                  )
                : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _notificationsStream(),
                    builder: (context, snapshot) {
                      // ── Loading ──────────────────────────────────────────
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        );
                      }

                      // ── Error ────────────────────────────────────────────
                      if (snapshot.hasError) {
                        return Column(
                          children: [
                            _NotificationTopBar(
                              notifications: const [],
                              isMarkingAll: false,
                              onMarkAllRead: null,
                              onBack: () => Navigator.of(context).pop(),
                            ),
                            Expanded(child: _buildErrorState()),
                          ],
                        );
                      }

                      // Map Firestore docs → AppNotification list
                      final docs = snapshot.data?.docs ?? [];
                      final notifications = docs
                          .map((doc) => AppNotification.fromFirestore(doc))
                          .toList();

                      return Column(
                        children: [
                          _NotificationTopBar(
                            notifications: notifications,
                            isMarkingAll: _isMarkingAll,
                            onMarkAllRead: () => _markAllRead(notifications),
                            onBack: () => Navigator.of(context).pop(),
                          ),
                          Expanded(
                            child: notifications.isEmpty
                                ? _buildEmptyState()
                                : _buildList(notifications),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ── Notification list ─────────────────────────────────────────────────────

  Widget _buildList(List<AppNotification> notifications) {
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
      itemCount: notifications.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final notification = notifications[index];
        return NotificationTile(
          notification: notification,
          onTap: () => _onTileTap(notification),
        );
      },
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: 0.35),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 44,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No notifications yet',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'When someone you follow shares a new deck, you\'ll see it here.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: AppColors.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Error state ───────────────────────────────────────────────────────────

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Unable to load notifications. Please try again later.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppColors.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOP BAR
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationTopBar extends StatelessWidget {
  const _NotificationTopBar({
    required this.notifications,
    required this.isMarkingAll,
    required this.onMarkAllRead,
    required this.onBack,
  });

  final List<AppNotification> notifications;
  final bool isMarkingAll;

  /// Null when there are no notifications (hides the action button).
  final VoidCallback? onMarkAllRead;
  final VoidCallback onBack;

  int get _unreadCount => notifications.where((n) => !n.read).length;

  @override
  Widget build(BuildContext context) {
    final hasUnread = _unreadCount > 0;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          color: AppColors.background.withValues(alpha: 0.75),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              // ── Back button ───────────────────────────────────────────────
              IconButton(
                onPressed: onBack,
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppColors.onSurface,
                ),
              ),

              // ── Title + unread badge ──────────────────────────────────────
              Expanded(
                child: Row(
                  children: [
                    Text(
                      'Notifications',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onSurface,
                        letterSpacing: -0.4,
                      ),
                    ),
                    if (hasUnread) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$_unreadCount',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onPrimary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // ── Mark all as read button ───────────────────────────────────
              if (onMarkAllRead != null && hasUnread)
                isMarkingAll
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    : TextButton(
                        onPressed: onMarkAllRead,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        child: Text(
                          'Mark all read',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
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
// SHARED HELPERS
// ─────────────────────────────────────────────────────────────────────────────

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
