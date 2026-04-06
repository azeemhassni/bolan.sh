import 'dart:io';

import '../ai_provider.dart';

/// Generates git commit messages from staged changes using AI.
class GitCommitGenerator {
  final AiProvider _provider;

  GitCommitGenerator({required AiProvider provider}) : _provider = provider;

  /// Gets the staged diff and generates a commit message.
  /// Returns null if there are no staged changes.
  Future<String?> generate(String cwd) async {
    final diff = await _getStagedDiff(cwd);
    if (diff.isEmpty) return null;

    final prompt = _buildPrompt(diff);
    final response = await _provider.generateContent(prompt);
    return _cleanResponse(response);
  }

  Future<String> _getStagedDiff(String cwd) async {
    final result = await Process.run(
      'git',
      ['diff', '--staged', '--stat', '--patch'],
      workingDirectory: cwd,
    );
    if (result.exitCode != 0) return '';
    final output = (result.stdout as String).trim();
    if (output.length > 8000) {
      return '${output.substring(0, 8000)}\n... (diff truncated)';
    }
    return output;
  }

  String _buildPrompt(String diff) {
    return '''
You are a git commit message generator. Write a concise, meaningful commit message for the following staged changes.

Rules:
- Use conventional commit format: type(scope): description
- Types: feat, fix, docs, chore, refactor, test, perf, style
- First line max 72 characters
- Add a blank line then a short body (2-3 bullets) if the change is complex
- No markdown, no code fences
- Be specific about what changed, not just "updated files"

Staged diff:
$diff''';
  }

  String _cleanResponse(String response) {
    var msg = response.trim();

    if (msg.contains('```')) {
      final lines = msg.split('\n');
      final inner = <String>[];
      var inFence = false;
      for (final line in lines) {
        if (line.trim().startsWith('```')) {
          inFence = !inFence;
          continue;
        }
        if (inFence) inner.add(line);
      }
      if (inner.isNotEmpty) msg = inner.join('\n').trim();
    }

    if (msg.startsWith('"') && msg.endsWith('"')) {
      msg = msg.substring(1, msg.length - 1);
    }

    return msg.trim();
  }
}
