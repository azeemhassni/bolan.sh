import 'dart:io';

import '../ai_provider.dart';

/// Converts natural language queries to shell commands using AI.
class NlpToCommand {
  final AiProvider _provider;

  NlpToCommand({required AiProvider provider}) : _provider = provider;

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
- Respond with ONLY the raw shell command, nothing else
- Do NOT wrap output in backticks, markdown, or code fences
- Do NOT add explanations, comments, or formatting of any kind
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
      if (inner.isNotEmpty) {
        cmd = inner.join('\n').trim();
      }
    }

    // Strip inline backticks (e.g., `ls -la`)
    if (cmd.startsWith('`') && cmd.endsWith('`')) {
      cmd = cmd.substring(1, cmd.length - 1);
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
