import 'app_action.dart';

/// Lightweight fuzzy search for command palette actions.
///
/// Scores each action by how well the query matches its label and keywords.
/// Higher scores indicate better matches. Returns results sorted by score.
class FuzzySearch {
  FuzzySearch._();

  /// Returns actions matching [query], sorted by relevance (best first).
  static List<AppAction> search(List<AppAction> actions, String query) {
    if (query.isEmpty) return actions;

    final lower = query.toLowerCase();
    final scored = <_ScoredAction>[];

    for (final action in actions) {
      final score = _score(action, lower);
      if (score > 0) {
        scored.add(_ScoredAction(action, score));
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.map((s) => s.action).toList();
  }

  static int _score(AppAction action, String query) {
    final label = action.label.toLowerCase();

    // Exact match
    if (label == query) return 100;

    // Starts with query
    if (label.startsWith(query)) return 80;

    // Contains query as substring
    if (label.contains(query)) return 60;

    // Word boundary match (e.g., "nt" matches "New Tab")
    final words = label.split(RegExp(r'\s+'));
    final queryChars = query.split('');
    var charIndex = 0;
    for (final word in words) {
      if (charIndex < queryChars.length &&
          word.startsWith(queryChars[charIndex])) {
        charIndex++;
      }
    }
    if (charIndex == queryChars.length) return 40;

    // Subsequence match (all chars appear in order)
    var seqIndex = 0;
    for (var i = 0; i < label.length && seqIndex < query.length; i++) {
      if (label[i] == query[seqIndex]) seqIndex++;
    }
    if (seqIndex == query.length) return 20;

    // Check keywords
    for (final keyword in action.keywords) {
      final kw = keyword.toLowerCase();
      if (kw.contains(query)) return 30;
    }

    return 0;
  }
}

class _ScoredAction {
  final AppAction action;
  final int score;

  _ScoredAction(this.action, this.score);
}
