import 'package:flutter/foundation.dart';

import 'bolan_theme.dart';
import 'default_dark.dart';

/// Registry of all available themes (built-in + custom).
///
/// Provides lookup by name with fallback to default-dark.
class ThemeRegistry extends ChangeNotifier {
  final Map<String, BolonTheme> _themes = {};

  ThemeRegistry() {
    // Register built-in themes
    _register(bolonDefaultDark);
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

  /// Registers a built-in theme.
  void _register(BolonTheme theme) {
    _themes[theme.name] = theme;
  }

  /// Registers a built-in theme (for use by theme files).
  void registerBuiltIn(BolonTheme theme) {
    _themes[theme.name] = theme;
  }

  /// Adds or updates a custom theme.
  void addCustomTheme(BolonTheme theme) {
    if (_themes.containsKey(theme.name) &&
        _themes[theme.name]!.isBuiltIn) {
      debugPrint('Cannot overwrite built-in theme: ${theme.name}');
      return;
    }
    _themes[theme.name] = theme;
    notifyListeners();
  }

  /// Removes a custom theme (cannot remove built-ins).
  void removeCustomTheme(String name) {
    final theme = _themes[name];
    if (theme == null || theme.isBuiltIn) return;
    _themes.remove(name);
    notifyListeners();
  }

  /// Whether a theme name exists.
  bool hasTheme(String name) => _themes.containsKey(name);
}
