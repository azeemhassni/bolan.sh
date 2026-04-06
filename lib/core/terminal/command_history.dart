import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'shell_history_importer.dart';

/// Persisted command history with search.
///
/// Stores commands in `~/.config/bolan/history` (one per line).
/// Supports navigation (up/down), search, and ghost text matching.
class CommandHistory {
  final List<String> _entries = [];
  static const _maxEntries = 10000;

  List<String> get entries => List.unmodifiable(_entries);
  int get length => _entries.length;

  /// Loads history from disk. On a fresh install (no Bolan history
  /// file yet) this also seeds entries from the user's bash/zsh
  /// history so completions and recall work immediately.
  Future<void> load() async {
    try {
      final file = await _historyFile();
      if (await file.exists()) {
        final lines = await file.readAsLines();
        _entries.addAll(lines.where((l) => l.isNotEmpty));
        if (_entries.length > _maxEntries) {
          _entries.removeRange(0, _entries.length - _maxEntries);
        }
        return;
      }
      await _bootstrapFromShellHistory();
    } on Object {
      // Best effort — a missing or unreadable history file shouldn't
      // prevent the app from starting.
    }
  }

  Future<void> _bootstrapFromShellHistory() async {
    final imported = await ShellHistoryImporter.autoDetect();
    if (imported == null || imported.isEmpty) return;

    final capped = imported.length > _maxEntries
        ? imported.sublist(imported.length - _maxEntries)
        : imported;
    _entries.addAll(capped);

    final file = await _historyFile();
    await file.parent.create(recursive: true);
    await file.writeAsString('${capped.join('\n')}\n');
  }

  /// Adds a command to history and persists it.
  Future<void> add(String command) async {
    if (command.isEmpty) return;
    // Don't add consecutive duplicates
    if (_entries.isNotEmpty && _entries.last == command) return;
    _entries.add(command);
    if (_entries.length > _maxEntries) {
      _entries.removeAt(0);
    }
    final file = await _historyFile();
    await file.parent.create(recursive: true);
    await file.writeAsString('$command\n', mode: FileMode.append);
  }

  /// Returns the entry at [index] from the end (0 = most recent).
  String? entryFromEnd(int index) {
    if (index < 0 || index >= _entries.length) return null;
    return _entries[_entries.length - 1 - index];
  }

  /// Searches history for entries containing [query] (case-insensitive).
  /// Returns matches from most recent to oldest.
  List<String> search(String query) {
    if (query.isEmpty) return _entries.reversed.take(50).toList();
    final lower = query.toLowerCase();
    return _entries.reversed
        .where((e) => e.toLowerCase().contains(lower))
        .take(50)
        .toList();
  }

  /// Finds the most recent entry that starts with [prefix].
  /// Used for ghost text suggestions while typing.
  String? findMatch(String prefix) {
    if (prefix.isEmpty) return null;
    final lower = prefix.toLowerCase();
    for (var i = _entries.length - 1; i >= 0; i--) {
      if (_entries[i].toLowerCase().startsWith(lower) &&
          _entries[i] != prefix) {
        return _entries[i];
      }
    }
    return null;
  }

  Future<File> _historyFile() async {
    if (Platform.isMacOS || Platform.isLinux) {
      final home = Platform.environment['HOME'] ?? '';
      return File('$home/.config/bolan/history');
    }
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/history');
  }
}
