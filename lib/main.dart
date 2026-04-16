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
import 'core/system/linux_desktop_entry.dart';
import 'core/workspace/workspace_paths.dart';
import 'core/workspace/workspace_registry.dart';
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
  WorkspacePaths.setActiveWorkspace(registry.activeId, registry.active);

  // Set default local model size based on system RAM before any
  // config or provider reads it. If the user has overridden it in
  // their config, the config loader will replace this later.
  final recommended = await ModelManager.recommendedSize();
  AiProviderHelper.configuredLocalModelSize = recommended.name;

  if (Platform.isMacOS) {
    await _initMacosWindow();
  }

  runApp(ProviderScope(
    overrides: [
      workspaceRegistryProvider.overrideWith((_) => registry),
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
