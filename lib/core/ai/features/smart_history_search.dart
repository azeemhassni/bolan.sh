import '../claude_provider.dart';
import '../gemini_provider.dart';
import '../history_sanitizer.dart';

/// AI-powered history search that understands natural language queries.
///
/// "the command I used to deploy" → finds `./deploy.sh production`
/// "how did I install that package" → finds `npm install express`
class SmartHistorySearch {
  final GeminiProvider? _geminiProvider;
  final bool _useClaudeCode;
  final ClaudeProvider _claudeProvider = ClaudeProvider();

  SmartHistorySearch({
    GeminiProvider? geminiProvider,
    bool useClaudeCode = false,
  })  : _geminiProvider = geminiProvider,
        _useClaudeCode = useClaudeCode;

  /// Searches history using AI to understand the intent.
  /// Returns matching commands ranked by relevance.
  Future<List<String>> search({
    required String query,
    required List<String> history,
  }) async {
    if (history.isEmpty) return [];

    // Sanitize before sending
    final sanitized = HistorySanitizer.sanitize(history);
    final prompt = _buildPrompt(query, sanitized);

    String response;
    if (_useClaudeCode) {
      if (!await ClaudeProvider.isAvailable()) return [];
      response = await _claudeProvider.generateContent(prompt);
    } else if (_geminiProvider != null) {
      response = await _geminiProvider.generateContent(prompt);
    } else {
      return [];
    }

    return _parseResponse(response, history);
  }

  String _buildPrompt(String query, List<String> history) {
    final numbered = <String>[];
    for (var i = 0; i < history.length; i++) {
      numbered.add('$i: ${history[i]}');
    }

    return '''
You are a command history search assistant. The user wants to find a command from their history.

History (numbered):
${numbered.join('\n')}

Query: "$query"

Rules:
- Return ONLY the line numbers of matching commands, most relevant first
- Format: one number per line, nothing else
- Return up to 10 matches
- If no match, return: NONE
- Match by intent, not just keywords. "deploy command" should match "./deploy.sh" even if "deploy" isn't in the exact text

Numbers:''';
  }

  List<String> _parseResponse(String response, List<String> originalHistory) {
    final trimmed = response.trim();
    if (trimmed == 'NONE' || trimmed.isEmpty) return [];

    final results = <String>[];
    for (final line in trimmed.split('\n')) {
      final num = int.tryParse(line.trim());
      if (num != null && num >= 0 && num < originalHistory.length) {
        final cmd = originalHistory[num];
        if (!results.contains(cmd)) results.add(cmd);
      }
    }
    return results;
  }

  /// Returns true if the query looks like natural language
  /// (worth sending to AI instead of simple string match).
  static bool isNaturalLanguage(String query) {
    if (query.length < 8) return false;
    // Contains multiple words and doesn't look like a command
    final words = query.trim().split(RegExp(r'\s+'));
    if (words.length < 3) return false;
    // Contains question-like words
    const nlWords = {
      'the', 'that', 'which', 'how', 'what', 'when', 'where',
      'find', 'show', 'used', 'did', 'was', 'command', 'last',
      'recently', 'yesterday', 'before', 'after', 'to', 'for',
      'with', 'my', 'i',
    };
    final lower = words.map((w) => w.toLowerCase()).toSet();
    return lower.intersection(nlWords).length >= 2;
  }
}
