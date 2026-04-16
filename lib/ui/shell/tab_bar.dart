import 'dart:async';
import 'dart:io';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macos_window_utils/widgets/macos_toolbar_passthrough.dart';
import 'package:macos_window_utils/window_manipulator.dart';

import '../../core/terminal/session.dart';
import '../../core/theme/bolan_theme.dart';
import '../../providers/session_provider.dart';
import '../../providers/workspace_provider.dart';

/// Whether a tab is currently being renamed. Checked by the global
/// key handler to avoid stealing keystrokes.
bool tabRenameActive = false;

const double _kMaxTabWidth = 200.0;
const double _kMinTabWidth = 130.0;

/// Compact tab bar rendered in the macOS title bar area.
///
/// Matches Warp's tab style: compact height, tight spacing, gradient-fade
/// only on overflow, status icons, hover close button.
class BolonTabBar extends ConsumerStatefulWidget {
  final void Function(int index)? onCloseTab;
  final bool sidebarOpen;
  final VoidCallback? onToggleSidebar;

  const BolonTabBar({
    super.key,
    this.onCloseTab,
    this.sidebarOpen = false,
    this.onToggleSidebar,
  });

  @override
  ConsumerState<BolonTabBar> createState() => _BolonTabBarState();
}

class _BolonTabBarState extends ConsumerState<BolonTabBar> {
  final _scrollController = ScrollController();
  final _tabKeys = <int, GlobalKey>{};
  DateTime? _lastTapDown;
  int? _lastActiveIndex;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(int index) =>
      _tabKeys.putIfAbsent(index, () => GlobalKey());

  Widget _buildTabItem(int index, SessionState sessionState, BolonTheme theme) {
    final tab = sessionState.tabs[index];
    final isActive = index == sessionState.activeTabIndex;

    if (tab.isSettings) {
      return KeyedSubtree(
        key: _keyFor(index),
        child: MacosToolbarPassthrough(
          child: _Tab(
            title: 'Settings',
            fullTitle: 'Settings',
            status: TabStatus.idle,
            isActive: isActive,
            isRenamed: false,
            icon: Icons.settings_outlined,
            canRename: false,
            theme: theme,
            onTap: () =>
                ref.read(currentSessionNotifierProvider).switchTab(index),
            onClose: () =>
                ref.read(currentSessionNotifierProvider).closeTab(index),
            onRename: (_) {},
          ),
        ),
      );
    }

    final session = tab.focusedSession;
    final title = tab.customTitle ?? session?.tabTitle ?? 'zsh';
    final fullTitle = tab.customTitle ?? session?.fullTabTitle ?? 'zsh';
    return KeyedSubtree(
      key: _keyFor(index),
      child: _DraggableTab(
        index: index,
        theme: theme,
        onReorder: (oldIndex, newIndex) => ref
            .read(currentSessionNotifierProvider)
            .reorderTab(oldIndex, newIndex),
        child: _Tab(
          title: title,
          fullTitle: fullTitle,
          status: session?.tabStatus ?? TabStatus.idle,
          isActive: isActive,
          isRenamed: tab.customTitle != null,
          theme: theme,
          onTap: () =>
              ref.read(currentSessionNotifierProvider).switchTab(index),
          onClose: () => widget.onCloseTab != null
              ? widget.onCloseTab!(index)
              : ref.read(currentSessionNotifierProvider).closeTab(index),
          onCloseOthers: sessionState.tabs.length > 1
              ? () => ref
                  .read(currentSessionNotifierProvider)
                  .closeOtherTabs(index)
              : null,
          onCloseRight: index < sessionState.tabs.length - 1
              ? () => ref
                  .read(currentSessionNotifierProvider)
                  .closeTabsToRight(index)
              : null,
          onRename: (name) =>
              ref.read(currentSessionNotifierProvider).renameTab(index, name),
        ),
      ),
    );
  }

