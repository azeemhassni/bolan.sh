import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../workspace/workspace_paths.dart';
import 'snippet.dart';

const _uuid = Uuid();

/// Manages snippet persistence in `~/.config/bolan/snippets.json`.
///
/// Provides CRUD operations and notifies listeners on changes.
class SnippetStore extends ChangeNotifier {
  List<Snippet> _snippets = [];

  List<Snippet> get snippets => List.unmodifiable(_snippets);

  File _snippetFile() => WorkspacePaths.snippetsFile();

  /// Loads snippets from disk.
  Future<void> load() async {
    final file = _snippetFile();
    if (!file.existsSync()) return;
    try {
      final content = await file.readAsString();
      final list = jsonDecode(content) as List<dynamic>;
      _snippets = list
          .map((e) => Snippet.fromJson(e as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } on Exception catch (e) {
      debugPrint('Failed to load snippets: $e');
    }
  }

  /// Saves all snippets to disk.
  Future<void> _save() async {
    final file = _snippetFile();
    await file.parent.create(recursive: true);
    final json = jsonEncode(_snippets.map((s) => s.toJson()).toList());
    await file.writeAsString(json);
  }

  /// Adds a new snippet and saves.
  Future<void> add(Snippet snippet) async {
    final withId = Snippet(
      id: snippet.id.isEmpty ? _uuid.v4() : snippet.id,
      name: snippet.name,
      command: snippet.command,
      description: snippet.description,
      tags: snippet.tags,
    );
    _snippets.add(withId);
    await _save();
    notifyListeners();
  }

  /// Updates an existing snippet by ID and saves.
  Future<void> update(Snippet snippet) async {
    final index = _snippets.indexWhere((s) => s.id == snippet.id);
    if (index == -1) return;
    _snippets[index] = snippet;
    await _save();
    notifyListeners();
  }

  /// Removes a snippet by ID and saves.
  Future<void> remove(String id) async {
    _snippets.removeWhere((s) => s.id == id);
    await _save();
    notifyListeners();
  }

  /// Searches snippets by name, command, description, or tags.
  List<Snippet> search(String query) {
    if (query.isEmpty) return _snippets;
    final lower = query.toLowerCase();
    return _snippets.where((s) {
      return s.name.toLowerCase().contains(lower) ||
          s.command.toLowerCase().contains(lower) ||
          s.description.toLowerCase().contains(lower) ||
          s.tags.any((t) => t.toLowerCase().contains(lower));
    }).toList();
  }
}
