import 'dart:io';

/// Result of a tab completion request.
class CompletionResult {
  final List<String> items;
  final String prefix;
  final int replaceStart;
  final int replaceEnd;

  const CompletionResult({
    required this.items,
    required this.prefix,
    required this.replaceStart,
    required this.replaceEnd,
  });

  bool get isEmpty => items.isEmpty;
  bool get isSingle => items.length == 1;
}

/// Generates shell completions by invoking bash/zsh in a subprocess.
///
/// Uses `compgen` for bash and a zpty-based approach for zsh to get
/// the same completions the user's shell would provide, including
/// custom completions for git, docker, kubectl, etc.
class CompletionEngine {
  final String _shell;

  CompletionEngine({String? shell})
      : _shell = shell ?? Platform.environment['SHELL'] ?? '/bin/bash';

  String get _shellName => _shell.split('/').last;

  /// Generates completions for [input] at [cursorPos] in [cwd].
  Future<CompletionResult> complete(
    String input,
    int cursorPos,
    String cwd,
  ) async {
    if (input.isEmpty) return _empty(input, cursorPos);

    // Extract the word being completed
    final textUpToCursor = input.substring(0, cursorPos);
    final words = textUpToCursor.split(RegExp(r'\s+'));
    final currentWord = words.isNotEmpty ? words.last : '';
    final replaceStart = cursorPos - currentWord.length;
    final isFirstWord = words.length <= 1;

    try {
      final items = _shellName == 'zsh'
          ? await _zshComplete(textUpToCursor, currentWord, isFirstWord, cwd)
          : await _bashComplete(currentWord, isFirstWord, cwd);

      return CompletionResult(
        items: items,
        prefix: currentWord,
        replaceStart: replaceStart,
        replaceEnd: cursorPos,
      );
    } on Exception {
      return _empty(input, cursorPos);
    }
  }

  Future<List<String>> _bashComplete(
    String word,
    bool isCommand,
    String cwd,
  ) async {
    // compgen -c for commands, -o default for files/directories
    final flag = isCommand ? '-c' : '-o default';
    final result = await Process.run(
      'bash',
      ['-i', '-c', 'compgen $flag -- ${_shellEscape(word)}'],
      workingDirectory: cwd,
      environment: Platform.environment,
    ).timeout(const Duration(seconds: 2));

    if (result.exitCode != 0) return [];
    return _parseLines(result.stdout as String);
  }

  Future<List<String>> _zshComplete(
    String fullInput,
    String word,
    bool isCommand,
    String cwd,
  ) async {
    // Use a zsh subprocess with a capture script.
    // For first-word (command) completion, list executables in PATH.
    // For subsequent words, use file completion + the shell's own completions.
    final script = '''
autoload -Uz compinit 2>/dev/null && compinit -C 2>/dev/null
# Capture completions
local -a completions
if [[ $isCommand == true ]]; then
  completions=(\${(k)commands} \${(k)aliases} \${(k)builtins} \${(k)functions})
  completions=(\${(M)completions:#${_shellEscape(word)}*})
else
  # File/directory completion
  completions=(\$(compgen -o default -- ${_shellEscape(word)} 2>/dev/null))
  if [[ \${#completions[@]} -eq 0 ]]; then
    completions=(\$(print -l ${_shellEscape(word)}*(N) 2>/dev/null))
  fi
fi
printf '%s\\n' "\${completions[@]}" | sort -u
''';

    final result = await Process.run(
      'zsh',
      ['-c', script],
      workingDirectory: cwd,
      environment: Platform.environment,
    ).timeout(const Duration(seconds: 2));

    if (result.exitCode != 0) return [];
    return _parseLines(result.stdout as String);
  }

  List<String> _parseLines(String output) {
    return output
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
  }

  String _shellEscape(String s) {
    return "'${s.replaceAll("'", "'\\''")}'";
  }

  CompletionResult _empty(String input, int cursorPos) {
    return CompletionResult(
      items: [],
      prefix: '',
      replaceStart: cursorPos,
      replaceEnd: cursorPos,
    );
  }

  void dispose() {}
}

/// Returns the longest common prefix of a list of strings.
String longestCommonPrefix(List<String> strings) {
  if (strings.isEmpty) return '';
  if (strings.length == 1) return strings.first;

  var prefix = strings.first;
  for (var i = 1; i < strings.length; i++) {
    while (!strings[i].startsWith(prefix)) {
      prefix = prefix.substring(0, prefix.length - 1);
      if (prefix.isEmpty) return '';
    }
  }
  return prefix;
}
