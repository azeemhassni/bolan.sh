/// Detects filesystem paths in terminal output for clickable rendering.
///
/// Matches:
/// - Absolute paths: `/usr/local/bin`, `/home/user/.config`
/// - Home-relative paths: `~/Documents/file.txt`
/// - Relative paths with extensions: `src/main.dart`, `./build/output.js`
/// - Paths with line numbers: `lib/main.dart:42`, `src/app.ts:10:5`
///
/// Avoids false positives by requiring paths to contain at least one `/`
/// and either a file extension or a known directory prefix.
class PathDetector {
  PathDetector._();

  /// Matches filesystem paths in text.
  ///
  /// The regex is intentionally conservative to avoid false positives
  /// from URLs (handled separately by UrlDetector), command flags,
  /// and other /-containing text.
  static final _pathPattern = RegExp(
    r'(?:'
    r'~?/[\w.+\-@][\w.+\-@/]*'              // ~/path or /path
    r'|'
    r'\.{1,2}/[\w.+\-@][\w.+\-@/]*'         // ./path or ../path
    r'|'
    r'[\w.+\-@]+/[\w.+\-@/]*\.[\w]+'        // relative: dir/file.ext
    r')'
    r'(?::(\d+)(?::(\d+))?)?',               // optional :line:col
  );

  /// Finds all file path matches in [text].
  ///
  /// Paths that look like URLs (contain ://) are excluded.
  /// The [cwd] is used to resolve relative paths for existence checks.
  static List<PathMatch> detectPaths(String text) {
    final matches = <PathMatch>[];
    for (final match in _pathPattern.allMatches(text)) {
      final full = match.group(0)!;

      // Skip if this is part of a URL — check a generous window
      // before the match for :// which indicates a URL scheme.
      if (full.contains('://')) continue;
      final windowStart = (match.start - 30).clamp(0, match.start);
      final window = text.substring(windowStart, match.end);
      if (RegExp(r'[a-zA-Z]+://').hasMatch(window)) continue;

      // Skip very short matches that are likely false positives
      // (e.g., a bare `/` or `./`)
      final pathPart = full.replaceFirst(RegExp(r':\d+(:\d+)?$'), '');
      if (pathPart.length < 3) continue;

      // Skip common false positives
      if (_isFalsePositive(pathPart)) continue;

      final line = match.group(1) != null ? int.tryParse(match.group(1)!) : null;
      final col = match.group(2) != null ? int.tryParse(match.group(2)!) : null;

      matches.add(PathMatch(
        start: match.start,
        end: match.end,
        text: full,
        path: pathPart,
        line: line,
        column: col,
      ));
    }
    return matches;
  }

  static bool _isFalsePositive(String path) {
    // Common flag-like patterns: -I/usr, -L/lib
    if (RegExp(r'^-\w').hasMatch(path)) return true;

    // Paths that are just version numbers: /1.2.3
    if (RegExp(r'^/\d+\.\d+').hasMatch(path)) return true;

    return false;
  }
}

/// A filesystem path found in text with its position and metadata.
class PathMatch {
  final int start;
  final int end;
  final String text;
  final String path;
  final int? line;
  final int? column;

  const PathMatch({
    required this.start,
    required this.end,
    required this.text,
    required this.path,
    this.line,
    this.column,
  });
}