  /// Scrolls the tab bar so the tab at [index] is fully visible.
  /// Uses the tab's actual render position, not an estimate.
  void _scrollToTab(int index) {
    final ctx = _tabKeys[index]?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      alignment: 0.5,
      alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
    );
  }

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
    final sessionState = ref.watch(currentSessionProvider);

    // Keep the active tab visible when it changes (e.g. keyboard switch
    // or keyboard reorder). Schedule after the frame so layout is ready.
    if (_lastActiveIndex != sessionState.activeTabIndex) {
      _lastActiveIndex = sessionState.activeTabIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToTab(sessionState.activeTabIndex);
      });
    }

    return Listener(
      onPointerDown: (_) => _handlePointerDown(),
      child: Container(
        height: 36,
        color: theme.tabBarBackground,
        child: Row(
          children: [
            // Sidebar toggle — placed after macOS traffic lights.
            if (widget.onToggleSidebar != null)
              Padding(
                padding: EdgeInsets.only(
                  left: Platform.isMacOS ? 78 : 8,
                ),
                child: MacosToolbarPassthrough(
                  child: _IconButton(
                    icon: widget.sidebarOpen
                        ? Icons.view_sidebar
                        : Icons.view_sidebar_outlined,
                    theme: theme,
                    onTap: widget.onToggleSidebar!,
                  ),
                ),
              ),
            // Tabs — expand to fill remaining space, scroll on overflow.
            // Individual tabs are wrapped in MacosToolbarPassthrough
            // (inside _DraggableTab) so empty scroll area remains a
            // window drag zone on macOS. On Linux the ListView's pan
            // recognizer wins the gesture arena over a Stacked
            // MoveWindow, so we swap in a non-scrolling Row whose
            // trailing space is an Expanded MoveWindow whenever the
            // tabs fit. On overflow we fall back to the ListView and
            // rely on the 100px handle below for window drag.
            Expanded(
              child: _TabScrollFades(
                controller: _scrollController,
                background: theme.tabBarBackground,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final tabs = sessionState.tabs;
                    // When the sidebar toggle is present it already
                    // provides the macOS traffic-light offset.
                    final leftPad = widget.onToggleSidebar != null
                        ? 4.0
                        : (Platform.isMacOS ? 78.0 : 8.0);
                    final tabsFit = Platform.isLinux &&
                        leftPad + tabs.length * _kMaxTabWidth <=
                            constraints.maxWidth;

                    if (tabsFit) {
                      return Row(
                        children: [
                          SizedBox(width: leftPad),
                          for (var i = 0; i < tabs.length; i++)
                            _buildTabItem(i, sessionState, theme),
                          Expanded(child: MoveWindow()),
                        ],
                      );
                    }
                    return ListView.builder(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      itemCount: tabs.length,
                      padding: EdgeInsets.only(left: leftPad),
                      itemBuilder: (context, index) =>
                          _buildTabItem(index, sessionState, theme),
                    );
                  },
                ),
              ),
            ),
            // Dedicated drag handle. On macOS the native title bar
            // handles drag; on Linux this is a reliable fallback for
            // when the tab list overflows and the Expanded MoveWindow
            // above is absent.
            SizedBox(
              width: 100,
              height: 36,
              child: Platform.isLinux ? MoveWindow() : null,
            ),
            // + and settings buttons
            MacosToolbarPassthrough(
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _IconButton(
                      icon: Icons.add,
                      theme: theme,
                      onTap: () =>
                          ref.read(currentSessionNotifierProvider).createTab(),
                    ),
                    const SizedBox(width: 2),
                    _IconButton(
                      icon: Icons.settings_outlined,
                      theme: theme,
                      onTap: () => ref
                          .read(currentSessionNotifierProvider)
                          .openSettingsTab(),
                    ),
                  ],
                ),
              ),
            ),
            if (Platform.isLinux) _LinuxWindowButtons(theme: theme),
          ],
        ),
      ),
    );
  }
}

