import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macos_window_utils/widgets/titlebar_safe_area.dart';

import '../../core/theme/bolan_theme.dart';
import '../../providers/session_provider.dart';

/// Custom tab bar rendered inside the macOS title bar area.
///
/// Uses [TitlebarSafeArea] to keep tabs clear of the traffic light buttons.
/// Each tab shows the session title and a close button on hover.
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
          // Tab list — scrollable if many tabs
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: sessionState.sessions.length,
              padding: const EdgeInsets.only(left: 8, top: 6, bottom: 6),
              itemBuilder: (context, index) {
                final session = sessionState.sessions[index];
                final isActive = index == sessionState.activeIndex;
                return _Tab(
                  title: session.title,
                  isActive: isActive,
                  theme: theme,
                  onTap: () => ref.read(sessionProvider.notifier).switchTo(index),
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

    // On macOS, wrap in TitlebarSafeArea to avoid traffic lights.
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
  final bool isActive;
  final BolonTheme theme;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _Tab({
    required this.title,
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
          constraints: const BoxConstraints(maxWidth: 180, minWidth: 80),
          margin: const EdgeInsets.only(right: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  widget.title,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    color: fg,
                    fontSize: 12,
                    fontFamily: 'Operator Mono',
                  ),
                ),
              ),
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
