import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/bolan_theme.dart';
import '../../core/workspace/workspace.dart';
import '../../providers/session_provider.dart';
import '../../providers/workspace_provider.dart';
import '../shared/bolan_button.dart';

/// Vertical rail listing workspaces. Click an item to switch; the
/// active item is highlighted with its accent color. Two-finger
/// horizontal swipe inside the sidebar advances to the next/previous
/// workspace — confined to the sidebar gutter so it never conflicts
/// with horizontal scroll inside a terminal block (e.g. wide git diff).
///
/// Switching invalidates the session provider so the new workspace's
/// tabs and history take over. (PTYs from the previous workspace are
/// torn down for now — keeping them alive in background is a follow-up.)
class WorkspaceSidebar extends ConsumerStatefulWidget {
  const WorkspaceSidebar({super.key});

  static const double width = 220;

  @override
  ConsumerState<WorkspaceSidebar> createState() => _WorkspaceSidebarState();
}

class _WorkspaceSidebarState extends ConsumerState<WorkspaceSidebar> {
  /// Horizontal scroll accumulator. Trackpad scrolls deliver many
  /// small deltas; we only act once the cumulative motion exceeds
  /// [_swipeThreshold]. Reset after firing or when motion reverses.
  double _swipeAccum = 0;
  DateTime _lastSwipeAt = DateTime.fromMillisecondsSinceEpoch(0);

  static const double _swipeThreshold = 60;
  static const Duration _swipeCooldown = Duration(milliseconds: 350);

  void _handleScroll(PointerScrollEvent event) {
    final dx = event.scrollDelta.dx;
    final dy = event.scrollDelta.dy;
    // Reject mostly-vertical signals (regular scroll wheels).
    if (dx.abs() < dy.abs()) return;

    // Reset accumulator on direction reversal so two quick swipes in
    // opposite directions both register.
    if (_swipeAccum.sign != 0 && _swipeAccum.sign != dx.sign) {
      _swipeAccum = 0;
    }
    _swipeAccum += dx;

    if (_swipeAccum.abs() < _swipeThreshold) return;
    if (DateTime.now().difference(_lastSwipeAt) < _swipeCooldown) return;

    final direction = _swipeAccum > 0 ? 1 : -1;
    _swipeAccum = 0;
    _lastSwipeAt = DateTime.now();
    _advance(direction);
  }

  Future<void> _advance(int direction) async {
    final registry = ref.read(workspaceRegistryProvider);
    final list = registry.workspaces;
    if (list.length < 2) return;
    final currentIndex = list.indexWhere((w) => w.id == registry.activeId);
    if (currentIndex < 0) return;
    final nextIndex = (currentIndex + direction) % list.length;
    final wrapped = nextIndex < 0 ? nextIndex + list.length : nextIndex;
    final switcher = ref.read(switchWorkspaceActionProvider);
    await switcher(list[wrapped].id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);
    final registry = ref.watch(workspaceRegistryProvider);
    final activeId = registry.activeId;

    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) _handleScroll(event);
      },
      child: ClipRect(
        child: Container(
          width: WorkspaceSidebar.width,
          decoration: BoxDecoration(
            color: theme.tabBarBackground,
            border: Border(
              right: BorderSide(color: theme.blockBorder, width: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: Text(
                  'Workspaces',
                  style: TextStyle(
                    color: theme.dimForeground,
                    fontFamily: theme.fontFamily,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              for (final w in registry.workspaces)
                if (w.enabled)
                  _WorkspaceItem(
                    workspace: w,
                    isActive: w.id == activeId,
                    theme: theme,
                    onTap: () => _switchTo(w.id),
                  ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: BolanIconButton(
                  icon: Icons.add,
                  tooltip: 'New workspace',
                  onTap: () =>
                      ref.read(currentSessionNotifierProvider)
                          .openSettingsTab(initialSettingsTab: 5),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _switchTo(String id) async {
    final switcher = ref.read(switchWorkspaceActionProvider);
    await switcher(id);
  }
}

class _WorkspaceItem extends StatefulWidget {
  final Workspace workspace;
  final bool isActive;
  final BolonTheme theme;
  final VoidCallback onTap;

  const _WorkspaceItem({
    required this.workspace,
    required this.isActive,
    required this.theme,
    required this.onTap,
  });

  @override
  State<_WorkspaceItem> createState() => _WorkspaceItemState();
}

class _WorkspaceItemState extends State<_WorkspaceItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final accent = widget.workspace.accentColor;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isActive
                ? accent.withAlpha(30)
                : _hovered
                    ? t.statusChipBg
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.workspace.name,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    color: widget.isActive ? t.foreground : t.dimForeground,
                    fontFamily: t.fontFamily,
                    fontSize: 12,
                    fontWeight:
                        widget.isActive ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (widget.isActive)
                Icon(Icons.check, size: 12, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}

