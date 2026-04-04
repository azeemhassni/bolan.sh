import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macos_window_utils/window_manipulator.dart';

import '../../core/terminal/session.dart';
import '../../core/theme/bolan_theme.dart';
import '../../providers/session_provider.dart';

/// Compact tab bar rendered in the macOS title bar area.
///
/// Matches Warp's tab style: compact height, tight spacing, gradient-fade
/// only on overflow, status icons, hover close button.
class BolonTabBar extends ConsumerStatefulWidget {
  final VoidCallback? onSettings;

  const BolonTabBar({super.key, this.onSettings});

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
                  return _Tab(
                    title: session?.tabTitle ?? 'zsh',
                    fullTitle: session?.fullTabTitle ?? 'zsh',
                    status: session?.tabStatus ?? TabStatus.idle,
                    isActive: isActive,
                    theme: theme,
                    onTap: () =>
                        ref.read(sessionProvider.notifier).switchTab(index),
                    onClose: () =>
                        ref.read(sessionProvider.notifier).closeTab(index),
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
  final BolonTheme theme;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _Tab({
    required this.title,
    required this.fullTitle,
    required this.status,
    required this.isActive,
    required this.theme,
    required this.onTap,
    required this.onClose,
  });

  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> {
  bool _hovered = false;

  /// Whether the title needs gradient fade (exceeds available space).
  /// We use a LayoutBuilder to detect this.
  static const _maxTabWidth = 180.0;
  static const _fontSize = 11.0;

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
        onTap: widget.onTap,
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
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Centered title with status icon
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _StatusIcon(status: widget.status, theme: widget.theme),
                    Flexible(child: _buildTitle(fg, fontWeight)),
                  ],
                ),

                // Close button — pinned to right edge, hover only
                if (_hovered)
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

  Widget _buildTitle(Color fg, FontWeight fontWeight) {
    final text = Text(
      widget.title,
      overflow: TextOverflow.clip,
      maxLines: 1,
      softWrap: false,
      style: TextStyle(
        color: fg,
        fontSize: _fontSize,
        fontFamily: 'Operator Mono',
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
            style: const TextStyle(fontSize: _fontSize, fontFamily: 'Operator Mono'),
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
