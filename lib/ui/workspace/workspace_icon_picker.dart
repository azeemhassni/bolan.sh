import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
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
    final borderColor =
        selected ? widget.accentColor : t.blockBorder;
    final bg =
        selected ? widget.accentColor.withAlpha(24) : Colors.transparent;
    final content = GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: _tile,
          height: _tile,
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(
              color: borderColor,
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(_radius),
          ),
          child: Center(child: child),
        ),
      ),
    );
    return tooltip == null ? content : Tooltip(message: tooltip, child: content);
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
