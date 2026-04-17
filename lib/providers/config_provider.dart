import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/config_loader.dart';
import '../core/notifications/notification_service.dart';

/// Global config loader instance. Loaded in main.dart before runApp
/// and overridden into ProviderScope so the first frame has the full
/// config (working directory, shell, theme, etc.).
final configLoaderProvider =
    ChangeNotifierProvider<ConfigLoader>((ref) {
  // Overridden by main.dart — this fallback only runs in tests.
  return ConfigLoader();
});

/// Incremented every time the config file changes on disk. Widgets
/// that `ref.watch` this alongside `configLoaderProvider` will rebuild
/// when config values change, even though the ConfigLoader object
/// reference stays the same.
final configVersionProvider = StateProvider<int>((ref) => 0);

/// Global notification service instance, set by TerminalShell.
final notificationServiceProvider =
    StateProvider<NotificationService?>((ref) => null);
