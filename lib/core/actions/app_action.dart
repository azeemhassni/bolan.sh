import 'package:flutter/widgets.dart';

/// A registered action that can be invoked from the command palette
/// or keyboard shortcuts.
class AppAction {
  final String id;
  final String label;
  final String? shortcut;
  final IconData? icon;
  final List<String> keywords;
  final VoidCallback callback;

  const AppAction({
    required this.id,
    required this.label,
    this.shortcut,
    this.icon,
    this.keywords = const [],
    required this.callback,
  });
}
