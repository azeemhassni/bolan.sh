import 'package:flutter/painting.dart';

/// A workspace is an isolated Bolan profile: its own tabs, history,
/// shell session, env vars, AI keys, and optional git identity. All
/// workspaces share the global config as a baseline; per-workspace
/// overrides layer on top (see Phase 4).
///
/// Identifiers are kebab-case and stable — they form directory names
/// under `~/.config/bolan/workspaces/<id>/` and are used as keychain
/// prefixes for AI provider keys. Display names are mutable.
class Workspace {
  /// Stable identifier. Must match `^[a-z0-9][a-z0-9-]*$` so it's safe
  /// as a directory name and keychain key fragment.
  final String id;

  /// Human-readable name shown in the sidebar and tab bar.
  final String name;

  /// Accent color (hex string, e.g. "#FF7A59"). Used for sidebar item
  /// highlight and the tab bar accent strip — the visual cue that
  /// prevents running prod commands in a personal workspace.
  final String color;

  /// Per-workspace environment variables injected into PTYs at spawn.
  /// Wired in Phase 5.
  final Map<String, String> envVars;

  /// Optional git identity. When set, `GIT_AUTHOR_NAME`/`GIT_AUTHOR_EMAIL`
  /// (and the committer pair) are injected into PTY env. Wired in Phase 5.
  final String? gitName;
  final String? gitEmail;

  /// Optional default working directory for new tabs. Empty means
  /// inherit from the global config.
  final String? defaultCwd;

  const Workspace({
    required this.id,
    required this.name,
    required this.color,
    this.envVars = const {},
    this.gitName,
    this.gitEmail,
    this.defaultCwd,
  });

  /// Initial letter for the sidebar icon. First code unit of [name];
  /// good enough for ASCII names and the common case (emoji prefixes
  /// would render the surrogate half — acceptable for v1).
  String get initial => name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();

  /// Parsed accent color, falling back to grey on malformed hex.
  Color get accentColor {
    final hex = color.replaceFirst('#', '');
    if (hex.length != 6) return const Color(0xFF888888);
    final v = int.tryParse(hex, radix: 16);
    if (v == null) return const Color(0xFF888888);
    return Color(0xFF000000 | v);
  }

  Workspace copyWith({
    String? id,
    String? name,
    String? color,
    Map<String, String>? envVars,
    String? gitName,
    String? gitEmail,
    String? defaultCwd,
  }) =>
      Workspace(
        id: id ?? this.id,
        name: name ?? this.name,
        color: color ?? this.color,
        envVars: envVars ?? this.envVars,
        gitName: gitName ?? this.gitName,
        gitEmail: gitEmail ?? this.gitEmail,
        defaultCwd: defaultCwd ?? this.defaultCwd,
      );
}
