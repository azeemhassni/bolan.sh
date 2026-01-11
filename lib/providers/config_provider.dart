import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/config_loader.dart';

/// Global config loader instance, set by TerminalShell.
///
/// Widgets can read this to access config values like line height,
/// cursor style, etc.
final configLoaderProvider = StateProvider<ConfigLoader?>((ref) => null);
