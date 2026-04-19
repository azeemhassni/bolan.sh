import 'dart:io';

import 'package:flutter/services.dart';

/// A single key binding: modifier flags + a logical key.
class KeyBinding {
  final bool meta;
  final bool ctrl;
  final bool shift;
  final bool alt;
  final LogicalKeyboardKey key;

  const KeyBinding({
    this.meta = false,
    this.ctrl = false,
    this.shift = false,
    this.alt = false,
    required this.key,
  });

  /// Whether the current hardware state matches this binding.
  bool matches({
    required bool metaDown,
    required bool ctrlDown,
    required bool shiftDown,
    required bool altDown,
    required LogicalKeyboardKey pressed,
  }) {
    return meta == metaDown &&
        ctrl == ctrlDown &&
        shift == shiftDown &&
        alt == altDown &&
        key == pressed;
  }

  /// Human-readable label like "⌘T" or "Ctrl+T".
  String get label {
    final parts = <String>[];
    if (Platform.isMacOS) {
      if (ctrl) parts.add('⌃');
      if (alt) parts.add('⌥');
      if (shift) parts.add('⇧');
      if (meta) parts.add('⌘');
    } else {
      if (ctrl) parts.add('Ctrl');
      if (alt) parts.add('Alt');
      if (shift) parts.add('Shift');
      if (meta) parts.add('Super');
    }
    parts.add(_keyLabel(key));
    return Platform.isMacOS ? parts.join(' ') : parts.join(' + ');
  }

  /// Serialize to a string like "meta+shift+keyT".
  String serialize() {
    final parts = <String>[];
    if (meta) parts.add('meta');
    if (ctrl) parts.add('ctrl');
    if (shift) parts.add('shift');
    if (alt) parts.add('alt');
    parts.add(_serializeKey(key));
    return parts.join('+');
  }

  /// Parse from a string like "meta+shift+keyT".
  static KeyBinding? parse(String s) {
    final parts = s.split('+');
    if (parts.isEmpty) return null;
    bool meta = false, ctrl = false, shift = false, alt = false;
    String? keyPart;
    for (final p in parts) {
      switch (p) {
        case 'meta':
          meta = true;
        case 'ctrl':
          ctrl = true;
        case 'shift':
          shift = true;
        case 'alt':
          alt = true;
        default:
          keyPart = p;
      }
    }
    if (keyPart == null) return null;
    final key = _parseKey(keyPart);
    if (key == null) return null;
    return KeyBinding(meta: meta, ctrl: ctrl, shift: shift, alt: alt, key: key);
  }

  @override
  bool operator ==(Object other) =>
      other is KeyBinding &&
      meta == other.meta &&
      ctrl == other.ctrl &&
      shift == other.shift &&
      alt == other.alt &&
      key == other.key;

  @override
  int get hashCode => Object.hash(meta, ctrl, shift, alt, key);
}

/// All customizable actions. Widget-internal navigation (palette arrows,
/// find bar escape, etc.) is excluded — those are standard UI patterns.
enum KeyAction {
  // ── Global ──
  zoomIn,
  zoomOut,
  resetZoom,
  togglePalette,
  quit,
  openSettings,
  toggleSidebar,
  newTab,
  closeTab,
  closePane,
  nextTab,
  previousTab,
  reorderTabLeft,
  reorderTabRight,
  splitRight,
  splitDown,
  navigatePaneLeft,
  navigatePaneRight,
  navigatePaneUp,
  navigatePaneDown,
  find,
  focusPrompt,
  // ── Workspace ──
  workspace1,
  workspace2,
  workspace3,
  workspace4,
  workspace5,
  workspace6,
  workspace7,
  workspace8,
  workspace9,
  // ── Prompt ──
  historySearch,
  cursorToStart,
  cursorToEnd,
  killLine,
  killToEnd,
  deleteWordBefore,
  sendSigint,
  clearScrollback,
  clearAll,
}

