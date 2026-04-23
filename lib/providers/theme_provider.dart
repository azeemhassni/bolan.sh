import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/bolan_theme.dart';
import '../core/theme/theme_registry.dart';

/// The global theme registry — holds all built-in and custom themes.
/// Populated at app startup in main.dart (custom themes loaded before
/// runApp) and overridden into ProviderScope so the first frame already
/// has the full theme list.
final themeRegistryProvider = Provider<ThemeRegistry>((ref) {
  // Overridden by main.dart — this fallback only runs in tests.
  final registry = ThemeRegistry();
  registry.startWatching();
  ref.onDispose(registry.dispose);
  return registry;
});

/// The currently active theme name — synced with config.
final activeThemeNameProvider = StateProvider<String>((ref) => 'midnight-cove');

/// The resolved active [BolonTheme] — derived from name + registry.
final activeThemeProvider = Provider<BolonTheme>((ref) {
  final name = ref.watch(activeThemeNameProvider);
  final registry = ref.watch(themeRegistryProvider);
  return registry.getTheme(name);
});
