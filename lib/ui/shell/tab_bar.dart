import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macos_window_utils/widgets/titlebar_safe_area.dart';

import '../../core/terminal/session.dart';
import '../../core/theme/bolan_theme.dart';
import '../../providers/session_provider.dart';

/// Tab bar rendered in the macOS title bar area.
///
/// Shows tabs with dynamic titles (current/last command), status icons
/// (running dot, error icon), gradient-fade truncation, and tooltips.
class BolonTabBar extends ConsumerWidget {
  final VoidCallback? onSettings;

  const BolonTabBar({super.key, this.onSettings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = BolonTheme.of(context);
    final sessionState = ref.watch(sessionProvider);

    final content = SizedBox(
      height: 38,
      child: Row(
        children: [
          // Tabs — scrollable
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: sessionState.sessions.length,
              padding: const EdgeInsets.only(left: 8, top: 6, bottom: 6),
              itemBuilder: (context, index) {
                final session = sessionState.sessions[index];
                final isActive = index == sessionState.activeIndex;
                return _Tab(
                  title: session.tabTitle,
                  fullTitle: session.fullTabTitle,
                  status: session.tabStatus,
                  isActive: isActive,
                  theme: theme,
                  onTap: () =>
                      ref.read(sessionProvider.notifier).switchTo(index),
                  onClose: () =>
                      ref.read(sessionProvider.notifier).closeSession(index),
                );
              },
            ),
          ),
          // Action buttons
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onSettings != null)
                  _IconButton(
                    icon: Icons.settings_outlined,
                    theme: theme,
                    onTap: onSettings!,
                  ),
                const SizedBox(width: 4),
                _IconButton(
                  icon: Icons.add,
                  theme: theme,
                  onTap: () =>
                      ref.read(sessionProvider.notifier).createSession(),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (Platform.isMacOS) {
      return Container(
        color: theme.tabBarBackground,
        child: TitlebarSafeArea(child: content),
      );
    }

    return Container(
      color: theme.tabBarBackground,
      child: content,
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

  @override
  Widget build(BuildContext context) {
    final bg = widget.isActive
        ? widget.theme.blockBackground
        : _hovered
            ? widget.theme.statusChipBg
            : Colors.transparent;
    final fg = widget.isActive
        ? widget.theme.foreground
        : widget.theme.dimForeground;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 180, minWidth: 60),
          margin: const EdgeInsets.only(right: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Status icon
              _StatusIcon(status: widget.status, theme: widget.theme),

              // Tab title with gradient fade + tooltip
              Flexible(
                child: Tooltip(
                  message: widget.fullTitle,
                  waitDuration: const Duration(milliseconds: 500),
                  child: ShaderMask(
                    shaderCallback: (Rect bounds) {
                      return const LinearGradient(
                        stops: [0.0, 0.7, 1.0],
                        colors: [
                          Colors.white,
                          Colors.white,
                          Colors.transparent,
                        ],
                      ).createShader(bounds);
                    },
                    blendMode: BlendMode.dstIn,
                    child: Text(
                      widget.title,
                      overflow: TextOverflow.clip,
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        color: fg,
                        fontSize: 12,
                        fontFamily: 'Operator Mono',
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
              ),

              // Close button
              if (_hovered || widget.isActive) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: widget.onClose,
                  child: Icon(
                    Icons.close,
                    size: 13,
                    color: widget.theme.dimForeground,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
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
          padding: const EdgeInsets.only(right: 6),
          child: Text(
            '●',
            style: TextStyle(
              color: theme.ansiGreen,
              fontSize: 8,
              decoration: TextDecoration.none,
            ),
          ),
        );
      case TabStatus.error:
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Icon(
            Icons.error_outline,
            size: 13,
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
        child: Icon(
          icon,
          size: 16,
          color: theme.dimForeground,
        ),
      ),
    );
  }
}
