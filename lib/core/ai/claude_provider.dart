import 'dart:io';

/// AI provider that uses the Claude Code CLI (`claude -p`) for responses.
///
/// No API key needed — Claude Code handles its own authentication.
/// Falls back gracefully if `claude` is not installed.
class ClaudeProvider {
  /// Checks if the `claude` CLI is available in PATH.
  static Future<bool> isAvailable() async {
    try {
      final result = await Process.run('which', ['claude']);
      return result.exitCode == 0;
    } on Exception {
      return false;
    }
  }

  /// Sends a prompt to Claude Code and returns the response.
  ///
  /// Uses `claude -p` (print mode) for non-interactive single-shot queries.
  Future<String> generateContent(String prompt) async {
    final result = await Process.run(
      'claude',
      ['-p', prompt],
      environment: Platform.environment,
    ).timeout(const Duration(seconds: 30));

    if (result.exitCode != 0) {
      final error = (result.stderr as String).trim();
      throw Exception('Claude Code error: $error');
    }

    return (result.stdout as String).trim();
  }
}
