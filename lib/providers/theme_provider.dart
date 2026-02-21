import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/bolan_theme.dart';
import '../core/theme/theme_registry.dart';

/// The global theme registry — holds all built-in and custom themes.
final themeRegistryProvider = Provider<ThemeRegistry>((ref) {
  return ThemeRegistry();
});

/// The currently active theme name — synced with config.
final activeThemeNameProvider = StateProvider<String>((ref) => 'default-dark');

/// The resolved active [BolonTheme] — derived from name + registry.
final activeThemeProvider = Provider<BolonTheme>((ref) {
  final name = ref.watch(activeThemeNameProvider);
  final registry = ref.watch(themeRegistryProvider);
  return registry.getTheme(name);
});
