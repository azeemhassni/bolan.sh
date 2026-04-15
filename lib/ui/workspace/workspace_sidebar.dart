import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/bolan_theme.dart';
import '../../core/workspace/workspace.dart';
import '../../providers/session_provider.dart';
import '../../providers/workspace_provider.dart';

/// Vertical rail listing workspaces. Click an item to switch; the
/// active item is highlighted with its accent color.
///
/// Switching invalidates the session provider so the new workspace's
/// tabs and history take over. (PTYs from the previous workspace are
/// torn down for now — keeping them alive in background is a follow-up.)
class WorkspaceSidebar extends ConsumerWidget {
  const WorkspaceSidebar({super.key});

  static const double width = 60;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = BolonTheme.of(context);
    final registry = ref.watch(workspaceRegistryProvider);
    final activeId = registry.activeId;

    return Container(
      width: width,
      color: theme.tabBarBackground,
      child: Column(
        children: [
          const SizedBox(height: 8),
          for (final w in registry.workspaces)
            _WorkspaceItem(
              workspace: w,
              isActive: w.id == activeId,
              onTap: () => _switchTo(ref, w.id),
            ),
          const Spacer(),
          _AddWorkspaceButton(
            theme: theme,
            onTap: () =>
                ref.read(sessionProvider.notifier).openSettingsTab(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _switchTo(WidgetRef ref, String id) async {
    final switcher = ref.read(switchWorkspaceActionProvider);
    await switcher(id);
  }
}

class _WorkspaceItem extends StatefulWidget {
  final Workspace workspace;
  final bool isActive;
  final VoidCallback onTap;

  const _WorkspaceItem({
    required this.workspace,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_WorkspaceItem> createState() => _WorkspaceItemState();
}

class _WorkspaceItemState extends State<_WorkspaceItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.workspace.accentColor;
    final fill = widget.isActive ? accent : accent.withAlpha(40);
    final border = widget.isActive ? accent : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
      child: Tooltip(
        message: widget.workspace.name,
        waitDuration: const Duration(milliseconds: 400),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _hovered && !widget.isActive
                    ? accent.withAlpha(70)
                    : fill,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: border, width: 1.5),
              ),
              child: Center(
                child: Text(
                  widget.workspace.initial,
                  style: TextStyle(
                    color: widget.isActive
                        ? Colors.white
                        : accent.withAlpha(220),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddWorkspaceButton extends StatefulWidget {
  final BolonTheme theme;
  final VoidCallback onTap;

  const _AddWorkspaceButton({required this.theme, required this.onTap});

  @override
  State<_AddWorkspaceButton> createState() => _AddWorkspaceButtonState();
}

class _AddWorkspaceButtonState extends State<_AddWorkspaceButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Tooltip(
        message: 'New workspace',
        waitDuration: const Duration(milliseconds: 400),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _hovered
                    ? widget.theme.statusChipBg
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.add,
                size: 18,
                color: widget.theme.dimForeground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
