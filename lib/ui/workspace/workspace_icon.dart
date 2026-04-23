import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/workspace/workspace.dart';
import '../../core/workspace/workspace_icons.dart';
import '../../core/workspace/workspace_paths.dart';

/// Renders the icon for a workspace.
///
/// Resolution order:
/// 1. If `workspace.icon == "svg"`, renders the SVG at
///    `<workspace-dir>/icon.svg` without applying a color filter so
///    brand logos keep their own colors.
/// 2. If `workspace.icon` starts with `material:<key>` and the key is
///    in the catalog, renders that Material icon tinted with
///    [tintColor] (defaults to the workspace's accent).
/// 3. Otherwise renders [fallback] — callers pass an accent dot for
///    the sidebar and an initial-letter tile for settings rows.
class WorkspaceIcon extends StatelessWidget {
  final Workspace workspace;

  /// Visual size of the icon (the SizedBox bounds). Material icons
  /// render at this size; SVGs are scaled to fit.
  final double size;

  /// Tint applied to Material icons. Ignored for SVGs. Defaults to the
  /// workspace's accent color.
  final Color? tintColor;

  /// Shown when the workspace has no icon set.
  final Widget fallback;

  const WorkspaceIcon({
    super.key,
    required this.workspace,
    required this.size,
    required this.fallback,
    this.tintColor,
  });

  @override
  Widget build(BuildContext context) {
    final icon = workspace.icon;
    if (icon.isEmpty) return fallback;

    if (icon == workspaceSvgIconMarker) {
      final file = WorkspacePaths.iconSvgFileFor(workspace.id);
      if (!file.existsSync()) return fallback;
      return SizedBox(
        width: size,
        height: size,
        child: SvgPicture.file(
          file,
          width: size,
          height: size,
          fit: BoxFit.contain,
          placeholderBuilder: (_) => fallback,
        ),
      );
    }

    final material = materialIconFor(icon);
    if (material == null) return fallback;
    return Icon(
      material,
      size: size,
      color: tintColor ?? workspace.accentColor,
    );
  }
}