extension KeyActionMeta on KeyAction {
  String get displayName => switch (this) {
        KeyAction.zoomIn => 'Zoom in',
        KeyAction.zoomOut => 'Zoom out',
        KeyAction.resetZoom => 'Reset zoom',
        KeyAction.togglePalette => 'Command palette',
        KeyAction.quit => 'Quit',
        KeyAction.openSettings => 'Settings',
        KeyAction.toggleSidebar => 'Toggle sidebar',
        KeyAction.newTab => 'New tab',
        KeyAction.closeTab => 'Close tab',
        KeyAction.closePane => 'Close pane',
        KeyAction.nextTab => 'Next tab',
        KeyAction.previousTab => 'Previous tab',
        KeyAction.reorderTabLeft => 'Move tab left',
        KeyAction.reorderTabRight => 'Move tab right',
        KeyAction.splitRight => 'Split right',
        KeyAction.splitDown => 'Split down',
        KeyAction.navigatePaneLeft => 'Navigate pane left',
        KeyAction.navigatePaneRight => 'Navigate pane right',
        KeyAction.navigatePaneUp => 'Navigate pane up',
        KeyAction.navigatePaneDown => 'Navigate pane down',
        KeyAction.find => 'Find',
        KeyAction.focusPrompt => 'Focus prompt',
        KeyAction.workspace1 => 'Switch to workspace 1',
        KeyAction.workspace2 => 'Switch to workspace 2',
        KeyAction.workspace3 => 'Switch to workspace 3',
        KeyAction.workspace4 => 'Switch to workspace 4',
        KeyAction.workspace5 => 'Switch to workspace 5',
        KeyAction.workspace6 => 'Switch to workspace 6',
        KeyAction.workspace7 => 'Switch to workspace 7',
        KeyAction.workspace8 => 'Switch to workspace 8',
        KeyAction.workspace9 => 'Switch to workspace 9',
        KeyAction.historySearch => 'History search',
        KeyAction.cursorToStart => 'Cursor to start',
        KeyAction.cursorToEnd => 'Cursor to end',
        KeyAction.killLine => 'Kill line',
        KeyAction.killToEnd => 'Kill to end',
        KeyAction.deleteWordBefore => 'Delete word before',
        KeyAction.sendSigint => 'Interrupt (Ctrl+C)',
        KeyAction.clearScrollback => 'Clear scrollback',
        KeyAction.clearAll => 'Clear all',
      };

  String get category => switch (this) {
        KeyAction.zoomIn ||
        KeyAction.zoomOut ||
        KeyAction.resetZoom ||
        KeyAction.togglePalette ||
        KeyAction.quit ||
        KeyAction.openSettings ||
        KeyAction.toggleSidebar ||
        KeyAction.newTab ||
        KeyAction.closeTab ||
        KeyAction.closePane ||
        KeyAction.nextTab ||
        KeyAction.previousTab ||
        KeyAction.reorderTabLeft ||
        KeyAction.reorderTabRight ||
        KeyAction.splitRight ||
        KeyAction.splitDown ||
        KeyAction.navigatePaneLeft ||
        KeyAction.navigatePaneRight ||
        KeyAction.navigatePaneUp ||
        KeyAction.navigatePaneDown ||
        KeyAction.find ||
        KeyAction.focusPrompt =>
          'Global',
        KeyAction.workspace1 ||
        KeyAction.workspace2 ||
        KeyAction.workspace3 ||
        KeyAction.workspace4 ||
        KeyAction.workspace5 ||
        KeyAction.workspace6 ||
        KeyAction.workspace7 ||
        KeyAction.workspace8 ||
        KeyAction.workspace9 =>
          'Workspaces',
        KeyAction.historySearch ||
        KeyAction.cursorToStart ||
        KeyAction.cursorToEnd ||
        KeyAction.killLine ||
        KeyAction.killToEnd ||
        KeyAction.deleteWordBefore ||
        KeyAction.sendSigint ||
        KeyAction.clearScrollback ||
        KeyAction.clearAll =>
          'Prompt',
      };
}

/// "meta" means Cmd on macOS, Ctrl on Linux — matching [isPrimaryModifierPressed].
bool get _isMac => Platform.isMacOS;

KeyBinding _primary(LogicalKeyboardKey key,
        {bool shift = false, bool alt = false}) =>
    KeyBinding(
        meta: _isMac, ctrl: !_isMac, shift: shift, alt: alt, key: key);

