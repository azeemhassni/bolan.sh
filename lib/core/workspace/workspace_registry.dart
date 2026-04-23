import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:toml/toml.dart';

import '../ai/api_key_storage.dart';
import 'workspace.dart';
import 'workspace_paths.dart';
import 'workspace_secrets.dart';

/// Loads, persists, and CRUDs the list of workspaces from
/// `~/.config/bolan/workspaces.toml`.
///
/// The first call after upgrading from a pre-workspaces install creates
/// a "default" workspace and migrates legacy state files
/// (`history`, `session_state.json`, `snippets.json`) into
/// `workspaces/default/`. Global `config.toml` stays at the root.
class WorkspaceRegistry extends ChangeNotifier {
  List<Workspace> _workspaces = const [];
  String _activeId = 'default';

  List<Workspace> get workspaces => List.unmodifiable(_workspaces);
  String get activeId => _activeId;
  Workspace get active =>
      _workspaces.firstWhere((w) => w.id == _activeId,
          orElse: () => _workspaces.first);

  /// Loads the registry, creating a default workspace and migrating
  /// legacy files on first run.
  Future<void> loadOrCreate() async {
    final file = WorkspacePaths.registryFile();
    if (await file.exists()) {
      await _parse(await file.readAsString());
      return;
    }
    await _firstRunMigration();
  }

  Future<void> _parse(String content) async {
    try {
      final doc = TomlDocument.parse(content).toMap();
      _activeId = (doc['active'] as String?) ?? 'default';
      final list = (doc['workspaces'] as List<dynamic>?) ?? const [];
      _workspaces = list
          .whereType<Map<String, dynamic>>()
          .map(_workspaceFromMap)
          .toList();
      if (_workspaces.isEmpty) {
        // Corrupt or empty registry — synthesize a default so the app
        // can boot. The user's data isn't touched.
        _workspaces = [_defaultWorkspace()];
        _activeId = 'default';
      }
      // Active id may point at a deleted workspace; fall back.
      if (!_workspaces.any((w) => w.id == _activeId)) {
        _activeId = _workspaces.first.id;
      }
      notifyListeners();
    } on Exception catch (e) {
      debugPrint('Failed to parse workspaces.toml: $e');
      _workspaces = [_defaultWorkspace()];
      _activeId = 'default';
    }
  }

  /// Creates the registry with a single "default" workspace and moves
  /// existing root-level state files into `workspaces/default/`.
  /// Idempotent: if the destination already exists we don't overwrite.
  Future<void> _firstRunMigration() async {
    _workspaces = [_defaultWorkspace()];
    _activeId = 'default';

    // Set the active id BEFORE migrating so destination paths resolve
    // through WorkspacePaths.workspacePath().
    WorkspacePaths.setActiveWorkspace('default', _workspaces.first);

    final root = WorkspacePaths.rootPath();
    // Seed default workspace's config from legacy root config so the
    // user keeps their existing settings. We COPY rather than move —
    // the legacy file stays put as a safety net during the upgrade
    // window. A future version can clean it up once we're confident.
    final legacyConfig = WorkspacePaths.legacyConfigFile();
    final newConfig = WorkspacePaths.configFile();
    if (await legacyConfig.exists() && !await newConfig.exists()) {
      await newConfig.parent.create(recursive: true);
      await legacyConfig.copy(newConfig.path);
    }

    await _moveIfPresent(
        File('$root/history'), WorkspacePaths.historyFile());
    await _moveIfPresent(
        File('$root/session_state.json'),
        WorkspacePaths.sessionStateFile());
    await _moveIfPresent(
        File('$root/snippets.json'), WorkspacePaths.snippetsFile());

    await save();
    notifyListeners();
  }

  Future<void> _moveIfPresent(File from, File to) async {
    if (!await from.exists()) return;
    if (await to.exists()) return; // don't clobber
    await to.parent.create(recursive: true);
    try {
      await from.rename(to.path);
    } on FileSystemException {
      // Cross-device rename can fail on some Linux setups (e.g. /tmp
      // mounted separately). Fall back to copy + delete.
      await from.copy(to.path);
      await from.delete();
    }
  }

  /// Persists the registry to disk.
  Future<void> save() async {
    final file = WorkspacePaths.registryFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(_toToml());
  }

