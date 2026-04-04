import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Whether the platform primary modifier (Cmd on macOS, Ctrl on Linux) is
/// currently pressed.
bool get isPrimaryModifierPressed => Platform.isMacOS
    ? HardwareKeyboard.instance.isMetaPressed
    : HardwareKeyboard.instance.isControlPressed;

/// Creates a [SingleActivator] that uses Meta on macOS and Control on Linux.
SingleActivator primaryActivator(
  LogicalKeyboardKey key, {
  bool shift = false,
  bool alt = false,
}) {
  if (Platform.isMacOS) {
    return SingleActivator(key, meta: true, shift: shift, alt: alt);
  }
  return SingleActivator(key, control: true, shift: shift, alt: alt);
}
