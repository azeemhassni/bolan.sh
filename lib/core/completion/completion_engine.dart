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

/// Generates shell completions using Dart's own filesystem APIs for
/// file/directory completion, and the shell for command completion.
///
/// This avoids fragile shell subprocess scripts for path completion
/// and gives reliable cross-shell results.
class CompletionEngine {
  final String _shell;

  CompletionEngine({String? shell})
      : _shell = shell ?? Platform.environment['SHELL'] ?? '/bin/bash';

  /// Generates completions for [input] at [cursorPos] in [cwd].
  Future<CompletionResult> complete(
    String input,
    int cursorPos,
    String cwd,
  ) async {
    if (input.isEmpty) return _empty(cursorPos);

    final textUpToCursor = input.substring(0, cursorPos);
    final words = textUpToCursor.split(RegExp(r'\s+'));
    final currentWord = words.isNotEmpty ? words.last : '';
    final replaceStart = cursorPos - currentWord.length;
    final isFirstWord = words.length <= 1 ||
        (words.length == 2 && textUpToCursor.endsWith(currentWord));

    try {
      List<String> items;

      if (isFirstWord && !currentWord.contains('/')) {
        // Command completion
        items = await _completeCommand(currentWord);
      } else {
        // File/path completion
        items = await _completePath(currentWord, cwd);
      }

      return CompletionResult(
        items: items,
        prefix: currentWord,
        replaceStart: replaceStart,
        replaceEnd: cursorPos,
      );
    } on Exception {
      return _empty(cursorPos);
    }
  }

  /// Completes file and directory paths using Dart IO.
  Future<List<String>> _completePath(String partial, String cwd) async {
    // Expand ~ to home directory
    var expanded = partial;
    final home = Platform.environment['HOME'] ?? '';
    if (expanded.startsWith('~')) {
      expanded = expanded.replaceFirst('~', home);
    }

    // Resolve relative to cwd
    String dirPath;
    String namePrefix;

    if (expanded.contains('/')) {
      final lastSlash = expanded.lastIndexOf('/');
      dirPath = expanded.substring(0, lastSlash + 1);
      namePrefix = expanded.substring(lastSlash + 1);
    } else {
      dirPath = cwd;
      namePrefix = expanded;
    }

    // Resolve relative paths
    if (!dirPath.startsWith('/')) {
      dirPath = '$cwd/$dirPath';
    }

    final dir = Directory(dirPath);
    if (!await dir.exists()) return [];

    final items = <String>[];
    try {
      await for (final entity in dir.list()) {
        final name = entity.path.split('/').last;
        if (name.startsWith('.') && !namePrefix.startsWith('.')) continue;
        if (!name.toLowerCase().startsWith(namePrefix.toLowerCase())) continue;

        // Build the completion string matching the user's input style
        String completion;
        if (partial.contains('/')) {
          final prefix = partial.substring(0, partial.lastIndexOf('/') + 1);
          completion = '$prefix$name';
        } else {
          completion = name;
        }

        if (entity is Directory) {
          completion = '$completion/';
        }

        items.add(completion);
      }
    } on FileSystemException {
      return [];
    }

    items.sort();
    return items;
  }

  /// Completes command names from PATH.
  Future<List<String>> _completeCommand(String partial) async {
    if (partial.isEmpty) return [];

    final items = <String>{};
    final pathDirs = Platform.environment['PATH']?.split(':') ?? [];

    for (final dirPath in pathDirs) {
      final dir = Directory(dirPath);
      if (!await dir.exists()) continue;
      try {
        await for (final entity in dir.list()) {
          if (entity is! File) continue;
          final name = entity.path.split('/').last;
          if (name.startsWith(partial)) {
            items.add(name);
          }
        }
      } on FileSystemException {
        continue;
      }
    }

    // Also add shell builtins/aliases via the shell
    try {
      final shellName = _shell.split('/').last;
      final script = shellName == 'zsh'
          ? "print -l \${(k)commands} \${(k)aliases} \${(k)builtins} 2>/dev/null | grep '^$partial' | sort -u"
          : "compgen -abc -- '$partial' 2>/dev/null | sort -u";

      final result = await Process.run(
        _shell,
        ['-c', script],
        environment: Platform.environment,
      ).timeout(const Duration(seconds: 2));

      if (result.exitCode == 0) {
        for (final line in (result.stdout as String).split('\n')) {
          final trimmed = line.trim();
          if (trimmed.isNotEmpty) items.add(trimmed);
        }
      }
    } on Exception {
      // Ignore — we already have PATH completions
    }

    final sorted = items.toList()..sort();
    return sorted;
  }

  CompletionResult _empty(int cursorPos) {
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