  Future<void> setActive(String id) async {
    final next = _workspaces.where((w) => w.id == id).firstOrNull;
    if (next == null) return;
    _activeId = id;
    // Load secrets from keychain into the workspace so they're
    // available for PTY injection without a separate async step.
    final secrets = await WorkspaceSecrets.load(id);
    final withSecrets = next.copyWith(secrets: secrets);
    WorkspacePaths.setActiveWorkspace(id, withSecrets);
    await save();
    notifyListeners();
  }

  /// Adds a workspace, optionally seeding its config from [seedFromId]
  /// (typically the currently-active workspace). Without a seed the
  /// new workspace starts with no config file and consumers will fall
  /// back to factory defaults.
  Future<void> add(Workspace w, {String? seedFromId}) async {
    if (_workspaces.any((existing) => existing.id == w.id)) {
      throw ArgumentError('Workspace id "${w.id}" already exists');
    }

    if (seedFromId != null) {
      final root = WorkspacePaths.rootPath();
      final src = File('$root/workspaces/$seedFromId/config.toml');
      final dst = File('$root/workspaces/${w.id}/config.toml');
      if (await src.exists() && !await dst.exists()) {
        await dst.parent.create(recursive: true);
        await src.copy(dst.path);
      }
    }

    _workspaces = [..._workspaces, w];
    await save();
    notifyListeners();
  }

  Future<void> update(Workspace w) async {
    _workspaces = [
      for (final existing in _workspaces)
        if (existing.id == w.id) w else existing,
    ];
    await save();
    notifyListeners();
  }

  /// Deletes a workspace and its on-disk state. Refuses to delete the
  /// last remaining workspace — there must always be at least one.
  Future<void> delete(String id) async {
    if (_workspaces.length <= 1) {
      throw StateError('Cannot delete the last remaining workspace.');
    }
    final dir =
        Directory('${WorkspacePaths.rootPath()}/workspaces/$id');
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    await ApiKeyStorage.deleteAllForWorkspace(id);
    await WorkspaceSecrets.deleteAll(id);
    _workspaces = _workspaces.where((w) => w.id != id).toList();
    if (_activeId == id) {
      _activeId = _workspaces.first.id;
      WorkspacePaths.setActiveWorkspace(_activeId, _workspaces.first);
    }
    await save();
    notifyListeners();
  }

  /// Reorders workspaces (used by drag-and-drop in the sidebar later).
  Future<void> reorder(int oldIndex, int newIndex) async {
    final list = [..._workspaces];
    if (newIndex > oldIndex) newIndex -= 1;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    _workspaces = list;
    await save();
    notifyListeners();
  }

  // ── (de)serialization ────────────────────────────────────────

  Workspace _workspaceFromMap(Map<String, dynamic> m) => Workspace(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? (m['id'] as String),
        color: (m['color'] as String?) ?? '#888888',
        enabled: (m['enabled'] as bool?) ?? true,
        envVars: ((m['env'] as Map<String, dynamic>?) ?? const {})
            .map((k, v) => MapEntry(k, v.toString())),
        gitName: m['git_name'] as String?,
        gitEmail: m['git_email'] as String?,
        icon: (m['icon'] as String?) ?? '',
      );

  Workspace _defaultWorkspace() => const Workspace(
        id: 'default',
        name: 'Default',
        color: '#7AA2F7',
      );

  String _toToml() {
    final sb = StringBuffer();
    sb.writeln('active = "$_activeId"');
    sb.writeln();
    for (final w in _workspaces) {
      sb.writeln('[[workspaces]]');
      sb.writeln('id = "${w.id}"');
      sb.writeln('name = "${w.name}"');
      sb.writeln('color = "${w.color}"');
      if (!w.enabled) sb.writeln('enabled = false');
      if (w.gitName != null) sb.writeln('git_name = "${w.gitName}"');
      if (w.gitEmail != null) sb.writeln('git_email = "${w.gitEmail}"');
      if (w.icon.isNotEmpty) sb.writeln('icon = "${w.icon}"');
      if (w.envVars.isNotEmpty) {
        sb.writeln('[workspaces.env]');
        for (final entry in w.envVars.entries) {
          sb.writeln('${entry.key} = "${entry.value}"');
        }
      }
      sb.writeln();
    }
    return sb.toString();
  }
}
