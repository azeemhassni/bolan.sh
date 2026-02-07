import 'dart:io';

import '../claude_provider.dart';
import '../gemini_provider.dart';

/// Converts natural language queries to shell commands using AI.
///
/// Tries Claude Code CLI first (no API key needed), falls back to Gemini.
class NlpToCommand {
  final GeminiProvider? _geminiProvider;
  final bool _useClaudeCode;
  final ClaudeProvider _claudeProvider = ClaudeProvider();

  NlpToCommand({GeminiProvider? geminiProvider, bool useClaudeCode = false})
      : _geminiProvider = geminiProvider,
        _useClaudeCode = useClaudeCode;

  /// Converts a natural language [query] to a shell command.
  Future<String> convert({
    required String query,
    required String cwd,
    required String shellName,
    required List<String> recentCommands,
  }) async {
    final prompt = _buildPrompt(query, cwd, shellName, recentCommands);

    // Use Claude Code if configured
    if (_useClaudeCode) {
      if (await ClaudeProvider.isAvailable()) {
        final response = await _claudeProvider.generateContent(prompt);
        return _cleanResponse(response);
      }
      throw Exception('Claude Code is not installed. Install it or switch to API mode in Settings.');
    }

    // Use Gemini/other API provider
    if (_geminiProvider == null) {
      throw Exception('No AI provider available. Install Claude Code or set a Gemini API key.');
    }
    final response = await _geminiProvider.generateContent(prompt);
    return _cleanResponse(response);
  }

  String _buildPrompt(
    String query,
    String cwd,
    String shellName,
    List<String> recentCommands,
  ) {
    final os = Platform.operatingSystem;
    final recent = recentCommands.isNotEmpty
        ? recentCommands.take(10).join('\n')
        : '(none)';

    return '''
You are a shell command translator. Convert the natural language query into a single shell command.

Context:
- Shell: $shellName
- OS: $os
- Current directory: $cwd
- Recent commands:
$recent

Rules:
- Respond with ONLY the shell command, nothing else
- No explanations, no markdown, no code fences, no comments
- If multiple commands are needed, chain them with && or ;
- Use commands appropriate for the given OS and shell
- Prefer common, portable commands when possible

Query: $query''';
  }

  /// Strips accidental markdown, code fences, prompt characters, etc.
  String _cleanResponse(String response) {
    var cmd = response.trim();

    // Strip markdown code fences (```bash ... ```)
    if (cmd.contains('```')) {
      final lines = cmd.split('\n');
      final inner = <String>[];
      var inFence = false;
      for (final line in lines) {
        if (line.trim().startsWith('```')) {
          inFence = !inFence;
          continue;
        }
        if (inFence) {
          inner.add(line);
        }
      }
      // If we extracted content from fences, use it
      if (inner.isNotEmpty) {
        cmd = inner.join('\n').trim();
      }
    }

    // Strip leading $ or > prompt characters (per line)
    final lines = cmd.split('\n');
    final cleaned = lines.map((l) {
      var s = l;
      if (s.startsWith(r'$ ')) s = s.substring(2);
      if (s.startsWith('> ')) s = s.substring(2);
      return s;
    }).join('\n');

    return cleaned.trim();
  }
}