/// Default key bindings. These match the current hardcoded shortcuts.
final Map<KeyAction, KeyBinding> defaultKeyBindings = {
  KeyAction.zoomIn: _primary(LogicalKeyboardKey.equal),
  KeyAction.zoomOut: _primary(LogicalKeyboardKey.minus),
  KeyAction.resetZoom: _primary(LogicalKeyboardKey.digit0),
  KeyAction.togglePalette: _primary(LogicalKeyboardKey.keyP, shift: true),
  KeyAction.quit: _primary(LogicalKeyboardKey.keyQ),
  KeyAction.openSettings: _primary(LogicalKeyboardKey.comma),
  KeyAction.toggleSidebar: _primary(LogicalKeyboardKey.backslash),
  KeyAction.newTab: _primary(LogicalKeyboardKey.keyT),
  KeyAction.closeTab: _primary(LogicalKeyboardKey.keyW),
  KeyAction.closePane: _primary(LogicalKeyboardKey.keyW, shift: true),
  KeyAction.nextTab: KeyBinding(ctrl: true, key: LogicalKeyboardKey.tab),
  KeyAction.previousTab:
      KeyBinding(ctrl: true, shift: true, key: LogicalKeyboardKey.tab),
  KeyAction.reorderTabLeft:
      _primary(LogicalKeyboardKey.arrowLeft, shift: true),
  KeyAction.reorderTabRight:
      _primary(LogicalKeyboardKey.arrowRight, shift: true),
  KeyAction.splitRight: _primary(LogicalKeyboardKey.keyD),
  KeyAction.splitDown: _primary(LogicalKeyboardKey.keyD, shift: true),
  KeyAction.navigatePaneLeft:
      _primary(LogicalKeyboardKey.arrowLeft, alt: true),
  KeyAction.navigatePaneRight:
      _primary(LogicalKeyboardKey.arrowRight, alt: true),
  KeyAction.navigatePaneUp: _primary(LogicalKeyboardKey.arrowUp, alt: true),
  KeyAction.navigatePaneDown:
      _primary(LogicalKeyboardKey.arrowDown, alt: true),
  KeyAction.find: _primary(LogicalKeyboardKey.keyF),
  KeyAction.focusPrompt: _primary(LogicalKeyboardKey.keyL),
  // Workspace switching: Ctrl+1–9 on all platforms.
  KeyAction.workspace1:
      KeyBinding(ctrl: true, key: LogicalKeyboardKey.digit1),
  KeyAction.workspace2:
      KeyBinding(ctrl: true, key: LogicalKeyboardKey.digit2),
  KeyAction.workspace3:
      KeyBinding(ctrl: true, key: LogicalKeyboardKey.digit3),
  KeyAction.workspace4:
      KeyBinding(ctrl: true, key: LogicalKeyboardKey.digit4),
  KeyAction.workspace5:
      KeyBinding(ctrl: true, key: LogicalKeyboardKey.digit5),
  KeyAction.workspace6:
      KeyBinding(ctrl: true, key: LogicalKeyboardKey.digit6),
  KeyAction.workspace7:
      KeyBinding(ctrl: true, key: LogicalKeyboardKey.digit7),
  KeyAction.workspace8:
      KeyBinding(ctrl: true, key: LogicalKeyboardKey.digit8),
  KeyAction.workspace9:
      KeyBinding(ctrl: true, key: LogicalKeyboardKey.digit9),
  // Prompt shortcuts.
  KeyAction.historySearch:
      KeyBinding(ctrl: true, key: LogicalKeyboardKey.keyR),
  KeyAction.cursorToStart:
      KeyBinding(ctrl: true, key: LogicalKeyboardKey.keyA),
  KeyAction.cursorToEnd:
      KeyBinding(ctrl: true, key: LogicalKeyboardKey.keyE),
  KeyAction.killLine: KeyBinding(ctrl: true, key: LogicalKeyboardKey.keyU),
  KeyAction.killToEnd: KeyBinding(ctrl: true, key: LogicalKeyboardKey.keyK),
  KeyAction.deleteWordBefore:
      KeyBinding(ctrl: true, key: LogicalKeyboardKey.keyW),
  KeyAction.sendSigint: KeyBinding(ctrl: true, key: LogicalKeyboardKey.keyC),
  KeyAction.clearScrollback:
      KeyBinding(ctrl: true, key: LogicalKeyboardKey.keyL),
  KeyAction.clearAll: _primary(LogicalKeyboardKey.keyK),
};

