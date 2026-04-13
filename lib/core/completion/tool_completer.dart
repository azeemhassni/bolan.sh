import 'dart:convert';
import 'dart:io';

import 'completion_engine.dart';

/// A self-discovering CLI tool that provides its own completions.
///
/// To add a new tool, create an instance of [ToolCompleter] and add it
/// to [toolCompleters]. The engine calls [discover] to get the command
/// list dynamically — no hardcoded subcommand lists to maintain.
///
/// Example:
/// ```dart
/// ToolCompleter(
///   names: ['composer'],
///   type: CompletionType.composerCommand,
///   discover: DiscoverCommand(
///     executable: 'composer',
///     args: ['list', '--format=json'],
///     parse: parseSymfonyConsoleJson,
///   ),
/// )
/// ```
class ToolCompleter {
  /// Command names that trigger this completer (e.g. `['composer']`).
  final List<String> names;

  /// The completion type for UI icon mapping.
  final CompletionType type;

  /// How to dynamically discover subcommands.
  final DiscoverCommand discover;

  /// Optional: file that must exist in cwd for static fallback.
  /// If null, static fallback is always available.
  final String? requiredFile;

  /// Static fallback commands when discovery fails.
  final Map<String, String> staticFallback;

  /// Names to exclude from discovery results (internal commands).
  final Set<String> excludeNames;

  const ToolCompleter({
    required this.names,
    required this.type,
    required this.discover,
    this.requiredFile,
    this.staticFallback = const {},
    this.excludeNames = const {},
  });

  /// Whether this completer handles the given command words.
  bool matches(List<String> words) {
    if (words.isEmpty) return false;
    return names.contains(words.first);
  }

  /// Index of the subcommand word (always 1 for direct tools).
  int get subcommandIndex => 1;

  /// Fetch completions for the subcommand position.
  Future<List<CompletionItem>> complete(
    String partial,
    String cwd,
  ) async {
    // Try dynamic discovery first
    final items = await _discover(partial, cwd);
    if (items.isNotEmpty) return items;

    // Static fallback
    if (requiredFile != null && !File('$cwd/$requiredFile').existsSync()) {
      return [];
    }
    return staticFallback.entries
        .where((e) => e.key.toLowerCase().startsWith(partial.toLowerCase()))
        .map((e) => CompletionItem(
              text: e.key,
              type: type,
              description: e.value,
            ))
        .toList();
  }

  Future<List<CompletionItem>> _discover(String partial, String cwd) async {
    try {
      final result = await Process.run(
        discover.executable,
        discover.args,
        workingDirectory: cwd,
      ).timeout(const Duration(seconds: 3));

      if (result.exitCode != 0) return [];

      final commands = discover.parse(result.stdout as String);
      return commands
          .where((c) =>
              !excludeNames.contains(c.name) &&
              c.name.toLowerCase().startsWith(partial.toLowerCase()))
          .map((c) => CompletionItem(
                text: c.name,
                type: type,
                description: c.description,
              ))
          .toList();
    } on Exception {
      return [];
    }
  }
}

/// How to run and parse a tool's self-discovery command.
class DiscoverCommand {
  final String executable;
  final List<String> args;
  final List<DiscoveredCommand> Function(String output) parse;

  const DiscoverCommand({
    required this.executable,
    required this.args,
    required this.parse,
  });
}

/// A command discovered from a tool's output.
class DiscoveredCommand {
  final String name;
  final String? description;

  const DiscoveredCommand({required this.name, this.description});
}

// ── Reusable parsers ───────────────────────────────────────

/// Parses Symfony Console JSON format (used by Laravel Artisan, Composer,
/// and any Symfony-based CLI tool).
///
/// Expected format:
/// ```json
/// { "commands": [{ "name": "...", "description": "..." }, ...] }
/// ```
List<DiscoveredCommand> parseSymfonyConsoleJson(String output) {
  final data = jsonDecode(output) as Map<String, dynamic>;
  final commands = data['commands'] as List<dynamic>? ?? [];
  return commands.map((cmd) {
    final c = cmd as Map<String, dynamic>;
    return DiscoveredCommand(
      name: c['name'] as String? ?? '',
      description: _truncate(c['description']?.toString() ?? '', 60),
    );
  }).where((c) => c.name.isNotEmpty).toList();
}

/// Parses line-per-command format (e.g. `cargo --list`).
///
/// Each line is either:
/// - `command` (just a name)
/// - `command   description` (name + whitespace + description)
List<DiscoveredCommand> parseLinePerCommand(String output) {
  return output
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .map((line) {
    final match = RegExp(r'^(\S+)\s+(.+)$').firstMatch(line);
    if (match != null) {
      return DiscoveredCommand(
        name: match.group(1)!,
        description: _truncate(match.group(2)!.trim(), 60),
      );
    }
    return DiscoveredCommand(name: line);
  }).toList();
}

String _truncate(String s, int max) =>
    s.length <= max ? s : '${s.substring(0, max)}...';
