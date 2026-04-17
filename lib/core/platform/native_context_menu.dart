import 'dart:io';

import 'package:flutter/services.dart';

/// Shows the OS-native context menu via platform channel.
///
/// On macOS: NSMenu. On Linux: GtkMenu (TODO).
/// The native menu doesn't interfere with Flutter's gesture system,
/// so text selection in SelectableText is preserved.
class NativeContextMenu {
  static const _channel = MethodChannel('bolan/context_menu');

  /// Shows a native context menu at the current cursor position.
  /// Returns the [id] of the selected item, or null if dismissed.
  static Future<String?> show(List<NativeMenuItem> items) async {
    if (!Platform.isMacOS && !Platform.isLinux) {
      return null;
    }
    try {
      final result = await _channel.invokeMethod<String>('show', {
        'items': items.map((i) => i.toMap()).toList(),
      });
      return result;
    } on PlatformException {
      return null;
    }
  }
}

class NativeMenuItem {
  final String id;
  final String label;
  final String? shortcut;
  final bool enabled;
  final bool isSeparator;

  const NativeMenuItem({
    required this.id,
    required this.label,
    this.shortcut,
    this.enabled = true,
    this.isSeparator = false,
  });

  const NativeMenuItem.separator()
      : id = '',
        label = '',
        shortcut = null,
        enabled = false,
        isSeparator = true;

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        if (shortcut != null) 'shortcut': shortcut,
        'enabled': enabled,
        'isSeparator': isSeparator,
      };
}
