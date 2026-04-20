import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/config/config_loader.dart';
import '../core/config/global_config.dart';
import '../core/config/keybinding.dart';
import '../core/notifications/notification_service.dart';

/// Per-workspace config loader. Loaded in main.dart before runApp
/// and overridden into ProviderScope so the first frame has the full
/// config (working directory, shell, theme, etc.).
final configLoaderProvider =
    ChangeNotifierProvider<ConfigLoader>((ref) {
  // Overridden by main.dart — this fallback only runs in tests.
  return ConfigLoader();
});

/// Global config loader (editor, theme, keybindings, updates).
/// Shared across all workspaces.
final globalConfigLoaderProvider =
    ChangeNotifierProvider<GlobalConfigLoader>((ref) {
  // Overridden by main.dart — this fallback only runs in tests.
  return GlobalConfigLoader();
});

/// Resolved config that merges global defaults with per-workspace
/// overrides. This is what UI consumers should read from.
final resolvedConfigProvider = Provider<ResolvedConfig>((ref) {
  final global = ref.watch(globalConfigLoaderProvider).config;
  final workspace = ref.watch(configLoaderProvider).config;
  return AppConfig.resolve(global, workspace);
});

/// Incremented every time the config file changes on disk. Widgets
/// that `ref.watch` this alongside `configLoaderProvider` will rebuild
/// when config values change, even though the ConfigLoader object
/// reference stays the same.
final configVersionProvider = StateProvider<int>((ref) => 0);

/// Keybinding overrides from the resolved config. Watches both
/// global and workspace config so changes take effect immediately.
final keybindingOverridesProvider =
    Provider<Map<KeyAction, KeyBinding>>((ref) {
  final resolved = ref.watch(resolvedConfigProvider);
  return resolved.keybindingOverrides;
});

/// Global notification service instance, set by TerminalShell.
final notificationServiceProvider =
    StateProvider<NotificationService?>((ref) => null);
