/// Detects URLs in plain text for clickable link rendering.
///
/// Matches:
/// - `http://` and `https://` URLs
/// - `ftp://` and `file://` URLs
/// - Bare domains with common TLDs (e.g., `github.com/foo`)
class UrlDetector {
  UrlDetector._();

  /// Matches URLs including scheme-less domains with common TLDs.
  static final _urlPattern = RegExp(
    r'(?:https?://|ftp://|file://)'       // scheme
    r'[^\s<>\[\]{}|\\^`"]*'               // URL body (no whitespace or brackets)
    r'[^\s<>\[\]{}|\\^`".,;:!?\)\]\}]'    // don't end on punctuation
    r'|'
    r'(?:[\w-]+\.)+(?:com|org|net|io|dev|sh|app|co|me|info|xyz|ai)\b' // bare domain
    r'(?:/[^\s<>\[\]{}|\\^`"]*'            // optional path
    r'[^\s<>\[\]{}|\\^`".,;:!?\)\]\}])?',  // don't end on punctuation
    caseSensitive: false,
  );

  /// Finds all URL matches in [text].
  static List<UrlMatch> detectUrls(String text) {
    final matches = <UrlMatch>[];
    for (final match in _urlPattern.allMatches(text)) {
      final url = match.group(0)!;
      // Add scheme to bare domains
      final uri = url.startsWith(RegExp(r'https?://|ftp://|file://'))
          ? url
          : 'https://$url';
      matches.add(UrlMatch(
        start: match.start,
        end: match.end,
        text: url,
        uri: uri,
      ));
    }
    return matches;
  }
}

/// A URL found in text with its position and resolved URI.
class UrlMatch {
  final int start;
  final int end;
  final String text;
  final String uri;

  const UrlMatch({
    required this.start,
    required this.end,
    required this.text,
    required this.uri,
  });
}
