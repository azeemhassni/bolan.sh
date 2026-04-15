import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/workspace/workspace_registry.dart';

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
