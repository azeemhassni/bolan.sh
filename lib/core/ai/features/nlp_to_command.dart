import 'dart:io';

import '../gemini_provider.dart';

/// Converts natural language queries to shell commands using Gemini.
class NlpToCommand {
  final GeminiProvider _provider;

  NlpToCommand(this._provider);

  /// Converts a natural language [query] to a shell command.
  Future<String> convert({
    required String query,
    required String cwd,
    required String shellName,
    required List<String> recentCommands,
  }) async {
    final prompt = _buildPrompt(query, cwd, shellName, recentCommands);
    final response = await _provider.generateContent(prompt);
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

    // Strip markdown code fences
    if (cmd.startsWith('```')) {
      final lines = cmd.split('\n');
      // Remove first line (```bash or ```) and last line (```)
      final inner = <String>[];
      for (var i = 1; i < lines.length; i++) {
        if (lines[i].trim() == '```') continue;
        inner.add(lines[i]);
      }
      cmd = inner.join('\n').trim();
    }

    // Strip leading $ or > prompt characters
    if (cmd.startsWith(r'$ ')) cmd = cmd.substring(2);
    if (cmd.startsWith('> ')) cmd = cmd.substring(2);

    return cmd.trim();
  }
}
