import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/config_loader.dart';
import '../core/notifications/notification_service.dart';

/// Global config loader instance, set by TerminalShell.
///
/// Widgets can read this to access config values like line height,
/// cursor style, etc.
final configLoaderProvider = StateProvider<ConfigLoader?>((ref) => null);

/// Incremented every time the config file changes on disk. Widgets
/// that `ref.watch` this alongside `configLoaderProvider` will rebuild
/// when config values change, even though the ConfigLoader object
/// reference stays the same.
final configVersionProvider = StateProvider<int>((ref) => 0);

/// Global notification service instance, set by TerminalShell.
final notificationServiceProvider =
    StateProvider<NotificationService?>((ref) => null);
