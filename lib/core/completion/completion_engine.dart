import 'dart:convert';
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
  npmSubcommand,
  npmScript,
  npmPackage,
  artisanCommand,
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
      } else if (words.isNotEmpty &&
          (words.first == 'npm' || words.first == 'npx' ||
           words.first == 'pnpm' || words.first == 'yarn')) {
        items = await _completeNpm(words, currentWord, cwd);
      } else if (_isArtisanCommand(words)) {
        items = await _completeArtisan(words, currentWord, cwd);
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

  // ── npm / pnpm / yarn / npx completion ──────────────────────────

  static const _npmSubcommands = <String, String>{
    'access': 'Set access level on published packages',
    'adduser': 'Add a registry user account',
    'audit': 'Run a security audit',
    'bugs': 'Report bugs for a package',
    'cache': 'Manipulates the packages cache',
    'ci': 'Clean install from lock file',
    'config': 'Manage npm configuration',
    'dedupe': 'Reduce duplication in the package tree',
    'deprecate': 'Deprecate a package version',
    'diff': 'Show diff of package files',
    'dist-tag': 'Modify package distribution tags',
    'docs': 'Open documentation for a package',
    'doctor': 'Check environment',
    'edit': 'Edit an installed package',
    'exec': 'Run a command from a package',
    'explain': 'Explain installed packages',
    'explore': 'Browse an installed package',
    'find-dupes': 'Find duplicates in the package tree',
    'fund': 'Show funding information',
    'help': 'Get help on npm',
    'init': 'Create a package.json file',
    'install': 'Install a package',
    'install-ci-test': 'Install and run tests',
    'install-test': 'Install and run tests',
    'link': 'Symlink a package folder',
    'login': 'Log in to the registry',
    'logout': 'Log out of the registry',
    'ls': 'List installed packages',
    'outdated': 'Check for outdated packages',
    'owner': 'Manage package owners',
    'pack': 'Create a tarball from a package',
    'pkg': 'Manage package.json',
    'prefix': 'Display prefix',
    'profile': 'Manage registry profile',
    'prune': 'Remove extraneous packages',
    'publish': 'Publish a package',
    'rebuild': 'Rebuild a package',
    'repo': 'Open package repository in browser',
    'restart': 'Restart a package',
    'root': 'Display npm root',
    'run': 'Run arbitrary package scripts',
    'run-script': 'Run arbitrary package scripts',
    'search': 'Search for packages',
    'set': 'Set a config key',
    'shrinkwrap': 'Lock down dependency versions',
    'star': 'Mark favourite packages',
    'stars': 'View starred packages',
    'start': 'Start a package',
    'stop': 'Stop a package',
    'test': 'Test a package',
    'token': 'Manage authentication tokens',
    'uninstall': 'Remove a package',
    'unpublish': 'Remove a package from the registry',
    'unstar': 'Remove star from a package',
    'update': 'Update packages',
    'version': 'Bump a package version',
    'view': 'View registry info',
    'whoami': 'Display npm username',
  };

  Future<List<CompletionItem>> _completeNpm(
    List<String> words,
    String partial,
    String cwd,
  ) async {
    final pm = words.first; // npm, pnpm, yarn, npx

    // `npx <TAB>` → installed binaries from node_modules/.bin
    if (pm == 'npx' && words.length == 2) {
      return _npmBinaries(partial, cwd);
    }

    // `npm <TAB>` → subcommands
    if (words.length == 2) {
      return _npmSubcommands.entries
          .where((e) => e.key.startsWith(partial))
          .map((e) => CompletionItem(
                text: e.key,
                type: CompletionType.npmSubcommand,
                description: e.value,
              ))
          .toList();
    }

    final subCmd = words[1];

    // `npm run <TAB>` / `npm run-script <TAB>` → scripts
    if ((subCmd == 'run' || subCmd == 'run-script') && words.length == 3) {
      return _npmScripts(partial, cwd);
    }

    // `pnpm <script>` / `yarn <script>` — these can run scripts
    // directly as subcommands, so also check package.json scripts
    // when the subcommand isn't a known npm command.
    if ((pm == 'pnpm' || pm == 'yarn') &&
        words.length == 2 &&
        !_npmSubcommands.containsKey(partial)) {
      final scripts = await _npmScripts(partial, cwd);
      if (scripts.isNotEmpty) return scripts;
    }

    // `npm uninstall <TAB>` / `npm remove <TAB>` → installed packages
    if ((subCmd == 'uninstall' || subCmd == 'remove' || subCmd == 'rm' ||
            subCmd == 'un') &&
        words.length == 3) {
      return _npmInstalledPackages(partial, cwd);
    }

    return [];
  }

  /// Reads scripts from the nearest package.json.
  Future<List<CompletionItem>> _npmScripts(String partial, String cwd) async {
    try {
      final file = File('$cwd/package.json');
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      // Lightweight JSON parse — just extract the "scripts" keys.
      // Full dart:convert is fine here; package.json is always small.
      final map = _parseJsonMap(content);
      final scripts = map['scripts'];
      if (scripts is! Map) return [];
      return scripts.keys
          .where((k) => k is String && k.startsWith(partial))
          .map((k) => CompletionItem(
                text: k as String,
                type: CompletionType.npmScript,
                description: _truncate(scripts[k]?.toString() ?? '', 60),
              ))
          .toList();
    } on Exception {
      return [];
    }
  }

  /// Lists top-level packages in node_modules (for uninstall completion).
  Future<List<CompletionItem>> _npmInstalledPackages(
    String partial,
    String cwd,
  ) async {
    try {
      final dir = Directory('$cwd/node_modules');
      if (!await dir.exists()) return [];
      final items = <CompletionItem>[];
      await for (final entity in dir.list()) {
        final name = entity.path.split('/').last;
        if (name.startsWith('.')) continue;
        // Scoped packages: @scope/pkg lives as node_modules/@scope/pkg
        if (name.startsWith('@') && entity is Directory) {
          await for (final scoped in entity.list()) {
            final scopedName = '$name/${scoped.path.split('/').last}';
            if (scopedName.startsWith(partial)) {
              items.add(CompletionItem(
                text: scopedName,
                type: CompletionType.npmPackage,
              ));
            }
          }
        } else if (name.startsWith(partial)) {
          items.add(CompletionItem(
            text: name,
            type: CompletionType.npmPackage,
          ));
        }
      }
      items.sort((a, b) => a.text.compareTo(b.text));
      return items;
    } on Exception {
      return [];
    }
  }

  /// Lists executables in node_modules/.bin (for npx completion).
  Future<List<CompletionItem>> _npmBinaries(String partial, String cwd) async {
    try {
      final dir = Directory('$cwd/node_modules/.bin');
      if (!await dir.exists()) return [];
      final items = <CompletionItem>[];
      await for (final entity in dir.list()) {
        final name = entity.path.split('/').last;
        if (name.startsWith(partial)) {
          items.add(CompletionItem(
            text: name,
            type: CompletionType.npmSubcommand,
            description: 'Local binary',
          ));
        }
      }
      items.sort((a, b) => a.text.compareTo(b.text));
      return items;
    } on Exception {
      return [];
    }
  }

  /// Minimal JSON object parser — avoids importing dart:convert in this
  /// file just for one call. Only handles the top level of a JSON object.
  static Map<String, dynamic> _parseJsonMap(String json) {
    // dart:convert is fine, just use it inline.
    return (const JsonDecoder().convert(json) as Map).cast<String, dynamic>();
  }

  static String _truncate(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max)}...';

  CompletionResult _empty(int cursorPos) {
    return CompletionResult(
      items: [],
      prefix: '',
      replaceStart: cursorPos,
      replaceEnd: cursorPos,
    );
  }

  // ── Laravel Artisan ───────────────────────────────────────

  /// Matches `php artisan`, `artisan`, or `./artisan`.
  bool _isArtisanCommand(List<String> words) {
    if (words.isEmpty) return false;
    final first = words.first;
    if (first == 'artisan' || first == './artisan') return true;
    if (first == 'php' && words.length > 1 && words[1] == 'artisan') {
      return true;
    }
    return false;
  }

  /// Index of the artisan subcommand word (the word after "artisan").
  int _artisanCmdIndex(List<String> words) {
    if (words.first == 'php') return 2; // php artisan <cmd>
    return 1; // artisan <cmd> or ./artisan <cmd>
  }

  Future<List<CompletionItem>> _completeArtisan(
    List<String> words,
    String partial,
    String cwd,
  ) async {
    final cmdIdx = _artisanCmdIndex(words);

    // Complete the artisan command name
    if (words.length == cmdIdx + 1) {
      return _artisanCommands(partial, cwd);
    }

    // After the command — fall back to path completion for arguments
    return _completePath(partial, cwd);
  }

  /// Gets artisan commands by running `php artisan list --format=json`.
  /// Falls back to a static list if php/artisan isn't available.
  Future<List<CompletionItem>> _artisanCommands(
    String partial,
    String cwd,
  ) async {
    // Try dynamic discovery first
    try {
      final result = await Process.run(
        'php',
        ['artisan', 'list', '--format=json'],
        workingDirectory: cwd,
      ).timeout(const Duration(seconds: 3));

      if (result.exitCode == 0) {
        final data = jsonDecode(result.stdout as String) as Map<String, dynamic>;
        final commands = data['commands'] as List<dynamic>? ?? [];
        final items = <CompletionItem>[];
        for (final cmd in commands) {
          final c = cmd as Map<String, dynamic>;
          final name = c['name'] as String? ?? '';
          if (name.isEmpty || name == '_complete' || name == 'completion') {
            continue;
          }
          if (name.toLowerCase().startsWith(partial.toLowerCase())) {
            items.add(CompletionItem(
              text: name,
              type: CompletionType.artisanCommand,
              description: _truncate(
                  c['description']?.toString() ?? '', 60),
            ));
          }
        }
        if (items.isNotEmpty) return items;
      }
    } on Exception {
      // Fall through to static list
    }

    // Static fallback — only if we're in a Laravel project
    if (!File('$cwd/artisan').existsSync()) return [];
    return _artisanStaticCommands.entries
        .where((e) => e.key.toLowerCase().startsWith(partial.toLowerCase()))
        .map((e) => CompletionItem(
              text: e.key,
              type: CompletionType.artisanCommand,
              description: e.value,
            ))
        .toList();
  }

  static const _artisanStaticCommands = <String, String>{
    'cache:clear': 'Flush the application cache',
    'cache:forget': 'Remove an item from the cache',
    'cache:table': 'Create a migration for the cache database table',
    'config:cache': 'Create a cache file for faster configuration loading',
    'config:clear': 'Remove the configuration cache file',
    'db:seed': 'Seed the database with records',
    'db:wipe': 'Drop all tables, views, and types',
    'down': 'Put the application into maintenance mode',
    'env': 'Display the current framework environment',
    'event:generate': 'Generate the missing events and listeners',
    'event:list': 'List the application events and listeners',
    'inspire': 'Display an inspiring quote',
    'key:generate': 'Set the application key',
    'make:cast': 'Create a new custom Eloquent cast class',
    'make:channel': 'Create a new channel class',
    'make:command': 'Create a new Artisan command',
    'make:component': 'Create a new view component class',
    'make:controller': 'Create a new controller class',
    'make:event': 'Create a new event class',
    'make:exception': 'Create a new custom exception class',
    'make:factory': 'Create a new model factory',
    'make:job': 'Create a new job class',
    'make:listener': 'Create a new event listener class',
    'make:livewire': 'Create a new Livewire component',
    'make:mail': 'Create a new email class',
    'make:middleware': 'Create a new middleware class',
    'make:migration': 'Create a new migration file',
    'make:model': 'Create a new Eloquent model class',
    'make:notification': 'Create a new notification class',
    'make:observer': 'Create a new observer class',
    'make:policy': 'Create a new policy class',
    'make:provider': 'Create a new service provider class',
    'make:request': 'Create a new form request class',
    'make:resource': 'Create a new resource',
    'make:rule': 'Create a new validation rule',
    'make:scope': 'Create a new scope class',
    'make:seeder': 'Create a new seeder class',
    'make:test': 'Create a new test class',
    'make:view': 'Create a new view',
    'migrate': 'Run the database migrations',
    'migrate:fresh': 'Drop all tables and re-run all migrations',
    'migrate:install': 'Create the migration repository',
    'migrate:refresh': 'Reset and re-run all migrations',
    'migrate:reset': 'Rollback all database migrations',
    'migrate:rollback': 'Rollback the last database migration',
    'migrate:status': 'Show the status of each migration',
    'optimize': 'Cache framework bootstrap, configuration, and metadata',
    'optimize:clear': 'Remove the cached bootstrap files',
    'queue:clear': 'Delete all of the jobs from the specified queue',
    'queue:failed': 'List all of the failed queue jobs',
    'queue:flush': 'Flush all of the failed queue jobs',
    'queue:listen': 'Listen to a given queue',
    'queue:restart': 'Restart queue worker daemons after their current job',
    'queue:retry': 'Retry a failed queue job',
    'queue:work': 'Start processing jobs on the queue as a daemon',
    'route:cache': 'Create a route cache file for faster route registration',
    'route:clear': 'Remove the route cache file',
    'route:list': 'List all registered routes',
    'schedule:list': 'List all scheduled tasks',
    'schedule:run': 'Run the scheduled commands',
    'schedule:work': 'Start the schedule worker',
    'serve': 'Serve the application on the PHP development server',
    'storage:link': 'Create the symbolic links for the application',
    'stub:publish': 'Publish all stubs that are available for customization',
    'test': 'Run the application tests',
    'tinker': 'Interact with your application',
    'up': 'Bring the application out of maintenance mode',
    'vendor:publish': 'Publish any publishable assets from vendor packages',
    'view:cache': 'Compile all of the application Blade templates',
    'view:clear': 'Clear all compiled view files',
  };

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
