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
  });

  final String targetUid;
}
