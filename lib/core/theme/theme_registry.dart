import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'bolan_theme.dart';
import 'default_dark.dart';
import 'theme_serializer.dart';
import 'themes/amethyst_dusk.dart';
import 'themes/carbon.dart';
import 'themes/coral_reef.dart';
import 'themes/default_light.dart';
import 'themes/dracula.dart';
import 'themes/ember.dart';
import 'themes/forest_dawn.dart';
import 'themes/gruvbox_dark.dart';
import 'themes/midnight_cove.dart';
import 'themes/monokai.dart';
import 'themes/nord.dart';
import 'themes/nordic_frost.dart';
import 'themes/one_dark.dart';
import 'themes/parchment.dart';
import 'themes/raskoh.dart';
import 'themes/sakura_morning.dart';
import 'themes/solarized_dark.dart';
import 'themes/solarized_light.dart';
import 'themes/terracotta.dart';
import 'themes/tokyo_night.dart';

/// Registry of all available themes (built-in + custom).
///
/// Provides lookup by name with fallback to default-dark.
/// Scans ~/.config/bolan/themes/ for custom TOML themes.
class ThemeRegistry extends ChangeNotifier {
  final Map<String, BolonTheme> _themes = {};
  Timer? _watchTimer;

  /// Names of the legacy built-ins — prior default set, kept for users
  /// who had them selected. Surfaced in a separate "Legacy" accordion
  /// in the theme picker so the primary set is what new users see first.
  static const _legacyNames = {
    'default-dark',
    'default-light',
    'dracula',
    'one-dark',
    'nord',
    'monokai',
    'solarized-dark',
    'solarized-light',
    'gruvbox-dark',
    'tokyo-night',
    'raskoh',
  };

  ThemeRegistry() {
    // Primary built-ins (registered first — shown at the top of the picker).
    _register(midnightCoveTheme);
    _register(parchmentTheme);
    _register(forestDawnTheme);
    _register(coralReefTheme);
    _register(amethystDuskTheme);
    _register(carbonTheme);
    _register(emberTheme);
    _register(nordicFrostTheme);
    _register(sakuraMorningTheme);
    _register(terracottaTheme);
    // Legacy built-ins.
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

  /// Whether a theme is one of the "legacy" built-ins (older set, kept
  /// for backward compatibility, rendered in an accordion).
  bool isLegacy(BolonTheme theme) =>
      theme.isBuiltIn && _legacyNames.contains(theme.name);

  /// Built-in themes that form the current default set (non-legacy),
  /// sorted alphabetically.
  List<BolonTheme> get primaryBuiltIns {
    return _themes.values
        .where((t) => t.isBuiltIn && !_legacyNames.contains(t.name))
        .toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
  }

  /// Legacy built-in themes, sorted alphabetically.
  List<BolonTheme> get legacyBuiltIns {
    return _themes.values
        .where((t) => t.isBuiltIn && _legacyNames.contains(t.name))
        .toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
  }

  /// User-created themes loaded from disk.
  List<BolonTheme> get customThemes {
    return _themes.values.where((t) => !t.isBuiltIn).toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
  }

  /// All available themes sorted: primary built-ins, custom, then legacy.
  List<BolonTheme> get allThemes =>
      [...primaryBuiltIns, ...customThemes, ...legacyBuiltIns];

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
