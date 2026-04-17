import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/workspace/workspace.dart';
import '../core/workspace/workspace_registry.dart';
import 'config_provider.dart';

/// The single registry instance, populated at app startup before
/// `runApp` is called. Dependent providers can `ref.watch` this and
/// rebuild when workspaces are added, renamed, or switched.
final workspaceRegistryProvider =
    ChangeNotifierProvider<WorkspaceRegistry>((ref) {
  // Set by main() via overrideWith before runApp.
  throw UnimplementedError(
    'workspaceRegistryProvider must be overridden in ProviderScope.',
  );
});

/// The currently-active workspace. Rebuilds when the user switches.
final currentWorkspaceProvider = Provider<Workspace>((ref) {
  return ref.watch(workspaceRegistryProvider).active;
});

/// Switches the active workspace. Updates [WorkspacePaths] so subsequent
/// disk reads route to the new workspace's directory and persists the
/// choice in `workspaces.toml`. Each workspace has its own
/// [SessionNotifier] via [sessionFamily], so background PTYs stay alive.
final switchWorkspaceActionProvider =
    Provider<Future<void> Function(String)>((ref) {
  return (String id) async {
    final registry = ref.read(workspaceRegistryProvider);
    if (registry.activeId == id) return;
    // Each workspace has its own SessionNotifier via sessionFamily.
    // Switching just changes which one currentSessionProvider routes to.
    // No invalidation needed — the old workspace's PTYs stay alive.
    await registry.setActive(id);
    // Reload config synchronously so the new workspace's theme, font,
    // shell, and AI settings are in memory BEFORE any widget rebuilds.
    // Without this, widgets see the previous workspace's config for
    // at least one frame.
    final configLoader = ref.read(configLoaderProvider);
    await configLoader.load();
  };
});

