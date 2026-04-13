import 'dart:io';
import 'dart:math';

import '../ai_provider.dart';

/// Explains command errors and suggests fixes using AI.
///
/// Before sending to the LLM, performs fuzzy matching against known
/// commands in $PATH to detect likely typos. This hint is injected
/// into the prompt so even small models can identify misspellings.
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
    final typoHint = await _detectTypo(command, output);
    final prompt =
        _buildPrompt(command, output, exitCode, cwd, shellName, typoHint);
    return _provider.generateContent(prompt);
  }

  /// Builds a hint about the error by:
  /// 1. Extracting "did you mean" suggestions from the error output
  /// 2. Fuzzy-matching the binary name against $PATH for typos
  Future<String?> _detectTypo(String command, String output) async {
    // 1. Check if the tool already suggests a correction
    final suggestion = _extractSuggestion(output);
    if (suggestion != null) return suggestion;

    // 2. Fuzzy-match the binary name against PATH
    final words = command.trim().split(RegExp(r'\s+'));
    if (words.isEmpty) return null;
    final typed = words.first;

    final binaries = <String>{};
    final pathDirs = Platform.environment['PATH']?.split(':') ?? [];
    for (final dirPath in pathDirs) {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) continue;
      try {
        for (final entity in dir.listSync()) {
          if (entity is File) {
            binaries.add(entity.path.split('/').last);
          }
        }
      } on FileSystemException {
        continue;
      }
    }

    // If binary exists in PATH, it's not a binary typo
    if (binaries.contains(typed)) return null;

    // Find closest match
    String? bestMatch;
    var bestDistance = 999;
    final maxDistance = (typed.length * 0.4).ceil().clamp(1, 3);

    for (final binary in binaries) {
      final dist = _editDistance(typed.toLowerCase(), binary.toLowerCase());
      if (dist < bestDistance && dist <= maxDistance) {
        bestDistance = dist;
        bestMatch = binary;
      }
    }

    if (bestMatch != null) {
      final corrected = [bestMatch, ...words.sublist(1)].join(' ');
      return "Note: '$command' closely resembles the known command "
          "'$corrected'. The user likely mistyped '$bestMatch' as '$typed'.";
    }

    return null;
  }

  /// Extracts correction suggestions that tools embed in their error output.
  ///
  /// Many CLIs already detect typos:
  /// - git: "Did you mean this? status"
  /// - npm: "Did you mean one of these? install"
  /// - cargo: "Did you mean `build`?"
  static String? _extractSuggestion(String output) {
    // "Did you mean" pattern (git, npm, cargo, etc.)
    final didYouMean = RegExp(
      r'''(?:did you mean|perhaps you meant|maybe you meant|similar command)[:\s]*[`'"]*(\S+)[`'"]*''',
      caseSensitive: false,
    );
    final match = didYouMean.firstMatch(output);
    if (match != null) {
      final suggested = match.group(1)!;
      return 'Note: the tool itself suggests the correct command is '
          "'$suggested'. The user likely made a typo.";
    }

    // "is not a X command" pattern — the error is already descriptive
    // enough for the LLM, no extra hint needed
    return null;
  }

  /// Levenshtein edit distance between two strings.
  static int _editDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final matrix = List.generate(
      a.length + 1,
      (i) => List.generate(b.length + 1, (j) => i == 0 ? j : (j == 0 ? i : 0)),
    );

    for (var i = 1; i <= a.length; i++) {
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce(min);
      }
    }

    return matrix[a.length][b.length];
  }

  String _buildPrompt(
    String command,
    String output,
    int exitCode,
    String cwd,
    String shellName,
    String? typoHint,
  ) {
    final os = Platform.operatingSystem;
    final trimmedOutput = output.length > 3000
        ? '${output.substring(0, 3000)}\n... (truncated)'
        : output;

    final hint = typoHint != null ? '\n$typoHint\n' : '';

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
$hint
Respond concisely:
1. **Why it failed** — one sentence explaining the error
2. **Fix** — the corrected command or steps to resolve

Keep it short and actionable. No markdown code fences.''';
  }

}