/// Resolves a [KeyAction] to its binding, checking overrides first.
KeyBinding bindingFor(KeyAction action, Map<KeyAction, KeyBinding> overrides) {
  return overrides[action] ?? defaultKeyBindings[action]!;
}

/// Finds which action (if any) the given key state maps to.
KeyAction? matchAction({
  required bool metaDown,
  required bool ctrlDown,
  required bool shiftDown,
  required bool altDown,
  required LogicalKeyboardKey pressed,
  required Map<KeyAction, KeyBinding> overrides,
  Iterable<KeyAction>? scope,
}) {
  final actions = scope ?? KeyAction.values;
  for (final action in actions) {
    final binding = overrides[action] ?? defaultKeyBindings[action]!;
    if (binding.matches(
      metaDown: metaDown,
      ctrlDown: ctrlDown,
      shiftDown: shiftDown,
      altDown: altDown,
      pressed: pressed,
    )) {
      return action;
    }
  }
  return null;
}

// ── Key label helpers ──────────────────────────────────────────

String _keyLabel(LogicalKeyboardKey k) {
  return _keyNames[k.keyId] ?? k.keyLabel;
}

String _serializeKey(LogicalKeyboardKey k) {
  return _serializeNames[k.keyId] ?? 'key_${k.keyId}';
}

LogicalKeyboardKey? _parseKey(String s) {
  return _deserializeMap[s];
}

final _keyNames = <int, String>{
  LogicalKeyboardKey.arrowUp.keyId: '↑',
  LogicalKeyboardKey.arrowDown.keyId: '↓',
  LogicalKeyboardKey.arrowLeft.keyId: '←',
  LogicalKeyboardKey.arrowRight.keyId: '→',
  LogicalKeyboardKey.tab.keyId: 'Tab',
  LogicalKeyboardKey.enter.keyId: 'Enter',
  LogicalKeyboardKey.escape.keyId: 'Esc',
  LogicalKeyboardKey.backspace.keyId: '⌫',
  LogicalKeyboardKey.delete.keyId: 'Del',
  LogicalKeyboardKey.space.keyId: 'Space',
  LogicalKeyboardKey.equal.keyId: '=',
  LogicalKeyboardKey.minus.keyId: '-',
  LogicalKeyboardKey.comma.keyId: ',',
  LogicalKeyboardKey.period.keyId: '.',
  LogicalKeyboardKey.backslash.keyId: '\\',
  LogicalKeyboardKey.slash.keyId: '/',
  LogicalKeyboardKey.bracketLeft.keyId: '[',
  LogicalKeyboardKey.bracketRight.keyId: ']',
  LogicalKeyboardKey.semicolon.keyId: ';',
  LogicalKeyboardKey.quoteSingle.keyId: "'",
  LogicalKeyboardKey.backquote.keyId: '`',
  LogicalKeyboardKey.digit0.keyId: '0',
  LogicalKeyboardKey.digit1.keyId: '1',
  LogicalKeyboardKey.digit2.keyId: '2',
  LogicalKeyboardKey.digit3.keyId: '3',
  LogicalKeyboardKey.digit4.keyId: '4',
  LogicalKeyboardKey.digit5.keyId: '5',
  LogicalKeyboardKey.digit6.keyId: '6',
  LogicalKeyboardKey.digit7.keyId: '7',
  LogicalKeyboardKey.digit8.keyId: '8',
  LogicalKeyboardKey.digit9.keyId: '9',
};

