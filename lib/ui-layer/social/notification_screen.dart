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
//   Tap tile       → mark read: true; profile_viewed/new_follower navigate to
//                    the other user's profile; new_shared_deck/deck_cloned
//                    check public_decks/{deckId} exists, then navigate to
//                    sharedDeckDetail or show a SnackBar
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

  // ── Selection-mode state ─────────────────────────────────────────────────
  // Using ValueNotifiers instead of plain setState so that toggling
  // selection rebuilds ONLY the tiles and top-bar, not the StreamBuilder
  // or the entire list — which was causing the jarring full-screen flash.
  final ValueNotifier<bool> _selectionMode = ValueNotifier(false);
  final ValueNotifier<Set<String>> _selectedIds = ValueNotifier({});
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  @override
  void dispose() {
    _selectionMode.dispose();
    _selectedIds.dispose();
    super.dispose();
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

  // ── Selection mode ─────────────────────────────────────────────────────────

  void _enterSelectionMode(String notificationId) {
    // Mutate a new Set so ValueNotifier listeners detect the change.
    final next = Set<String>.from(_selectedIds.value)..add(notificationId);
    _selectedIds.value = next;
    _selectionMode.value = true;
  }

  void _toggleSelected(String notificationId) {
    final next = Set<String>.from(_selectedIds.value);
    if (next.contains(notificationId)) {
      next.remove(notificationId);
    } else {
      next.add(notificationId);
    }
    _selectedIds.value = next;
    // Auto-exit selection mode once nothing is left checked.
    if (next.isEmpty) {
      _selectionMode.value = false;
    }
  }

  void _exitSelectionMode() {
    _selectedIds.value = {};
    _selectionMode.value = false;
  }

  /// Deletes only the currently checked notifications. Same button placement
  /// as "Delete All" — this is what runs instead, while selection mode is
  /// active.
  Future<void> _deleteSelected() async {
    if (_currentUid.isEmpty || _selectedIds.value.isEmpty) return;

    final confirmed = await _confirmDelete(
      title: 'Delete selected notifications?',
      message: 'This will permanently delete ${_selectedIds.value.length} '
          '${_selectedIds.value.length == 1 ? 'notification' : 'notifications'}. '
          'This can\'t be undone.',
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final id in _selectedIds.value) {
        batch.delete(
          FirebaseFirestore.instance
              .collection('users')
              .doc(_currentUid)
              .collection('notifications')
              .doc(id),
        );
      }
      await batch.commit();
      if (mounted) _exitSelectionMode();
    } catch (e) {
      if (mounted)
        _showErrorSnackBar('Failed to delete selected notifications.');
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  /// Deletes every notification the user currently has, regardless of read
  /// state. Firestore batches cap at 500 writes, so large inboxes are
  /// chunked into multiple batches.
  Future<void> _deleteAll(List<AppNotification> notifications) async {
    if (_currentUid.isEmpty || notifications.isEmpty) return;

    final confirmed = await _confirmDelete(
      title: 'Delete all notifications?',
      message: 'This will permanently delete all ${notifications.length} '
          'notifications. This can\'t be undone.',
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      const chunkSize = 450;
      for (var i = 0; i < notifications.length; i += chunkSize) {
        final chunk = notifications.skip(i).take(chunkSize);
        final batch = FirebaseFirestore.instance.batch();
        for (final n in chunk) {
          batch.delete(
            FirebaseFirestore.instance
                .collection('users')
                .doc(_currentUid)
                .collection('notifications')
                .doc(n.notificationId),
          );
        }
        await batch.commit();
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar('Failed to delete all notifications.');
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  /// Shared confirmation dialog for both delete actions.
  Future<bool?> _confirmDelete({
    required String title,
    required String message,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            color: AppColors.onSurface,
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: AppColors.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Delete',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onTileTap(AppNotification notification) async {
    // 1. Mark as read (fire-and-forget; UI updates via stream)
    await _markRead(notification.notificationId);

    if (!mounted) return;

    // 2. Handle by notification type
    if (notification.type == 'profile_viewed' ||
        notification.type == 'new_follower') {
      // Navigate to the other user's public profile only if we have a valid
      // UID. suppressViewNotification: true prevents PublicProfileScreen
      // from firing another profile_viewed notification back at them, which
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

    // 3. new_shared_deck / deck_cloned — check whether the deck still exists
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
                      ValueListenableBuilder<bool>(
                        valueListenable: _selectionMode,
                        builder: (context, selMode, _) =>
                            ValueListenableBuilder<Set<String>>(
                          valueListenable: _selectedIds,
                          builder: (context, selIds, _) => _NotificationTopBar(
                            notifications: const [],
                            isMarkingAll: false,
                            onMarkAllRead: null,
                            onBack: () => Navigator.of(context).pop(),
                            selectionMode: selMode,
                            selectedCount: selIds.length,
                            isDeleting: _isDeleting,
                            onDeleteAll: null,
                            onDeleteSelected: null,
                            onCancelSelection: null,
                          ),
                        ),
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
                            ValueListenableBuilder<bool>(
                              valueListenable: _selectionMode,
                              builder: (context, selMode, _) =>
                                  ValueListenableBuilder<Set<String>>(
                                valueListenable: _selectedIds,
                                builder: (context, selIds, _) =>
                                    _NotificationTopBar(
                                  notifications: const [],
                                  isMarkingAll: false,
                                  onMarkAllRead: null,
                                  onBack: () => Navigator.of(context).pop(),
                                  selectionMode: selMode,
                                  selectedCount: selIds.length,
                                  isDeleting: _isDeleting,
                                  onDeleteAll: null,
                                  onDeleteSelected: null,
                                  onCancelSelection: null,
                                ),
                              ),
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

                      // The Column + top-bar + list are wrapped in a
                      // ValueListenableBuilder so selection changes only
                      // rebuild this subtree — not the StreamBuilder.
                      return ValueListenableBuilder<bool>(
                        valueListenable: _selectionMode,
                        builder: (context, selMode, _) =>
                            ValueListenableBuilder<Set<String>>(
                          valueListenable: _selectedIds,
                          builder: (context, selIds, _) {
                            return Column(
                              children: [
                                _NotificationTopBar(
                                  notifications: notifications,
                                  isMarkingAll: _isMarkingAll,
                                  onMarkAllRead: () =>
                                      _markAllRead(notifications),
                                  onBack: () => Navigator.of(context).pop(),
                                  selectionMode: selMode,
                                  selectedCount: selIds.length,
                                  isDeleting: _isDeleting,
                                  onDeleteAll: notifications.isEmpty
                                      ? null
                                      : () => _deleteAll(notifications),
                                  onDeleteSelected:
                                      selIds.isEmpty ? null : _deleteSelected,
                                  onCancelSelection: _exitSelectionMode,
                                ),
                                Expanded(
                                  child: notifications.isEmpty
                                      ? _buildEmptyState()
                                      : _buildList(
                                          notifications, selMode, selIds),
                                ),
                              ],
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ── Notification list ─────────────────────────────────────────────────────

  Widget _buildList(
      List<AppNotification> notifications, bool selMode, Set<String> selIds) {
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
      itemCount: notifications.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final notification = notifications[index];
        final id = notification.notificationId;
        return NotificationTile(
          key: ValueKey(id),
          notification: notification,
          selectionMode: selMode,
          selected: selIds.contains(id),
          onTap: selMode
              ? () => _toggleSelected(id)
              : () => _onTileTap(notification),
          onLongPress: selMode
              ? () => _toggleSelected(id)
              : () => _enterSelectionMode(id),
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
              'When someone follows you, clones your deck, or shares a new one, you\'ll see it here.',
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
    required this.selectionMode,
    required this.selectedCount,
    required this.isDeleting,
    required this.onDeleteAll,
    required this.onDeleteSelected,
    required this.onCancelSelection,
  });

  final List<AppNotification> notifications;
  final bool isMarkingAll;

  /// Null when there are no notifications (hides the action button).
  final VoidCallback? onMarkAllRead;
  final VoidCallback onBack;

  /// Whether the list is currently in long-press selection mode.
  final bool selectionMode;
  final int selectedCount;
  final bool isDeleting;

  /// Null when there's nothing to delete (hides the button).
  final VoidCallback? onDeleteAll;

  /// Null while nothing is checked (selection mode only).
  final VoidCallback? onDeleteSelected;

  /// Exits selection mode without deleting anything.
  final VoidCallback? onCancelSelection;

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
              // ── Back button (or close, while selecting) ───────────────────
              IconButton(
                onPressed: selectionMode ? onCancelSelection : onBack,
                icon: Icon(
                  selectionMode
                      ? Icons.close_rounded
                      : Icons.arrow_back_rounded,
                  color: AppColors.onSurface,
                ),
              ),

              // ── Title + badge ───────────────────────────────────────────────
              Expanded(
                child: selectionMode
                    ? Text(
                        '$selectedCount selected',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onSurface,
                          letterSpacing: -0.3,
                        ),
                      )
                    : Row(
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

              // ── Mark all as read — only shown outside selection mode ───────
              if (!selectionMode && onMarkAllRead != null && hasUnread)
                isMarkingAll
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
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
                            horizontal: 10,
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

              // ── Dynamic delete button ───────────────────────────────────────
              // Same slot, same placement, always. What it says and what it
              // does flips depending on whether selection mode is active:
              //   • inactive → "Delete All"        → deletes every notification
              //   • active   → "Delete (n)"         → deletes only the checked ones
              _DynamicDeleteButton(
                selectionMode: selectionMode,
                selectedCount: selectedCount,
                isDeleting: isDeleting,
                onDeleteAll: onDeleteAll,
                onDeleteSelected: onDeleteSelected,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DYNAMIC DELETE BUTTON
//
// Occupies one fixed slot in the top bar. Swaps label and behavior based on
// whether selection mode is currently active — never moves, never duplicates.
// ─────────────────────────────────────────────────────────────────────────────

class _DynamicDeleteButton extends StatelessWidget {
  const _DynamicDeleteButton({
    required this.selectionMode,
    required this.selectedCount,
    required this.isDeleting,
    required this.onDeleteAll,
    required this.onDeleteSelected,
  });

  final bool selectionMode;
  final int selectedCount;
  final bool isDeleting;
  final VoidCallback? onDeleteAll;
  final VoidCallback? onDeleteSelected;

  @override
  Widget build(BuildContext context) {
    if (isDeleting) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            color: AppColors.error,
            strokeWidth: 2,
          ),
        ),
      );
    }

    final label = selectionMode ? 'Delete ($selectedCount)' : 'Delete All';
    final onPressed = selectionMode ? onDeleteSelected : onDeleteAll;

    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.error,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      icon: const Icon(Icons.delete_outline_rounded, size: 17),
      label: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.error,
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
