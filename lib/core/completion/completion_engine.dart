import 'dart:io';

/// Type of a completion item.
enum CompletionType {
  command,
  builtin,
  file,
  directory,
  gitSubcommand,
  gitBranch,
  gitRemote,
  gitTag,
}

/// A single completion candidate with metadata.
class CompletionItem {
  final String text;
  final CompletionType type;
  final String? description;

  const CompletionItem({
    required this.text,
    this.type = CompletionType.command,
    this.description,
  });
}

/// Result of a tab completion request.
class CompletionResult {
  final List<CompletionItem> items;
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

  /// Plain text list for backward compat.
  List<String> get texts => items.map((i) => i.text).toList();
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
    final isFirstWord = words.length <= 1;

    try {
      List<CompletionItem> items;

      if (isFirstWord && !currentWord.contains('/')) {
        items = await _completeCommand(currentWord);
      } else if (words.isNotEmpty && words.first == 'git') {
        items = await _completeGit(words, currentWord, cwd);
        // Fall through to path completion for commands like `git add`
        // where the user is completing a file path.
        if (items.isEmpty && _gitCmdTakesFiles(words)) {
          items = await _completePath(currentWord, cwd);
        }
      } else {
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
  Future<List<CompletionItem>> _completePath(String partial, String cwd) async {
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

    final items = <CompletionItem>[];
    try {
      await for (final entity in dir.list()) {
        final name = entity.path.split('/').last;
        if (name.startsWith('.') && !namePrefix.startsWith('.')) continue;
        if (!name.toLowerCase().startsWith(namePrefix.toLowerCase())) continue;

        String completion;
        if (partial.contains('/')) {
          final prefix = partial.substring(0, partial.lastIndexOf('/') + 1);
          completion = '$prefix$name';
        } else {
          completion = name;
        }

        final isDir = entity is Directory;
        if (isDir) completion = '$completion/';

        items.add(CompletionItem(
          text: completion,
          type: isDir ? CompletionType.directory : CompletionType.file,
        ));
      }
    } on FileSystemException {
      return [];
    }

    items.sort((a, b) => a.text.compareTo(b.text));
    return items;
  }

  /// Completes command names from PATH, identifies builtins.
  Future<List<CompletionItem>> _completeCommand(String partial) async {
    if (partial.isEmpty) return [];

    final pathCommands = <String>{};
    final builtins = <String>{};
    final pathDirs = Platform.environment['PATH']?.split(':') ?? [];

    for (final dirPath in pathDirs) {
      final dir = Directory(dirPath);
      if (!await dir.exists()) continue;
      try {
        await for (final entity in dir.list()) {
          if (entity is! File) continue;
          final name = entity.path.split('/').last;
          if (name.startsWith(partial)) pathCommands.add(name);
        }
      } on FileSystemException {
        continue;
      }
    }

    // Get builtins separately so we can tag them
    try {
      final shellName = _shell.split('/').last;
      final script = shellName == 'zsh'
          ? "print -l \${(k)builtins} 2>/dev/null | grep '^$partial' | sort -u"
          : "compgen -b -- '$partial' 2>/dev/null | sort -u";

      final result = await Process.run(
        _shell,
        ['-c', script],
        environment: Platform.environment,
      ).timeout(const Duration(seconds: 2));

      if (result.exitCode == 0) {
        for (final line in (result.stdout as String).split('\n')) {
          final trimmed = line.trim();
          if (trimmed.isNotEmpty) builtins.add(trimmed);
        }
      }
    } on Exception {
      // Ignore
    }

    // Also get aliases and other commands
    try {
      final shellName = _shell.split('/').last;
      final script = shellName == 'zsh'
          ? "print -l \${(k)commands} \${(k)aliases} 2>/dev/null | grep '^$partial' | sort -u"
          : "compgen -ac -- '$partial' 2>/dev/null | sort -u";

      final result = await Process.run(
        _shell,
        ['-c', script],
        environment: Platform.environment,
      ).timeout(const Duration(seconds: 2));

      if (result.exitCode == 0) {
        for (final line in (result.stdout as String).split('\n')) {
          final trimmed = line.trim();
          if (trimmed.isNotEmpty) pathCommands.add(trimmed);
        }
      }
    } on Exception {
      // Ignore
    }

    // Merge and sort — builtins first, then commands
    final all = <String>{...builtins, ...pathCommands};
    final sorted = all.toList()..sort();

    return sorted.map((name) {
      final isBuiltin = builtins.contains(name);
      return CompletionItem(
        text: name,
        type: isBuiltin ? CompletionType.builtin : CompletionType.command,
        description: isBuiltin ? 'Shell builtin' : null,
      );
    }).toList();
  }

  // ── Git-aware completion ─────────────────────────────────────────

  /// Common git subcommands, ordered roughly by frequency.
  static const _gitSubcommands = <String, String>{
    'add': 'Add file contents to the index',
    'branch': 'List, create, or delete branches',
    'checkout': 'Switch branches or restore files',
    'cherry-pick': 'Apply changes from existing commits',
    'clone': 'Clone a repository',
    'commit': 'Record changes to the repository',
    'diff': 'Show changes between commits or working tree',
    'fetch': 'Download objects and refs from a remote',
    'init': 'Create an empty git repository',
    'log': 'Show commit logs',
    'merge': 'Join two or more development histories',
    'pull': 'Fetch from and merge with a remote',
    'push': 'Update remote refs',
    'rebase': 'Reapply commits on top of another base',
    'remote': 'Manage set of tracked repositories',
    'reset': 'Reset HEAD to a specified state',
    'restore': 'Restore working tree files',
    'revert': 'Revert some existing commits',
    'show': 'Show various types of objects',
    'stash': 'Stash changes in a dirty working directory',
    'status': 'Show the working tree status',
    'switch': 'Switch branches',
    'tag': 'Create, list, delete, or verify tags',
  };

  /// Subcommands for `git remote`.
  static const _gitRemoteSubcommands = <String, String>{
    'add': 'Add a remote',
    'remove': 'Remove a remote',
    'rename': 'Rename a remote',
    'show': 'Show information about a remote',
    'prune': 'Remove stale tracking branches',
    'set-url': 'Change the URL of a remote',
  };

  /// Subcommands for `git stash`.
  static const _gitStashSubcommands = <String, String>{
    'apply': 'Apply a stash without removing it',
    'clear': 'Remove all stash entries',
    'drop': 'Remove a single stash entry',
    'list': 'List stash entries',
    'pop': 'Apply and remove the latest stash',
    'show': 'Show the changes in a stash',
  };

  /// Git subcommands whose arguments are typically files/paths.
  static const _gitFileCommands = {'add', 'restore', 'rm', 'mv', 'diff'};

  /// Git subcommands that take a branch/ref as their first argument.
  static const _gitBranchCommands = {
    'checkout', 'switch', 'merge', 'rebase', 'log',
    'show', 'cherry-pick', 'revert', 'reset',
  };

  /// Git subcommands that take a remote as their first argument,
  /// then a branch as the second.
  static const _gitRemoteFirstCommands = {'push', 'pull', 'fetch'};

  bool _gitCmdTakesFiles(List<String> words) {
    return words.length >= 2 && _gitFileCommands.contains(words[1]);
  }

  Future<List<CompletionItem>> _completeGit(
    List<String> words,
    String partial,
    String cwd,
  ) async {
    // `git <TAB>` → subcommands
    if (words.length == 2) {
      return _gitSubcommands.entries
          .where((e) => e.key.startsWith(partial))
          .map((e) => CompletionItem(
                text: e.key,
                type: CompletionType.gitSubcommand,
                description: e.value,
              ))
          .toList();
    }

    final subCmd = words[1];

    // `git remote <TAB>` → remote subcommands
    if (subCmd == 'remote' && words.length == 3) {
      return _gitRemoteSubcommands.entries
          .where((e) => e.key.startsWith(partial))
          .map((e) => CompletionItem(
                text: e.key,
                type: CompletionType.gitSubcommand,
                description: e.value,
              ))
          .toList();
    }

    // `git stash <TAB>` → stash subcommands
    if (subCmd == 'stash' && words.length == 3) {
      return _gitStashSubcommands.entries
          .where((e) => e.key.startsWith(partial))
          .map((e) => CompletionItem(
                text: e.key,
                type: CompletionType.gitSubcommand,
                description: e.value,
              ))
          .toList();
    }

    // `git push/pull/fetch <TAB>` → remotes
    if (_gitRemoteFirstCommands.contains(subCmd) && words.length == 3) {
      return _gitRemotes(partial, cwd);
    }

    // `git push/pull <remote> <TAB>` → branches, current branch first
    if (_gitRemoteFirstCommands.contains(subCmd) && words.length == 4) {
      return _gitBranches(partial, cwd, currentBranchFirst: true);
    }

    // `git checkout/switch/merge/rebase/... <TAB>` → branches
    if (_gitBranchCommands.contains(subCmd) && words.length == 3) {
      return _gitBranches(partial, cwd);
    }

    // `git branch -d/-D <TAB>` → branches
    if (subCmd == 'branch' && words.length == 4 &&
        (words[2] == '-d' || words[2] == '-D')) {
      return _gitBranches(partial, cwd);
    }

    // `git tag <TAB>` after a flag like -d → tags
    if (subCmd == 'tag' && words.length == 4 && words[2] == '-d') {
      return _gitTags(partial, cwd);
    }

    return [];
  }

  Future<List<CompletionItem>> _gitBranches(
    String partial,
    String cwd, {
    bool currentBranchFirst = false,
  }) async {
    try {
      final result = await Process.run(
        'git', ['branch', '-a', '--format=%(refname:short)'],
        workingDirectory: cwd,
      ).timeout(const Duration(seconds: 2));
      if (result.exitCode != 0) return [];

      String? currentBranch;
      if (currentBranchFirst) {
        final headResult = await Process.run(
          'git', ['branch', '--show-current'],
          workingDirectory: cwd,
        ).timeout(const Duration(seconds: 2));
        if (headResult.exitCode == 0) {
          currentBranch = (headResult.stdout as String).trim();
          if (currentBranch.isEmpty) currentBranch = null;
        }
      }

      final q = partial.toLowerCase();
      final items = (result.stdout as String)
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty && !s.endsWith('/HEAD'))
          .where((s) => s.toLowerCase().startsWith(q))
          .map((s) => CompletionItem(
                text: s,
                type: CompletionType.gitBranch,
                description: s == currentBranch
                    ? 'Current branch'
                    : s.contains('/') ? 'Remote' : 'Local',
              ))
          .toList();

      // Sort current branch to the top so it appears as the ghost
      // text suggestion for `git push origin <TAB>` etc.
      if (currentBranch != null) {
        items.sort((a, b) {
          if (a.text == currentBranch) return -1;
          if (b.text == currentBranch) return 1;
          return a.text.compareTo(b.text);
        });
      }

      return items;
    } on Exception {
      return [];
    }
  }

  Future<List<CompletionItem>> _gitRemotes(String partial, String cwd) async {
    try {
      final result = await Process.run(
        'git', ['remote'],
        workingDirectory: cwd,
      ).timeout(const Duration(seconds: 2));
      if (result.exitCode != 0) return [];
      return (result.stdout as String)
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty && s.startsWith(partial))
          .map((s) => CompletionItem(
                text: s,
                type: CompletionType.gitRemote,
              ))
          .toList();
    } on Exception {
      return [];
    }
  }

  Future<List<CompletionItem>> _gitTags(String partial, String cwd) async {
    try {
      final result = await Process.run(
        'git', ['tag', '-l'],
        workingDirectory: cwd,
      ).timeout(const Duration(seconds: 2));
      if (result.exitCode != 0) return [];
      return (result.stdout as String)
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty && s.startsWith(partial))
          .map((s) => CompletionItem(
                text: s,
                type: CompletionType.gitTag,
              ))
          .toList();
    } on Exception {
      return [];
    }
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
