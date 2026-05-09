// ─────────────────────────────────────────────────────────────────────────────
// DECK SEARCH ENGINE
//
// Lightweight, generic in-memory search index for deck lists.
//
// [T] is the item type — e.g. QueryDocumentSnapshot<Map<String, dynamic>> for
// the Deck Library, or PublicDeckSummary for Deck Discovery.
//
// The caller supplies a keyExtractor that concatenates all searchable fields
// into a single string.  The engine lowercases that string once at index-build
// time so that query evaluation never transforms source data per keystroke.
//
// TYPICAL LIFECYCLE
// ─────────────────
//   rebuild()  → called when the source list is replaced (first load, tag
//                change, Firestore stream update)
//   extend()   → called when a new pagination page is appended
//   query()    → called on every debounced keystroke; O(n) single-pass scan
//   snapshot() → called before compute() to produce an isolate-safe copy
//
// ISOLATE BOUNDARY
// ────────────────
//   QueryDocumentSnapshot objects cannot cross isolate boundaries.  When the
//   index contains ≥ 500 entries the caller should:
//     1. Call snapshot() to get a plain List<({String searchKey, …})>.
//     2. Pass that list + the keyword to compute(runIsolateQuery, params).
//     3. Use the returned List<int> as indices into the original deck list.
// ─────────────────────────────────────────────────────────────────────────────

// ── Internal index entry ─────────────────────────────────────────────────────

class _IndexEntry<T> {
  const _IndexEntry(this.item, this.searchKey);

  /// The original item (deck snapshot or summary object).
  final T item;

  /// Pre-lowercased concatenation of all searchable fields for this item.
  final String searchKey;
}

// ── DeckSearchEngine ─────────────────────────────────────────────────────────

/// Generic in-memory search engine for deck lists.
///
/// Maintains a pre-lowercased index alongside the raw item list so that
/// [query] requires no per-call string transformation on source data.
class DeckSearchEngine<T> {
  List<_IndexEntry<T>> _index = [];

  // ── Index management ──────────────────────────────────────────────────────

  /// Replaces the entire index with [items].
  ///
  /// Call this when the source list is replaced — e.g. on first load, a
  /// Firestore stream update, or a tag-filter change that triggers a reload.
  void rebuild(List<T> items, String Function(T) keyExtractor) {
    _index = items
        .map((item) => _IndexEntry<T>(item, keyExtractor(item).toLowerCase()))
        .toList();
  }

  /// Appends [items] to the existing index without discarding prior entries.
  ///
  /// Call this when a new pagination page arrives so that earlier pages remain
  /// searchable.
  void extend(List<T> items, String Function(T) keyExtractor) {
    for (final item in items) {
      _index.add(_IndexEntry<T>(item, keyExtractor(item).toLowerCase()));
    }
  }

  // ── Query ─────────────────────────────────────────────────────────────────

  /// Returns all items whose search key contains [keyword] (case-insensitive).
  ///
  /// If [tagFilter] is non-null, only items where [tagOf](item) == [tagFilter]
  /// are included.  Both predicates are evaluated in a single pass.
  ///
  /// When [keyword] is empty **and** [tagFilter] is null, all indexed items
  /// are returned in insertion order (O(n) copy).
  List<T> query(
    String keyword, {
    String? tagFilter,
    String Function(T)? tagOf,
  }) {
    // Fast path — no filtering needed.
    if (keyword.isEmpty && tagFilter == null) {
      return _index.map((e) => e.item).toList();
    }

    final results = <T>[];
    final lowerKeyword = keyword.toLowerCase();

    for (final entry in _index) {
      // Keyword predicate — skip when keyword is empty (always passes).
      if (keyword.isNotEmpty && !entry.searchKey.contains(lowerKeyword)) {
        continue;
      }

      // Tag predicate — skip when tagFilter is null (always passes).
      if (tagFilter != null) {
        final tag = tagOf != null ? tagOf(entry.item) : '';
        if (tag != tagFilter) continue;
      }

      results.add(entry.item);
    }

    return results;
  }

  // ── Isolate support ───────────────────────────────────────────────────────

  /// Returns a serialisable snapshot of the index for use with [compute()].
  ///
  /// Each record contains:
  /// - [searchKey] — the pre-lowercased search string.
  /// - [tag]       — the tag value for this item; defaults to `''` when
  ///                 [tagOf] is null.
  /// - [idx]       — the position of this entry in the index, used by the
  ///                 caller to reconstruct the result list from the original
  ///                 deck list after [runIsolateQuery] returns.
  List<({String searchKey, String tag, int idx})> snapshot({
    String Function(T)? tagOf,
  }) {
    return [
      for (var i = 0; i < _index.length; i++)
        (
          searchKey: _index[i].searchKey,
          tag: tagOf != null ? tagOf(_index[i].item) : '',
          idx: i,
        ),
    ];
  }

  // ── Accessors ─────────────────────────────────────────────────────────────

  /// Number of items currently in the index.
  int get length => _index.length;
}

// ── Top-level isolate function ────────────────────────────────────────────────

/// Evaluates a query against a serialisable index snapshot.
///
/// Designed to be passed directly to Flutter's [compute()]:
/// ```dart
/// final indices = await compute(runIsolateQuery, (
///   index: engine.snapshot(tagOf: tagOf),
///   keyword: keyword,
///   tagFilter: activeTag,
/// ));
/// ```
///
/// Returns a [List<int>] of matching [idx] values.  The caller uses these
/// indices to reconstruct the filtered list from the original deck list,
/// avoiding the need to pass non-serialisable objects across isolate
/// boundaries.
List<int> runIsolateQuery(
  ({
    List<({String searchKey, String tag, int idx})> index,
    String keyword,
    String? tagFilter,
  }) params,
) {
  final keyword = params.keyword.toLowerCase();
  final tagFilter = params.tagFilter;
  final results = <int>[];

  for (final entry in params.index) {
    if (keyword.isNotEmpty && !entry.searchKey.contains(keyword)) {
      continue;
    }
    if (tagFilter != null && entry.tag != tagFilter) {
      continue;
    }
    results.add(entry.idx);
  }

  return results;
}
