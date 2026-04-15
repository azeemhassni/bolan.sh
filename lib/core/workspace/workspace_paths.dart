import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Single source of truth for where per-workspace state lives on disk.
///
/// Workspace-scoped files are: `config.toml`, `history`, `session_state.json`,
/// `snippets.json`. Globally-scoped files (model weights, themes, update
/// tracking) bypass this helper and resolve to the legacy locations directly.
///
/// Until the workspace registry lands [activeWorkspaceId] is null and every
/// path resolves to the legacy `~/.config/bolan/<file>` location, preserving
/// the pre-workspaces layout exactly.
///
/// Call [init] once at app startup (before any consumer reads paths). After
/// that, sync accessors are available — needed by callers like
/// `SessionPersistence.load()` that cannot await.
class WorkspacePaths {
  WorkspacePaths._();

  /// Currently-active workspace id, or null if no workspace context is set.
  /// Mutate via [setActiveWorkspace] so dependent caches stay coherent.
  static String? activeWorkspaceId;

  /// Cached root directory, populated by [init]. Sync APIs depend on this.
  static String? _rootPath;

  /// Resolves and caches the root directory. Call once at app startup
  /// before any other code reads paths. Idempotent.
  static Future<void> init() async {
    if (_rootPath != null) return;
    if (Platform.isMacOS || Platform.isLinux) {
      final home = Platform.environment['HOME'] ?? '';
      _rootPath = '$home/.config/bolan';
    } else {
      final dir = await getApplicationSupportDirectory();
      _rootPath = dir.path;
    }
  }

  static void setActiveWorkspace(String? id) {
    activeWorkspaceId = id;
  }

  /// Root directory for all Bolan state. Requires [init] to have run.
  static String rootPath() {
    final p = _rootPath;
    if (p == null) {
      throw StateError('WorkspacePaths.init() must be awaited before use.');
    }
    return p;
  }

  /// Directory holding the active workspace's state. When no workspace is
  /// set this is the legacy root, so existing layouts continue to work
  /// untouched.
  static String workspacePath() {
    final root = rootPath();
    final id = activeWorkspaceId;
    return id == null ? root : '$root/workspaces/$id';
  }

  /// Global config file (shared across all workspaces). Per-workspace
  /// overrides live separately and are merged on top — see Phase 4.
  static File configFile() => File('${rootPath()}/config.toml');

  /// Per-workspace config override (sparse — only keys that differ from
  /// the global config). Returns the legacy global path when no
  /// workspace is active. Wired in Phase 4.
  static File configOverrideFile() =>
      File('${workspacePath()}/config.toml');

  /// Workspace registry — list of all workspaces, ordering, last active.
  static File registryFile() => File('${rootPath()}/workspaces.toml');

  static File historyFile() => File('${workspacePath()}/history');
  static File sessionStateFile() =>
      File('${workspacePath()}/session_state.json');
  static File snippetsFile() => File('${workspacePath()}/snippets.json');
}
