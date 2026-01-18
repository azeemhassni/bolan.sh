import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';

import '../terminal/command_history.dart';
import '../terminal/session.dart';
import 'pane_node.dart';

const _uuid = Uuid();

/// Pure functions for manipulating the pane tree.
class PaneManager {
  const PaneManager._();

  /// Splits the leaf with [targetId] into a [SplitPane] along [axis].
  /// Returns the new root and the newly created leaf pane.
  static (PaneNode, LeafPane) split(
    PaneNode root,
    String targetId,
    Axis axis,
    CommandHistory history,
  ) {
    final newLeaf = LeafPane(
      id: _uuid.v4(),
      session: TerminalSession.start(id: _uuid.v4(), history: history),
    );

    final newRoot = _replaceNode(root, targetId, (leaf) {
      return SplitPane(
        id: _uuid.v4(),
        first: leaf,
        second: newLeaf,
        axis: axis,
      );
    });

    return (newRoot, newLeaf);
  }

  /// Closes the leaf with [targetId]. Returns the new root, or null if
  /// it was the last pane. Disposes the closed session.
  static PaneNode? close(PaneNode root, String targetId) {
    if (root is LeafPane && root.id == targetId) {
      root.session.dispose();
      return null;
    }
    return _removeNode(root, targetId);
  }

  /// Finds the [LeafPane] with [id], or null.
  static LeafPane? findLeaf(PaneNode root, String id) {
    return switch (root) {
      LeafPane() => root.id == id ? root : null,
      SplitPane() => findLeaf(root.first, id) ?? findLeaf(root.second, id),
    };
  }

  /// Returns all leaf panes in the tree.
  static List<LeafPane> allLeaves(PaneNode root) {
    return switch (root) {
      LeafPane() => [root],
      SplitPane() => [...allLeaves(root.first), ...allLeaves(root.second)],
    };
  }

  /// Finds the adjacent pane in the given [direction] from [focusedId].
  static String? findAdjacentPane(
    PaneNode root,
    String focusedId,
    AxisDirection direction,
  ) {
    final path = _findPath(root, focusedId);
    if (path == null || path.length < 2) return null;

    // Walk up to find an ancestor split with matching axis
    final isHorizontal = direction == AxisDirection.left ||
        direction == AxisDirection.right;
    final targetAxis = isHorizontal ? Axis.horizontal : Axis.vertical;
    final goToSecond = direction == AxisDirection.right ||
        direction == AxisDirection.down;

    for (var i = path.length - 2; i >= 0; i--) {
      final node = path[i];
      if (node is! SplitPane || node.axis != targetAxis) continue;

      final child = path[i + 1];
      final isInFirst = identical(node.first, child);

      // If we're in first and going forward, or in second and going back
      if ((isInFirst && goToSecond) || (!isInFirst && !goToSecond)) {
        final target = isInFirst ? node.second : node.first;
        // Navigate to the edge-most leaf in the target subtree
        return _edgeLeaf(target, goToSecond ? false : true)?.id;
      }
    }
    return null;
  }

  /// Disposes all sessions in the tree.
  static void disposeAll(PaneNode root) {
    for (final leaf in allLeaves(root)) {
      leaf.session.dispose();
    }
  }

  // --- Internal helpers ---

  static PaneNode _replaceNode(
    PaneNode node,
    String targetId,
    PaneNode Function(LeafPane) replacer,
  ) {
    return switch (node) {
      LeafPane() => node.id == targetId ? replacer(node) : node,
      SplitPane() => SplitPane(
          id: node.id,
          first: _replaceNode(node.first, targetId, replacer),
          second: _replaceNode(node.second, targetId, replacer),
          axis: node.axis,
          ratio: node.ratio,
        ),
    };
  }

  static PaneNode? _removeNode(PaneNode node, String targetId) {
    if (node is! SplitPane) return node;

    if (node.first is LeafPane && (node.first as LeafPane).id == targetId) {
      (node.first as LeafPane).session.dispose();
      return node.second;
    }
    if (node.second is LeafPane && (node.second as LeafPane).id == targetId) {
      (node.second as LeafPane).session.dispose();
      return node.first;
    }

    final newFirst = _removeNode(node.first, targetId);
    if (!identical(newFirst, node.first)) {
      return newFirst == null
          ? node.second
          : SplitPane(
              id: node.id,
              first: newFirst,
              second: node.second,
              axis: node.axis,
              ratio: node.ratio,
            );
    }

    final newSecond = _removeNode(node.second, targetId);
    if (!identical(newSecond, node.second)) {
      return newSecond == null
          ? node.first
          : SplitPane(
              id: node.id,
              first: node.first,
              second: newSecond,
              axis: node.axis,
              ratio: node.ratio,
            );
    }

    return node;
  }

  /// Returns the path from root to the leaf with [id].
  static List<PaneNode>? _findPath(PaneNode node, String id) {
    if (node is LeafPane) {
      return node.id == id ? [node] : null;
    }
    if (node is SplitPane) {
      final left = _findPath(node.first, id);
      if (left != null) return [node, ...left];
      final right = _findPath(node.second, id);
      if (right != null) return [node, ...right];
    }
    return null;
  }

  /// Returns the edge-most leaf in a subtree.
  /// If [first] is true, returns the first (top/left) leaf.
  static LeafPane? _edgeLeaf(PaneNode node, bool first) {
    return switch (node) {
      LeafPane() => node,
      SplitPane() =>
        _edgeLeaf(first ? node.first : node.second, first),
    };
  }
}
