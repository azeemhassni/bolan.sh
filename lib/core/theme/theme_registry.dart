import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'bolan_theme.dart';
import 'default_dark.dart';
import 'theme_serializer.dart';
import 'themes/default_light.dart';
import 'themes/dracula.dart';
import 'themes/gruvbox_dark.dart';
import 'themes/monokai.dart';
import 'themes/nord.dart';
import 'themes/one_dark.dart';
import 'themes/raskoh.dart';
import 'themes/solarized_dark.dart';
import 'themes/solarized_light.dart';
import 'themes/tokyo_night.dart';

/// Registry of all available themes (built-in + custom).
///
/// Provides lookup by name with fallback to default-dark.
/// Scans ~/.config/bolan/themes/ for custom TOML themes.
class ThemeRegistry extends ChangeNotifier {
  final Map<String, BolonTheme> _themes = {};
  Timer? _watchTimer;

  ThemeRegistry() {
    _register(bolonDefaultDark);
    _register(bolonDefaultLight);
    _register(draculaTheme);
    _register(oneDarkTheme);
    _register(nordTheme);
    _register(monokaiTheme);
    _register(solarizedDarkTheme);
    _register(solarizedLightTheme);
    _register(gruvboxDarkTheme);
    _register(tokyoNightTheme);
    _register(raskohTheme);
  }

  /// All available themes sorted: built-ins first, then custom alphabetically.
  List<BolonTheme> get allThemes {
    final builtIns = _themes.values.where((t) => t.isBuiltIn).toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
    final custom = _themes.values.where((t) => !t.isBuiltIn).toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
    return [...builtIns, ...custom];
  }

  /// Gets a theme by name, falling back to default-dark.
  BolonTheme getTheme(String name) {
    return _themes[name] ?? bolonDefaultDark;
  }

  /// Loads custom themes from ~/.config/bolan/themes/
  Future<void> loadCustomThemes() async {
    final dir = _themesDir();
    if (!await dir.exists()) return;

    try {
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.toml')) {
          await _loadThemeFile(entity);
        }
      }
    } on FileSystemException catch (e) {
      debugPrint('Error scanning themes dir: $e');
    }
  }

  /// Starts watching the themes directory for changes.
  void startWatching() {
    _watchTimer?.cancel();
    _watchTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      await loadCustomThemes();
    });
  }

  /// Stops watching.
  void stopWatching() {
    _watchTimer?.cancel();
    _watchTimer = null;
  }

  /// Saves a custom theme as a TOML file.
  Future<void> saveCustomTheme(BolonTheme theme) async {
    final dir = _themesDir();
    await dir.create(recursive: true);
    final file = File('${dir.path}/${theme.name}.toml');
    await file.writeAsString(ThemeSerializer.toToml(theme));
    _themes[theme.name] = theme;
    notifyListeners();
  }

  /// Duplicates a theme with a new name for editing.
  Future<BolonTheme> duplicateTheme(
      BolonTheme source, String newName, String displayName) async {
    final copy = source.copyWith(
      name: newName,
      displayName: displayName,
      isBuiltIn: false,
    );
    await saveCustomTheme(copy);
    return copy;
  }

  /// Exports a theme to a file path.
  Future<void> exportTheme(BolonTheme theme, String path) async {
    final file = File(path);
    await file.writeAsString(ThemeSerializer.toToml(theme));
  }

  /// Imports a theme from a file path.
  Future<BolonTheme?> importTheme(String path) async {
    try {
      final file = File(path);
      final content = await file.readAsString();
      final theme = ThemeSerializer.fromToml(content);
      if (_themes.containsKey(theme.name) && _themes[theme.name]!.isBuiltIn) {
        debugPrint('Cannot import: name conflicts with built-in theme');
        return null;
      }
      await saveCustomTheme(theme);
      return theme;
    } on Exception catch (e) {
      debugPrint('Import failed: $e');
      return null;
    }
  }

  /// Adds or updates a custom theme.
  void addCustomTheme(BolonTheme theme) {
    if (_themes.containsKey(theme.name) && _themes[theme.name]!.isBuiltIn) {
      debugPrint('Cannot overwrite built-in theme: ${theme.name}');
      return;
    }
    _themes[theme.name] = theme;
    notifyListeners();
  }

  /// Removes a custom theme (cannot remove built-ins).
  Future<void> removeCustomTheme(String name) async {
    final theme = _themes[name];
    if (theme == null || theme.isBuiltIn) return;
    _themes.remove(name);
    // Delete the file
    final file = File('${_themesDir().path}/$name.toml');
    if (await file.exists()) await file.delete();
    notifyListeners();
  }

  /// Whether a theme name exists.
  bool hasTheme(String name) => _themes.containsKey(name);

  @override
  void dispose() {
    stopWatching();
    super.dispose();
  }

  // --- Internal ---

  void _register(BolonTheme theme) {
    _themes[theme.name] = theme;
  }

  Future<void> _loadThemeFile(File file) async {
    try {
      final content = await file.readAsString();
      final theme = ThemeSerializer.fromToml(content);
      // Don't overwrite built-in themes
      if (!_themes.containsKey(theme.name) ||
          !_themes[theme.name]!.isBuiltIn) {
        _themes[theme.name] = theme;
      }
    } on Exception catch (e) {
      debugPrint('Failed to load theme ${file.path}: $e');
    }
  }

  Directory _themesDir() {
    final home = Platform.environment['HOME'] ?? '';
    return Directory('$home/.config/bolan/themes');
  }
}
