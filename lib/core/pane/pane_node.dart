import 'package:flutter/widgets.dart';

import '../terminal/session.dart';

/// Where a dragged pane should be placed relative to the drop target.
enum DropPosition { left, right, top, bottom }

/// A node in the pane tree. Either a leaf (single terminal) or a split
/// (two children separated by a resizable divider).
sealed class PaneNode {
  String get id;
}

/// A leaf pane containing a single terminal session.
class LeafPane extends PaneNode {
  @override
  final String id;
  final TerminalSession session;

  LeafPane({required this.id, required this.session});
}

/// A split pane containing two children with a divider.
///
/// [axis] determines layout:
///   - `Axis.horizontal` → children side by side (vertical divider)
///   - `Axis.vertical` → children stacked (horizontal divider)
///
/// [ratio] is the fraction of space given to [first] (0.0–1.0).
class SplitPane extends PaneNode {
  @override
  final String id;
  final PaneNode first;
  final PaneNode second;
  final Axis axis;
  double ratio;

  SplitPane({
    required this.id,
    required this.first,
    required this.second,
    required this.axis,
    this.ratio = 0.5,
  });
}
