import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/workspace/workspace.dart';
import '../core/workspace/workspace_registry.dart';
import 'session_provider.dart';

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
/// disk reads route to the new workspace's directory, persists the
/// choice in `workspaces.toml`, and invalidates [sessionProvider] so
/// the session rebuilds against the new workspace's history + layout.
///
/// Until the family-keyed session refactor lands this is a "tear down
/// and rebuild" — running commands in the previous workspace are
/// terminated. Acceptable for an early sidebar implementation; the
/// follow-up that keeps background PTYs alive will replace this.
final switchWorkspaceActionProvider =
    Provider<Future<void> Function(String)>((ref) {
  return (String id) async {
    final registry = ref.read(workspaceRegistryProvider);
    if (registry.activeId == id) return;
    await registry.setActive(id);
    // setActive already updates WorkspacePaths.activeWorkspaceId.
    // Force the session to rebuild against the new workspace's files.
    ref.invalidate(sessionProvider);
  };
});