final _serializeNames = <int, String>{
  LogicalKeyboardKey.arrowUp.keyId: 'arrowUp',
  LogicalKeyboardKey.arrowDown.keyId: 'arrowDown',
  LogicalKeyboardKey.arrowLeft.keyId: 'arrowLeft',
  LogicalKeyboardKey.arrowRight.keyId: 'arrowRight',
  LogicalKeyboardKey.tab.keyId: 'tab',
  LogicalKeyboardKey.enter.keyId: 'enter',
  LogicalKeyboardKey.escape.keyId: 'escape',
  LogicalKeyboardKey.backspace.keyId: 'backspace',
  LogicalKeyboardKey.delete.keyId: 'delete',
  LogicalKeyboardKey.space.keyId: 'space',
  LogicalKeyboardKey.equal.keyId: 'equal',
  LogicalKeyboardKey.minus.keyId: 'minus',
  LogicalKeyboardKey.comma.keyId: 'comma',
  LogicalKeyboardKey.period.keyId: 'period',
  LogicalKeyboardKey.backslash.keyId: 'backslash',
  LogicalKeyboardKey.slash.keyId: 'slash',
  LogicalKeyboardKey.bracketLeft.keyId: 'bracketLeft',
  LogicalKeyboardKey.bracketRight.keyId: 'bracketRight',
  LogicalKeyboardKey.semicolon.keyId: 'semicolon',
  LogicalKeyboardKey.quoteSingle.keyId: 'quoteSingle',
  LogicalKeyboardKey.backquote.keyId: 'backquote',
  LogicalKeyboardKey.digit0.keyId: 'digit0',
  LogicalKeyboardKey.digit1.keyId: 'digit1',
  LogicalKeyboardKey.digit2.keyId: 'digit2',
  LogicalKeyboardKey.digit3.keyId: 'digit3',
  LogicalKeyboardKey.digit4.keyId: 'digit4',
  LogicalKeyboardKey.digit5.keyId: 'digit5',
  LogicalKeyboardKey.digit6.keyId: 'digit6',
  LogicalKeyboardKey.digit7.keyId: 'digit7',
  LogicalKeyboardKey.digit8.keyId: 'digit8',
  LogicalKeyboardKey.digit9.keyId: 'digit9',
  LogicalKeyboardKey.keyA.keyId: 'keyA',
  LogicalKeyboardKey.keyB.keyId: 'keyB',
  LogicalKeyboardKey.keyC.keyId: 'keyC',
  LogicalKeyboardKey.keyD.keyId: 'keyD',
  LogicalKeyboardKey.keyE.keyId: 'keyE',
  LogicalKeyboardKey.keyF.keyId: 'keyF',
  LogicalKeyboardKey.keyG.keyId: 'keyG',
  LogicalKeyboardKey.keyH.keyId: 'keyH',
  LogicalKeyboardKey.keyI.keyId: 'keyI',
  LogicalKeyboardKey.keyJ.keyId: 'keyJ',
  LogicalKeyboardKey.keyK.keyId: 'keyK',
  LogicalKeyboardKey.keyL.keyId: 'keyL',
  LogicalKeyboardKey.keyM.keyId: 'keyM',
  LogicalKeyboardKey.keyN.keyId: 'keyN',
  LogicalKeyboardKey.keyO.keyId: 'keyO',
  LogicalKeyboardKey.keyP.keyId: 'keyP',
  LogicalKeyboardKey.keyQ.keyId: 'keyQ',
  LogicalKeyboardKey.keyR.keyId: 'keyR',
  LogicalKeyboardKey.keyS.keyId: 'keyS',
  LogicalKeyboardKey.keyT.keyId: 'keyT',
  LogicalKeyboardKey.keyU.keyId: 'keyU',
  LogicalKeyboardKey.keyV.keyId: 'keyV',
  LogicalKeyboardKey.keyW.keyId: 'keyW',
  LogicalKeyboardKey.keyX.keyId: 'keyX',
  LogicalKeyboardKey.keyY.keyId: 'keyY',
  LogicalKeyboardKey.keyZ.keyId: 'keyZ',
};

final _deserializeMap = <String, LogicalKeyboardKey>{
  for (final e in _serializeNames.entries)
    e.value: LogicalKeyboardKey.findKeyByKeyId(e.key)!,
};
