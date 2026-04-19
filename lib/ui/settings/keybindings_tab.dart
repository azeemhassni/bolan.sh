import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/config/keybinding.dart';
import '../../core/theme/bolan_theme.dart';

/// Settings tab for customizing keyboard shortcuts.
class KeybindingsTab extends StatefulWidget {
  /// True while the shortcut recorder is waiting for input.
  /// Checked by [_globalKeyHandler] to avoid intercepting the
  /// key the user is trying to record.
  static bool isRecording = false;

  final Map<KeyAction, KeyBinding> overrides;
  final ValueChanged<Map<KeyAction, KeyBinding>> onChanged;
  final BolonTheme theme;

  /// Other workspaces to copy keybindings from. Each entry is (id, name).
  final List<(String, String)> otherWorkspaces;

  /// Loads keybinding overrides from another workspace's config.
  final Future<Map<KeyAction, KeyBinding>> Function(String workspaceId)?
      loadFromWorkspace;

  const KeybindingsTab({
    super.key,
    required this.overrides,
    required this.onChanged,
    required this.theme,
    this.otherWorkspaces = const [],
    this.loadFromWorkspace,
  });

  @override
  State<KeybindingsTab> createState() => _KeybindingsTabState();
}

class _KeybindingsTabState extends State<KeybindingsTab> {
  String _search = '';
  KeyAction? _recording;
  final FocusNode _recorderFocus = FocusNode();

  late Map<KeyAction, KeyBinding> _overrides;

  @override
  void initState() {
    super.initState();
    _overrides = Map.of(widget.overrides);
  }

