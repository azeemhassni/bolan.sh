import 'dart:async';
import 'dart:io';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macos_window_utils/macos_window_utils.dart';

import 'app.dart';
import 'core/ai/ai_provider_helper.dart';
import 'core/ai/model_manager.dart';
import 'core/config/config_loader.dart';
import 'core/system/linux_desktop_entry.dart';
import 'core/theme/theme_registry.dart';
import 'core/workspace/workspace_paths.dart';
import 'core/workspace/workspace_registry.dart';
import 'providers/config_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/workspace_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Resolve config root once so per-workspace path lookups can be sync.
  // Must run before ProviderScope so config/history loaders see the path.
  await WorkspacePaths.init();

  // Load the workspace registry. On first run after upgrade this also
  // migrates legacy state files into workspaces/default/ and sets
  // WorkspacePaths.activeWorkspaceId — must happen before any consumer
  // (config loader, session provider) reads from disk.
  final registry = WorkspaceRegistry();
  await registry.loadOrCreate();
  // Use setActive (not setActiveWorkspace directly) so secrets are
  // loaded from the keychain into the workspace before any PTY spawns.
  await registry.setActive(registry.activeId);

  // Load config before runApp so SessionNotifier.build() can read
  // working directory and shell settings on the very first frame.
  final configLoader = ConfigLoader();
  await configLoader.load();
  configLoader.startWatching();

  // Set AI model defaults from config (or system RAM if not configured).
  final recommended = await ModelManager.recommendedSize();
  AiProviderHelper.configuredLocalModelSize =
      configLoader.config.ai.localModelSize.isNotEmpty
          ? configLoader.config.ai.localModelSize
          : recommended.name;
  AiProviderHelper.configuredHuggingfaceModel =
      configLoader.config.ai.huggingfaceModel;

  // Load custom themes from disk before runApp so the first frame
  // has the full theme list (including any AI-generated themes).
  final themeRegistry = ThemeRegistry();
  await themeRegistry.loadCustomThemes();
  themeRegistry.startWatching();

  if (Platform.isMacOS) {
    await _initMacosWindow();
  }

  runApp(ProviderScope(
    overrides: [
      workspaceRegistryProvider.overrideWith((_) => registry),
      themeRegistryProvider.overrideWith((_) => themeRegistry),
      configLoaderProvider.overrideWith((_) => configLoader),
    ],
    child: const BolonApp(),
  ));

  if (Platform.isLinux) {
    // Install a .desktop entry + hicolor icons so GNOME/Wayland's dock
    // can resolve our app_id to a real icon. Fire-and-forget.
    unawaited(ensureLinuxDesktopEntry());
    doWhenWindowReady(() {
      const initialSize = Size(1100, 700);
      appWindow.minSize = const Size(600, 400);
      appWindow.size = initialSize;
      appWindow.alignment = Alignment.center;
      appWindow.title = 'Bolan';
      appWindow.show();
    });
  }
}

Future<void> _initMacosWindow() async {
  // flutter_acrylic's Window.initialize() calls WindowManipulator.initialize()
  // internally — calling both causes a "Future already completed" error.
  await Window.initialize();

  await WindowManipulator.makeTitlebarTransparent();
  await WindowManipulator.enableFullSizeContentView();
  await WindowManipulator.hideTitle();

  await Window.setEffect(
    effect: WindowEffect.sidebar,
    dark: true,
  );
}
