// ─────────────────────────────────────────────────────────────────────────────
// SOCIAL ROUTE ARGS
//
// Typed argument objects passed via settings.arguments when navigating to
// social screens.  Mirrors the pattern used by EditDeckArgs in
// edit_deck_screen.dart.
// ─────────────────────────────────────────────────────────────────────────────

/// Arguments for AppRoutes.sharedDeckDetail.
class SharedDeckDetailArgs {
  const SharedDeckDetailArgs({
    required this.deckId,
    required this.ownerUid,
  });

  final String deckId;
  final String ownerUid;
}

/// Arguments for AppRoutes.publicProfile.
class PublicProfileArgs {
  const PublicProfileArgs({
    required this.targetUid,
    this.suppressViewNotification = false,
  });

  final String targetUid;

  /// When true, the PublicProfileScreen will NOT fire a "profile_viewed"
  /// notification to the owner. Set to true when navigating here from a
  /// profile_viewed notification tile, to break the infinite ping-pong loop
  /// where viewing the notifier's profile sends them another notification.
  final bool suppressViewNotification;
}

/// Arguments for AppRoutes.followList.
///
/// Drives the tabbed Followers / Following screen for [targetUid]. The tab
/// the screen opens on is controlled by [initialTab].
class FollowListArgs {
  const FollowListArgs({
    required this.targetUid,
    this.initialTab = FollowListTab.followers,
  });

  final String targetUid;
  final FollowListTab initialTab;
}

enum FollowListTab { followers, following }