class _Tab extends ConsumerStatefulWidget {
  final String title;
  final String fullTitle;
  final TabStatus status;
  final bool isActive;
  final bool isRenamed;
  final IconData? icon;
  final bool canRename;
  final BolonTheme theme;
  final VoidCallback onTap;
  final VoidCallback onClose;
  final VoidCallback? onCloseOthers;
  final VoidCallback? onCloseRight;
  final ValueChanged<String?> onRename;

  const _Tab({
    required this.title,
    required this.fullTitle,
    required this.status,
    required this.isActive,
    this.isRenamed = false,
    this.icon,
    this.canRename = true,
    required this.theme,
    required this.onTap,
    required this.onClose,
    this.onCloseOthers,
    this.onCloseRight,
    required this.onRename,
  });

  @override
  ConsumerState<_Tab> createState() => _TabState();
}

class _TabState extends ConsumerState<_Tab> {
  bool _hovered = false;
  bool _editing = false;
  late TextEditingController _editController;

  /// True briefly after a running command finishes successfully so the
  /// tab can flash a checkmark before settling back to idle.
  bool _showSuccess = false;
  Timer? _successFadeTimer;
  static const _successFadeDelay = Duration(seconds: 3);

  static const _maxTabWidth = _kMaxTabWidth;
  static const _minTabWidth = _kMinTabWidth;
  static const _fontSize = 11.0;
  static const _accentHeight = 2.0;
  static const _closeSlotWidth = 14.0;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController();
  }

  @override
  void didUpdateWidget(_Tab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Detect running → idle transition (with no error). Briefly show
    // a checkmark, then fade back to plain idle.
    if (oldWidget.status == TabStatus.running &&
        widget.status == TabStatus.idle) {
      setState(() => _showSuccess = true);
      _successFadeTimer?.cancel();
      _successFadeTimer = Timer(_successFadeDelay, () {
        if (mounted) setState(() => _showSuccess = false);
      });
    } else if (widget.status != TabStatus.idle && _showSuccess) {
      // Any new activity supersedes the success fade.
      _successFadeTimer?.cancel();
      _showSuccess = false;
    }
  }

  @override
  void dispose() {
    _successFadeTimer?.cancel();
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
        if (widget.canRename)
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
              color: theme.foreground,
              fontFamily: theme.fontFamily,
              fontSize: 12,
            ),
          ),
        ),
        if (widget.onCloseRight != null)
          PopupMenuItem(
            value: 'close_right',
            height: 32,
            child: Text(
              'Close Tabs to the Right',
              style: TextStyle(
                color: theme.foreground,
                fontFamily: theme.fontFamily,
                fontSize: 12,
              ),
            ),
          ),
        if (widget.onCloseOthers != null)
          PopupMenuItem(
            value: 'close_others',
            height: 32,
            child: Text(
              'Close All Other Tabs',
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
      if (value == 'close_right') widget.onCloseRight?.call();
      if (value == 'close_others') widget.onCloseOthers?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    // Active tab matches the content area below — visually connecting
    // the selected tab to the panel it controls. Inactive tabs blend
    // into the bar; hover lifts them slightly.
    final bg = widget.isActive
        ? t.background
        : _hovered
            ? t.statusChipBg
            : t.tabBarBackground;
    final fg = widget.isActive ? t.foreground : t.dimForeground;
    final fontWeight = widget.isActive ? FontWeight.w500 : FontWeight.normal;
    final showCloseButton = _hovered || widget.isActive;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _editing ? null : widget.onTap,
        onSecondaryTapDown: _editing
            ? null
            : (details) => _showContextMenu(details, context),
        child: Tooltip(
          message: widget.fullTitle,
          waitDuration: const Duration(milliseconds: 600),
          child: Container(
            margin: const EdgeInsets.only(right: 2),
            constraints: const BoxConstraints(
              maxWidth: _maxTabWidth,
              minWidth: _minTabWidth,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
              ),
            ),
            child: Stack(
              children: [
                // Accent strip on top of the active tab.
                if (widget.isActive)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: _accentHeight,
                    child: Container(
                      decoration: BoxDecoration(
                        color: ref.watch(currentWorkspaceProvider).accentColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(6),
                          topRight: Radius.circular(6),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: _editing
                      ? _buildEditField(fg)
                      : Row(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            if (widget.icon != null)
                              Icon(widget.icon,
                                  size: 12, color: fg)
                            else
                              _StatusIcon(
                                status: widget.status,
                                showSuccess: _showSuccess,
                                theme: t,
                              ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Center(
                                child: _buildTitle(fg, fontWeight),
                              ),
                            ),
                            const SizedBox(width: 4),
                            SizedBox(
                              width: _closeSlotWidth,
                              height: _closeSlotWidth,
                              child: showCloseButton
                                  ? GestureDetector(
                                      onTap: widget.onClose,
                                      child: MouseRegion(
                                        cursor: SystemMouseCursors.click,
                                        child: Icon(
                                          Icons.close,
                                          size: 11,
                                          color: t.dimForeground,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                          ],
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

/// Status indicator at the start of each tab. Reserves a fixed slot
/// so the title doesn't shift as state changes.
///
/// - running: pulsing dot in `ansiGreen`
/// - error: filled red circle
/// - success (transient post-run): green checkmark
/// - idle: empty slot (still reserves space)
class _StatusIcon extends StatefulWidget {
  final TabStatus status;
  final bool showSuccess;
  final BolonTheme theme;

  const _StatusIcon({
    required this.status,
    required this.showSuccess,
    required this.theme,
  });

  @override
  State<_StatusIcon> createState() => _StatusIconState();
}

class _StatusIconState extends State<_StatusIcon>
    with SingleTickerProviderStateMixin {
  static const double _slotSize = 11;

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    if (widget.status == TabStatus.running) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_StatusIcon old) {
    super.didUpdateWidget(old);
    final wasRunning = old.status == TabStatus.running;
    final isRunning = widget.status == TabStatus.running;
    if (isRunning && !wasRunning) {
      _pulseController.repeat(reverse: true);
    } else if (!isRunning && wasRunning) {
      _pulseController.stop();
      _pulseController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;

    Widget child;
    switch (widget.status) {
      case TabStatus.running:
        child = AnimatedBuilder(
          animation: _pulseController,
          builder: (_, __) {
            // Pulse opacity between 0.45 and 1.0.
            final v = 0.45 + (_pulseController.value * 0.55);
            return Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: t.ansiGreen.withValues(alpha: v),
                shape: BoxShape.circle,
              ),
            );
          },
        );
        break;
      case TabStatus.error:
        child = Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: t.exitFailureFg,
            shape: BoxShape.circle,
          ),
        );
        break;
      case TabStatus.idle:
        if (widget.showSuccess) {
          child = Icon(
            Icons.check,
            size: 10,
            color: t.exitSuccessFg,
          );
        } else {
          child = const SizedBox.shrink();
        }
        break;
    }

    return SizedBox(
      width: _slotSize,
      height: _slotSize,
      child: Center(child: child),
    );
  }
}

class _LinuxWindowButtons extends StatelessWidget {
  final BolonTheme theme;
  const _LinuxWindowButtons({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _WinBtn(
            icon: Icons.remove,
            theme: theme,
            onTap: () => appWindow.minimize(),
          ),
          _WinBtn(
            icon: Icons.crop_square,
            theme: theme,
            onTap: () => appWindow.maximizeOrRestore(),
          ),
          _WinBtn(
            icon: Icons.close,
            theme: theme,
            hoverColor: const Color(0xFFE81123),
            onTap: () => appWindow.close(),
          ),
        ],
      ),
    );
  }
}

class _WinBtn extends StatefulWidget {
  final IconData icon;
  final BolonTheme theme;
  final VoidCallback onTap;
  final Color? hoverColor;
  const _WinBtn({
    required this.icon,
    required this.theme,
    required this.onTap,
    this.hoverColor,
  });

  @override
  State<_WinBtn> createState() => _WinBtnState();
}

class _WinBtnState extends State<_WinBtn> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _hovered
                ? (widget.hoverColor ?? widget.theme.statusChipBg)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            widget.icon,
            size: 12,
            color: _hovered && widget.hoverColor != null
                ? Colors.white
                : widget.theme.dimForeground,
          ),
        ),
      ),
    );
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

/// Wraps a [_Tab] in a [Draggable] + [DragTarget] pair so the user
/// can reorder tabs by dragging one onto another. The drag carries
/// the source index; the drop target reorders via [onReorder].
class _DraggableTab extends ConsumerStatefulWidget {
  final int index;
  final BolonTheme theme;
  final Widget child;
  final void Function(int oldIndex, int newIndex) onReorder;

  const _DraggableTab({
    required this.index,
    required this.theme,
    required this.child,
    required this.onReorder,
  });

  @override
  ConsumerState<_DraggableTab> createState() => _DraggableTabState();
}

class _DraggableTabState extends ConsumerState<_DraggableTab> {
  bool _hovering = false;
  bool _dropAfter = false;

  @override
  Widget build(BuildContext context) {
    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => details.data != widget.index,
      onMove: (details) {
        // Decide whether the drop should land BEFORE or AFTER this
        // tab based on whether the pointer is in its left or right
        // half. Computed in local coordinates.
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final local = box.globalToLocal(details.offset);
        // 40% threshold — easier to push tabs past each other in
        // either direction without having to cross the full midpoint.
        final after = local.dx > box.size.width * 0.4;
        if (after != _dropAfter || !_hovering) {
          setState(() {
            _hovering = true;
            _dropAfter = after;
          });
        }
      },
      onLeave: (_) => setState(() => _hovering = false),
      onAcceptWithDetails: (details) {
        final from = details.data;
        final to = widget.index + (_dropAfter ? 1 : 0);
        widget.onReorder(from, to);
        setState(() => _hovering = false);
      },
      builder: (context, candidate, rejected) {
        return Stack(
          children: [
            MacosToolbarPassthrough(
              child: Draggable<int>(
                data: widget.index,
                axis: Axis.horizontal,
                feedback: Material(
                  color: Colors.transparent,
                  child: SizedBox(
                    height: 36,
                    child: Opacity(opacity: 0.85, child: widget.child),
                  ),
                ),
                childWhenDragging:
                    Opacity(opacity: 0.35, child: widget.child),
                child: widget.child,
              ),
            ),
            // Drop indicator — a 2px accent stripe on the side the
            // dragged tab will land.
            if (_hovering)
              Positioned(
                left: _dropAfter ? null : 0,
                right: _dropAfter ? 0 : null,
                top: 4,
                bottom: 4,
                child: Container(
                  width: 2,
                  color: ref.watch(currentWorkspaceProvider).accentColor,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Overlays left/right gradient fades on a horizontal scroll area to
/// indicate that more content exists in that direction.
class _TabScrollFades extends StatefulWidget {
  final ScrollController controller;
  final Color background;
  final Widget child;

  const _TabScrollFades({
    required this.controller,
    required this.background,
    required this.child,
  });

  @override
  State<_TabScrollFades> createState() => _TabScrollFadesState();
}

class _TabScrollFadesState extends State<_TabScrollFades> {
  bool _showLeft = false;
  bool _showRight = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_update);
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_update);
    super.dispose();
  }

  void _update() {
    if (!widget.controller.hasClients) return;
    final pos = widget.controller.position;
    final left = pos.pixels > 1;
    final right = pos.pixels < pos.maxScrollExtent - 1;
    if (left != _showLeft || right != _showRight) {
      setState(() {
        _showLeft = left;
        _showRight = right;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (_) {
        _update();
        return false;
      },
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          widget.child,
          if (_showLeft)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 24,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        widget.background,
                        widget.background.withAlpha(0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (_showRight)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 24,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [
                        widget.background,
                        widget.background.withAlpha(0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
