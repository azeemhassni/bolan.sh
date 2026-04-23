import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/bolan_theme.dart';
import '../../core/workspace/workspace_icons.dart';
import '../../core/workspace/workspace_paths.dart';

/// Grid picker for a workspace's icon.
///
/// Emits one of:
/// - `''` — "None" tile tapped.
/// - `'material:<key>'` — a built-in icon tile tapped.
/// - `'svg'` — user uploaded a custom SVG. The file is copied to
///   `<workspace-dir>/icon.svg` before the callback fires, but only
///   when [workspaceId] is provided. Pass `supportSvg: false` in
///   flows that don't yet have a stable workspace id (e.g. the
///   "new workspace" form) — the upload tile is hidden there.
class WorkspaceIconPicker extends StatefulWidget {
  final String currentIcon;
  final Color accentColor;
  final BolonTheme theme;
  final String? workspaceId;
  final bool supportSvg;
  final ValueChanged<String> onChanged;

  const WorkspaceIconPicker({
    super.key,
    required this.currentIcon,
    required this.accentColor,
    required this.theme,
    required this.onChanged,
    this.workspaceId,
    this.supportSvg = true,
  });

  @override
  State<WorkspaceIconPicker> createState() => _WorkspaceIconPickerState();
}

class _WorkspaceIconPickerState extends State<WorkspaceIconPicker> {
  static const double _tile = 40;
  static const double _radius = 6;

  Future<void> _pickSvg() async {
    final id = widget.workspaceId;
    if (id == null) return;
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(label: 'SVG', extensions: ['svg']),
      ],
    );
    if (file == null) return;
    final dest = WorkspacePaths.iconSvgFileFor(id);
    await dest.parent.create(recursive: true);
    await File(file.path).copy(dest.path);
    widget.onChanged(workspaceSvgIconMarker);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final current = widget.currentIcon;
    final showSvgTile = widget.supportSvg && widget.workspaceId != null;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _tileNone(t, current.isEmpty),
        for (final entry in workspaceMaterialIcons.entries)
          _tileMaterial(t, entry.key, entry.value,
              selected: current == '$workspaceMaterialIconPrefix${entry.key}'),
        if (current == workspaceSvgIconMarker) _tileSvgPreview(t),
        if (showSvgTile) _tileUpload(t),
      ],
    );
  }

  Widget _tileWrap({
    required BolonTheme t,
    required bool selected,
    required VoidCallback onTap,
    required Widget child,
    String? tooltip,
  }) {
    return _FocusableIconTile(
      selected: selected,
      onTap: onTap,
      theme: t,
      accentColor: widget.accentColor,
      size: _tile,
      radius: _radius,
      tooltip: tooltip,
      child: child,
    );
  }

  Widget _tileNone(BolonTheme t, bool selected) => _tileWrap(
        t: t,
        selected: selected,
        onTap: () => widget.onChanged(''),
        tooltip: 'None',
        child: Icon(Icons.block, size: 18, color: t.dimForeground),
      );

  Widget _tileMaterial(BolonTheme t, String key, IconData icon,
          {required bool selected}) =>
      _tileWrap(
        t: t,
        selected: selected,
        onTap: () => widget
            .onChanged('$workspaceMaterialIconPrefix$key'),
        tooltip: key,
        child: Icon(
          icon,
          size: 20,
          color: selected ? widget.accentColor : t.foreground,
        ),
      );

  Widget _tileSvgPreview(BolonTheme t) {
    final id = widget.workspaceId;
    if (id == null) return const SizedBox.shrink();
    final file = WorkspacePaths.iconSvgFileFor(id);
    if (!file.existsSync()) return const SizedBox.shrink();
    return _tileWrap(
      t: t,
      selected: true,
      onTap: () {}, // already selected
      tooltip: 'Uploaded SVG',
      child: SvgPicture.file(
        file,
        width: 24,
        height: 24,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _tileUpload(BolonTheme t) => _tileWrap(
        t: t,
        selected: false,
        onTap: _pickSvg,
        tooltip: 'Upload SVG',
        child: Icon(Icons.upload, size: 18, color: t.dimForeground),
      );
}

/// Focusable, activatable 40×40 tile used by the icon picker. Keeps
/// the same visual (selected border + accent tint) and adds a focus
/// halo + Enter/Space keyboard activation.
class _FocusableIconTile extends StatefulWidget {
  final Widget child;
  final bool selected;
  final VoidCallback onTap;
  final BolonTheme theme;
  final Color accentColor;
  final double size;
  final double radius;
  final String? tooltip;

  const _FocusableIconTile({
    required this.child,
    required this.selected,
    required this.onTap,
    required this.theme,
    required this.accentColor,
    required this.size,
    required this.radius,
    this.tooltip,
  });

  @override
  State<_FocusableIconTile> createState() => _FocusableIconTileState();
}

class _FocusableIconTileState extends State<_FocusableIconTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final borderColor =
        widget.selected ? widget.accentColor : t.blockBorder;
    final bg = widget.selected
        ? widget.accentColor.withAlpha(24)
        : Colors.transparent;
    final core = GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(
            color: borderColor,
            width: widget.selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(widget.radius),
          boxShadow: _focused
              ? [
                  BoxShadow(
                    color: t.cursor,
                    spreadRadius: 2,
                    blurRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Center(child: widget.child),
      ),
    );
    final focusable = FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap();
            return null;
          },
        ),
      },
      child: core,
    );
    final tooltip = widget.tooltip;
    return tooltip == null
        ? focusable
        : Tooltip(message: tooltip, child: focusable);
  }
}
