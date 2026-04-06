import 'dart:io';

import '../ai_provider.dart';

/// Explains command errors and suggests fixes using AI.
class ErrorExplainer {
  final AiProvider _provider;

  ErrorExplainer({required AiProvider provider}) : _provider = provider;

  /// Explains why a command failed and suggests a fix.
  Future<String> explain({
    required String command,
    required String output,
    required int exitCode,
    required String cwd,
    required String shellName,
  }) async {
    final prompt = _buildPrompt(command, output, exitCode, cwd, shellName);
    return _provider.generateContent(prompt);
  }

  String _buildPrompt(
    String command,
    String output,
    int exitCode,
    String cwd,
    String shellName,
  ) {
    final os = Platform.operatingSystem;
    final trimmedOutput = output.length > 3000
        ? '${output.substring(0, 3000)}\n... (truncated)'
        : output;

    return '''
You are a terminal error assistant. A command failed and the user needs help understanding why and how to fix it.

Context:
- Shell: $shellName
- OS: $os
- Directory: $cwd
- Exit code: $exitCode

Command: $command

Output:
$trimmedOutput

Respond concisely:
1. **Why it failed** — one sentence explaining the error
2. **Fix** — the corrected command or steps to resolve

Keep it short and actionable. No markdown code fences.''';
  }
}
