import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macos_window_utils/window_manipulator.dart';

import '../../core/terminal/session.dart';
import '../../core/theme/bolan_theme.dart';
import '../../providers/session_provider.dart';

/// Whether a tab is currently being renamed. Checked by the global
/// key handler to avoid stealing keystrokes.
bool tabRenameActive = false;

/// Compact tab bar rendered in the macOS title bar area.
///
/// Matches Warp's tab style: compact height, tight spacing, gradient-fade
/// only on overflow, status icons, hover close button.
class BolonTabBar extends ConsumerStatefulWidget {
  final VoidCallback? onSettings;
  final void Function(int index)? onCloseTab;

  const BolonTabBar({super.key, this.onSettings, this.onCloseTab});

  @override
  ConsumerState<BolonTabBar> createState() => _BolonTabBarState();
}

class _BolonTabBarState extends ConsumerState<BolonTabBar> {
  DateTime? _lastTapDown;

  void _handlePointerDown() {
    if (!Platform.isMacOS) return;
    final now = DateTime.now();
    if (_lastTapDown != null &&
        now.difference(_lastTapDown!).inMilliseconds < 300) {
      WindowManipulator.isWindowZoomed().then((zoomed) {
        if (zoomed) {
          WindowManipulator.unzoomWindow();
        } else {
          WindowManipulator.zoomWindow();
        }
      });
      _lastTapDown = null;
    } else {
      _lastTapDown = now;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);
    final sessionState = ref.watch(sessionProvider);

    return Listener(
      onPointerDown: (_) => _handlePointerDown(),
      child: Container(
        height: 36,
        color: theme.tabBarBackground,
        child: Row(
          children: [
            // Tabs
            Expanded(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: sessionState.tabs.length,
                padding: EdgeInsets.only(
                  left: Platform.isMacOS ? 78 : 8,
                ),
                itemBuilder: (context, index) {
                  final tab = sessionState.tabs[index];
                  final session = tab.focusedSession;
                  final isActive = index == sessionState.activeTabIndex;
                  final title = tab.customTitle ??
                      session?.tabTitle ??
                      'zsh';
                  final fullTitle = tab.customTitle ??
                      session?.fullTabTitle ??
                      'zsh';
                  return _Tab(
                    title: title,
                    fullTitle: fullTitle,
                    status: session?.tabStatus ?? TabStatus.idle,
                    isActive: isActive,
                    isRenamed: tab.customTitle != null,
                    theme: theme,
                    onTap: () =>
                        ref.read(sessionProvider.notifier).switchTab(index),
                    onClose: () => widget.onCloseTab != null
                        ? widget.onCloseTab!(index)
                        : ref.read(sessionProvider.notifier).closeTab(index),
                    onRename: (name) =>
                        ref.read(sessionProvider.notifier).renameTab(index, name),
                  );
                },
              ),
            ),
            // + button
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _IconButton(
                    icon: Icons.add,
                    theme: theme,
                    onTap: () =>
                        ref.read(sessionProvider.notifier).createTab(),
                  ),
                  if (widget.onSettings != null) ...[
                    const SizedBox(width: 2),
                    _IconButton(
                      icon: Icons.settings_outlined,
                      theme: theme,
                      onTap: widget.onSettings!,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatefulWidget {
  final String title;
  final String fullTitle;
  final TabStatus status;
  final bool isActive;
  final bool isRenamed;
  final BolonTheme theme;
  final VoidCallback onTap;
  final VoidCallback onClose;
  final ValueChanged<String?> onRename;

  const _Tab({
    required this.title,
    required this.fullTitle,
    required this.status,
    required this.isActive,
    this.isRenamed = false,
    required this.theme,
    required this.onTap,
    required this.onClose,
    required this.onRename,
  });

  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> {
  bool _hovered = false;
  bool _editing = false;
  late TextEditingController _editController;

  /// Whether the title needs gradient fade (exceeds available space).
  /// We use a LayoutBuilder to detect this.
  static const _maxTabWidth = 180.0;
  static const _fontSize = 11.0;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController();
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  void _startEditing() {
    tabRenameActive = true;
    setState(() {
      _editing = true;
      _editController.text = widget.title;
      _editController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.title.length,
      );
    });
  }

  void _submitRename() {
    final name = _editController.text.trim();
    widget.onRename(name.isEmpty ? null : name);
    tabRenameActive = false;
    setState(() => _editing = false);
  }

  void _cancelEditing() {
    tabRenameActive = false;
    setState(() => _editing = false);
  }

  void _showContextMenu(TapDownDetails details, BuildContext context) {
    final theme = widget.theme;
    final position = details.globalPosition;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx, position.dy, position.dx, position.dy,
      ),
      color: theme.blockBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: theme.blockBorder, width: 1),
      ),
      items: [
        PopupMenuItem(
          value: 'rename',
          height: 32,
          child: Text(
            'Rename',
            style: TextStyle(
              color: theme.foreground,
              fontFamily: theme.fontFamily,
              fontSize: 12,
            ),
          ),
        ),
        if (widget.isRenamed)
          PopupMenuItem(
            value: 'reset',
            height: 32,
            child: Text(
              'Reset Name',
              style: TextStyle(
                color: theme.dimForeground,
                fontFamily: theme.fontFamily,
                fontSize: 12,
              ),
            ),
          ),
        PopupMenuItem(
          value: 'close',
          height: 32,
          child: Text(
            'Close Tab',
            style: TextStyle(
              color: theme.exitFailureFg,
              fontFamily: theme.fontFamily,
              fontSize: 12,
            ),
          ),
        ),
      ],
    ).then((value) {
      if (value == 'rename') _startEditing();
      if (value == 'reset') widget.onRename(null);
      if (value == 'close') widget.onClose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isActive
        ? widget.theme.tabBarBackground
        : _hovered
            ? widget.theme.statusChipBg
            : widget.theme.blockBackground;
    final fg = widget.isActive
        ? widget.theme.foreground
        : widget.theme.dimForeground;
    final fontWeight = widget.isActive ? FontWeight.w500 : FontWeight.normal;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _editing ? null : widget.onTap,
        onDoubleTap: _editing ? null : _startEditing,
        onSecondaryTapDown: _editing
            ? null
            : (details) => _showContextMenu(details, context),
        child: Tooltip(
          message: widget.fullTitle,
          waitDuration: const Duration(milliseconds: 600),
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: _maxTabWidth,
              minWidth: 130,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: bg,
              border: Border(
                right: BorderSide(
                  color: widget.theme.blockBorder,
                  width: 1,
                ),
              ),
            ),
            child: _editing
                ? _buildEditField(fg)
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _StatusIcon(
                              status: widget.status, theme: widget.theme),
                          Flexible(child: _buildTitle(fg, fontWeight)),
                        ],
                      ),
                      if (_hovered && !_editing)
                        Positioned(
                          right: 0,
                          child: GestureDetector(
                            onTap: widget.onClose,
                            child: Icon(
                              Icons.close,
                              size: 11,
                              color: widget.theme.dimForeground,
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditField(Color fg) {
    return Center(
      child: SizedBox(
        height: 16,
        child: Material(
          color: Colors.transparent,
          child: Focus(
            onKeyEvent: (_, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              if (event.logicalKey == LogicalKeyboardKey.enter) {
                _submitRename();
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.escape) {
                _cancelEditing();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: TextField(
              controller: _editController,
              autofocus: true,
              textAlignVertical: TextAlignVertical.center,
              style: TextStyle(
                color: fg,
                fontSize: _fontSize,
                fontFamily: widget.theme.fontFamily,
                height: 1.0,
              ),
              cursorColor: widget.theme.cursor,
              cursorHeight: 11,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
                isCollapsed: true,
              ),
              onSubmitted: (_) => _submitRename(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(Color fg, FontWeight fontWeight) {
    final text = Text(
      widget.title,
      overflow: TextOverflow.clip,
      maxLines: 1,
      softWrap: false,
      style: TextStyle(
        color: fg,
        fontSize: _fontSize,
        fontFamily: widget.theme.fontFamily,
        fontWeight: fontWeight,
        decoration: TextDecoration.none,
      ),
    );

    // Use LayoutBuilder to detect if the text overflows.
    // Only apply gradient fade when it actually clips.
    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: widget.title,
            style: TextStyle(fontSize: _fontSize, fontFamily: widget.theme.fontFamily),
          ),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout();

        final overflows = textPainter.width > constraints.maxWidth;

        if (!overflows) return text;

        return ShaderMask(
          shaderCallback: (Rect bounds) {
            return const LinearGradient(
              stops: [0.0, 0.75, 1.0],
              colors: [
                Colors.white,
                Colors.white,
                Colors.transparent,
              ],
            ).createShader(bounds);
          },
          blendMode: BlendMode.dstIn,
          child: text,
        );
      },
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final TabStatus status;
  final BolonTheme theme;

  const _StatusIcon({required this.status, required this.theme});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case TabStatus.running:
        return Padding(
          padding: const EdgeInsets.only(right: 5),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: theme.ansiGreen,
              shape: BoxShape.circle,
            ),
          ),
        );
      case TabStatus.error:
        return Padding(
          padding: const EdgeInsets.only(right: 5),
          child: Icon(
            Icons.error_outline,
            size: 11,
            color: theme.exitFailureFg,
          ),
        );
      case TabStatus.idle:
        return const SizedBox.shrink();
    }
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final BolonTheme theme;
  final VoidCallback onTap;

  const _IconButton({
    required this.icon,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            icon,
            size: 14,
            color: theme.dimForeground,
          ),
        ),
      ),
    );
  }
}
