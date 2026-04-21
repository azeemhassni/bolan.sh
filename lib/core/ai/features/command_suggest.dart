import 'dart:io';

import '../ai_provider.dart';

/// Suggests the next command based on context using AI.
///
/// Triggered after a command completes. Uses recent command history,
/// current directory, git status, and the last command's output to
/// predict what the user likely wants to run next.
class CommandSuggestor {
  final AiProvider _provider;

  CommandSuggestor({required AiProvider provider}) : _provider = provider;

  /// Suggests the next command based on context.
  /// Returns null if no suggestion is appropriate.
  Future<String?> suggest({
    required String lastCommand,
    required String lastOutput,
    required int lastExitCode,
    required String cwd,
    required String shellName,
    required List<String> recentHistory,
    String? gitBranch,
    bool gitDirty = false,
  }) async {
    final prompt = _buildPrompt(
      lastCommand, lastOutput, lastExitCode, cwd,
      shellName, recentHistory, gitBranch, gitDirty,
    );

    final response = await _provider.generateContent(prompt);
    return _cleanResponse(response);
  }

  String _buildPrompt(
    String lastCommand,
    String lastOutput,
    int lastExitCode,
    String cwd,
    String shellName,
    List<String> recentHistory,
    String? gitBranch,
    bool gitDirty,
  ) {
    final os = Platform.operatingSystem;
    final history = recentHistory.isNotEmpty
        ? recentHistory.take(20).join('\n')
        : '(none)';
    final trimmedOutput = lastOutput.length > 2000
        ? '${lastOutput.substring(0, 2000)}\n... (truncated)'
        : lastOutput;

    final gitContext = gitBranch != null
        ? 'Git branch: $gitBranch${gitDirty ? " (dirty)" : " (clean)"}'
        : 'Not a git repository';

    return '''
You are a terminal command predictor. Based on the context, predict the SINGLE most likely next command the user will type.

Context:
- Shell: $shellName
- OS: $os
- Directory: $cwd
- $gitContext
- Last command exit code: $lastExitCode

Recent command history (newest last):
$history

Last command: $lastCommand
Last output:
$trimmedOutput

Rules:
- Respond with EXACTLY ONE command on a single line
- No explanations, no markdown, no alternatives, no numbering
- Do NOT list multiple commands or options
- If the last command was a git commit, suggest git push with the correct branch
- If the last command failed, suggest the corrected version
- If no good prediction exists, respond with exactly: NONE
- Be specific: use actual file names, branch names, paths from the context

Command:''';
  }

  String? _cleanResponse(String response) {
    var cmd = response.trim();

    if (cmd.isEmpty ||
        cmd == 'NONE' ||
        cmd.toLowerCase() == 'none' ||
        cmd.toLowerCase().startsWith('none')) {
      return null;
    }

    // Strip code fences — extract only the first fenced block.
    if (cmd.contains('```')) {
      final lines = cmd.split('\n');
      final inner = <String>[];
      var inFence = false;
      for (final line in lines) {
        if (line.trim().startsWith('```')) {
          if (inFence) break; // only take the first block
          inFence = true;
          continue;
        }
        if (inFence) inner.add(line);
      }
      if (inner.isNotEmpty) cmd = inner.first.trim();
    }

    // Strip prompt prefixes.
    if (cmd.startsWith(r'$ ')) cmd = cmd.substring(2);
    if (cmd.startsWith('> ')) cmd = cmd.substring(2);

    // Take only the FIRST line — we want a single command, not a script.
    final firstLine = cmd.split('\n').first.trim();
    if (firstLine.isEmpty) return null;

    // Reject if the model returned conversational text instead of a command.
    if (firstLine.contains('Here is') ||
        firstLine.contains('I suggest') ||
        firstLine.contains('You could') ||
        firstLine.contains('The next') ||
        firstLine.startsWith('Based on')) {
      return null;
    }

    // Reject overly long suggestions (likely explanations, not commands).
    if (firstLine.length > 200) return null;

    return firstLine;
  }
}