  @override
  void dispose() {
    KeybindingsTab.isRecording = false;
    _recorderFocus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(KeybindingsTab old) {
    super.didUpdateWidget(old);
    if (old.overrides != widget.overrides) {
      _overrides = Map.of(widget.overrides);
    }
  }

  void _resetToDefault(KeyAction action) {
    setState(() {
      _overrides.remove(action);
      _stopRecording();
    });
    widget.onChanged(_overrides);
  }

  void _resetAll() {
    setState(() {
      _overrides.clear();
      _stopRecording();
    });
    widget.onChanged(_overrides);
  }

  Future<void> _copyFrom(String workspaceId) async {
    final loader = widget.loadFromWorkspace;
    if (loader == null) return;
    final imported = await loader(workspaceId);
    setState(() {
      _overrides
        ..clear()
        ..addAll(imported);
    });
    widget.onChanged(_overrides);
  }

  void _startRecording(KeyAction action) {
    setState(() => _recording = action);
    KeybindingsTab.isRecording = true;
    _recorderFocus.requestFocus();
  }

  void _stopRecording() {
    _recording = null;
    KeybindingsTab.isRecording = false;
  }

  void _handleRecordedKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final action = _recording;
    if (action == null) return;

    final key = event.logicalKey;
    // Ignore bare modifier keys.
    if (key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight ||
        key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight) {
      return;
    }

    // Escape cancels recording.
    if (key == LogicalKeyboardKey.escape) {
      setState(() => _stopRecording());
      return;
    }

    final binding = KeyBinding(
      meta: HardwareKeyboard.instance.isMetaPressed,
      ctrl: HardwareKeyboard.instance.isControlPressed,
      shift: HardwareKeyboard.instance.isShiftPressed,
      alt: HardwareKeyboard.instance.isAltPressed,
      key: key,
    );

    // Check if this binding matches the default — if so, remove
    // the override rather than storing a redundant entry.
    final defaultBinding = defaultKeyBindings[action]!;
    if (binding == defaultBinding) {
      _overrides.remove(action);
    } else {
      _overrides[action] = binding;
    }

    setState(() => _stopRecording());
    widget.onChanged(_overrides);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;

    // Group actions by category.
    final groups = <String, List<KeyAction>>{};
    for (final action in KeyAction.values) {
      final cat = action.category;
      (groups[cat] ??= []).add(action);
    }

    // Filter by search.
    final query = _search.toLowerCase();
    final filteredGroups = <String, List<KeyAction>>{};
    for (final entry in groups.entries) {
      final filtered = entry.value.where((a) {
        if (query.isEmpty) return true;
        final binding = bindingFor(a, _overrides);
        return a.displayName.toLowerCase().contains(query) ||
            binding.label.toLowerCase().contains(query) ||
            entry.key.toLowerCase().contains(query);
      }).toList();
      if (filtered.isNotEmpty) {
        filteredGroups[entry.key] = filtered;
      }
    }

    return Focus(
      focusNode: _recorderFocus,
      onKeyEvent: (_, event) {
        if (_recording != null) {
          _handleRecordedKey(event);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search + Reset all
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: TextField(
                    style: TextStyle(
                      color: t.foreground,
                      fontFamily: t.fontFamily,
                      fontSize: 13,
                      decoration: TextDecoration.none,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search shortcuts...',
                      hintStyle: TextStyle(
                        color: t.dimForeground,
                        fontFamily: t.fontFamily,
                        fontSize: 13,
                        decoration: TextDecoration.none,
                      ),
                      prefixIcon: Icon(Icons.search,
                          size: 16, color: t.dimForeground),
                      filled: true,
                      fillColor: t.blockBackground,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide:
                            BorderSide(color: t.blockBorder, width: 1),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide:
                            BorderSide(color: t.blockBorder, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: t.cursor, width: 1),
                      ),
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                ),
              ),
              if (_overrides.isNotEmpty) ...[
                const SizedBox(width: 12),
                TextButton(
                  onPressed: _resetAll,
                  child: Text(
                    'Reset all',
                    style: TextStyle(
                      color: t.ansiRed,
                      fontFamily: t.fontFamily,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (widget.otherWorkspaces.isNotEmpty &&
              widget.loadFromWorkspace != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Copy from workspace:',
                  style: TextStyle(
                    color: t.dimForeground,
                    fontFamily: t.fontFamily,
                    fontSize: 13,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(width: 12),
                for (final (id, name) in widget.otherWorkspaces)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: TextButton(
                      onPressed: () => _copyFrom(id),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                          side: BorderSide(color: t.blockBorder, width: 1),
                        ),
                      ),
                      child: Text(
                        name,
                        style: TextStyle(
                          color: t.foreground,
                          fontFamily: t.fontFamily,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),

          // Shortcut list
          for (final entry in filteredGroups.entries) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 12),
              child: Text(
                entry.key,
                style: TextStyle(
                  color: t.dimForeground,
                  fontFamily: t.fontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            for (final action in entry.value)
              _ShortcutRow(
                action: action,
                binding: bindingFor(action, _overrides),
                isCustom: _overrides.containsKey(action),
                isRecording: _recording == action,
                theme: t,
                onRecord: () => _startRecording(action),
                onReset: () => _resetToDefault(action),
              ),
          ],
        ],
      ),
    );
  }
}

class _ShortcutRow extends StatefulWidget {
  final KeyAction action;
  final KeyBinding binding;
  final bool isCustom;
  final bool isRecording;
  final BolonTheme theme;
  final VoidCallback onRecord;
  final VoidCallback onReset;

  const _ShortcutRow({
    required this.action,
    required this.binding,
    required this.isCustom,
    required this.isRecording,
    required this.theme,
    required this.onRecord,
    required this.onReset,
  });

  @override
  State<_ShortcutRow> createState() => _ShortcutRowState();
}

class _ShortcutRowState extends State<_ShortcutRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: widget.isRecording
              ? t.cursor.withAlpha(20)
              : _hovered
                  ? t.statusChipBg
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            // Action name
            Expanded(
              child: Text(
                widget.action.displayName,
                style: TextStyle(
                  color: t.foreground,
                  fontFamily: t.fontFamily,
                  fontSize: 14,
                  decoration: TextDecoration.none,
                ),
              ),
            ),

            // Binding chip or recording state
            if (widget.isRecording)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: t.cursor.withAlpha(30),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: t.cursor, width: 1),
                ),
                child: Text(
                  'Press a key combo...  (Esc to cancel)',
                  style: TextStyle(
                    color: t.cursor,
                    fontFamily: t.fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.none,
                  ),
                ),
              )
            else
              GestureDetector(
                onTap: widget.onRecord,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: t.blockBackground,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: widget.isCustom
                            ? t.cursor.withAlpha(100)
                            : t.blockBorder,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      widget.binding.label,
                      style: TextStyle(
                        color: widget.isCustom ? t.cursor : t.foreground,
                        fontFamily: t.fontFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
              ),

            // Reset button (only for custom bindings)
            if (widget.isCustom && !widget.isRecording) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: widget.onReset,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Icon(
                    Icons.restart_alt,
                    size: 16,
                    color: t.dimForeground,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
