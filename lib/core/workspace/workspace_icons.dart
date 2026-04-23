import 'package:flutter/material.dart';

/// Curated set of general-purpose icons users can pick for a workspace.
/// Keys are short kebab-case slugs persisted in `workspaces.toml` as
/// `icon = "material:<key>"`. Adding an entry here makes it available
/// in the picker automatically.
const Map<String, IconData> workspaceMaterialIcons = {
  'work': Icons.work_outline,
  'home': Icons.home_outlined,
  'code': Icons.code,
  'terminal': Icons.terminal,
  'rocket': Icons.rocket_launch_outlined,
  'bug': Icons.bug_report_outlined,
  'cloud': Icons.cloud_outlined,
  'lock': Icons.lock_outlined,
  'build': Icons.build_outlined,
  'science': Icons.science_outlined,
  'flag': Icons.flag_outlined,
  'star': Icons.star_outline,
  'favorite': Icons.favorite_outline,
  'palette': Icons.palette_outlined,
  'tune': Icons.tune,
  'folder': Icons.folder_outlined,
  'book': Icons.menu_book_outlined,
  'wallet': Icons.account_balance_wallet_outlined,
  'globe': Icons.public,
  'school': Icons.school_outlined,
};

/// Marker value stored in `Workspace.icon` when the user uploaded a
/// custom SVG. The file lives at `WorkspacePaths.iconSvgFileFor(id)`.
const String workspaceSvgIconMarker = 'svg';

/// Prefix used in `Workspace.icon` for Material icon references:
/// `material:<key>` where `<key>` is a slug from [workspaceMaterialIcons].
const String workspaceMaterialIconPrefix = 'material:';

/// Resolves a `Workspace.icon` string to a Material [IconData] when it
/// refers to a built-in icon; returns null otherwise (empty icon, SVG,
/// or unknown key).
IconData? materialIconFor(String icon) {
  if (!icon.startsWith(workspaceMaterialIconPrefix)) return null;
  return workspaceMaterialIcons[icon.substring(workspaceMaterialIconPrefix.length)];
}
