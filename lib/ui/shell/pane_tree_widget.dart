import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/pane/pane_node.dart';
import '../../core/theme/bolan_theme.dart';
import '../../providers/session_provider.dart';
import 'pane_divider.dart';
import 'session_view.dart';

/// Recursively renders a [PaneNode] tree into split panes with dividers.
class PaneTreeWidget extends ConsumerWidget {
  final PaneNode node;
  final String focusedPaneId;

  const PaneTreeWidget({
    super.key,
    required this.node,
    required this.focusedPaneId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (node) {
      final LeafPane leaf => _LeafPaneWidget(
          leaf: leaf,
          isFocused: leaf.id == focusedPaneId,
        ),
      final SplitPane split => _SplitPaneWidget(
          split: split,
          focusedPaneId: focusedPaneId,
        ),
    };
  }
}

class _LeafPaneWidget extends ConsumerWidget {
  final LeafPane leaf;
  final bool isFocused;

  const _LeafPaneWidget({required this.leaf, required this.isFocused});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = BolonTheme.of(context);

    return GestureDetector(
      onTap: () => ref.read(sessionProvider.notifier).setFocusedPane(leaf.id),
      onSecondaryTapDown: (details) =>
          _showContextMenu(context, ref, details),
      child: Container(
        decoration: BoxDecoration(
          border: isFocused
              ? Border.all(color: theme.cursor.withAlpha(80), width: 1)
              : null,
        ),
        child: SessionView(
          key: ValueKey(leaf.id),
          session: leaf.session,
        ),
      ),
    );
  }

  void _showContextMenu(
    BuildContext context,
    WidgetRef ref,
    TapDownDetails details,
  ) {
    final notifier = ref.read(sessionProvider.notifier);
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx,
        details.globalPosition.dy,
        details.globalPosition.dx,
        details.globalPosition.dy,
      ),
      items: [
        const PopupMenuItem(value: 'split_right', child: Text('Split Right')),
        const PopupMenuItem(value: 'split_down', child: Text('Split Down')),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'close', child: Text('Close Pane')),
      ],
    ).then((value) {
      if (value == null) return;
      // Ensure this pane is focused before acting
      notifier.setFocusedPane(leaf.id);
      switch (value) {
        case 'split_right':
          notifier.splitPane(Axis.horizontal);
        case 'split_down':
          notifier.splitPane(Axis.vertical);
        case 'close':
          notifier.closePane();
      }
    });
  }
}

class _SplitPaneWidget extends ConsumerWidget {
  final SplitPane split;
  final String focusedPaneId;

  const _SplitPaneWidget({
    required this.split,
    required this.focusedPaneId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isHorizontal = split.axis == Axis.horizontal;
        final totalSize = isHorizontal
            ? constraints.maxWidth
            : constraints.maxHeight;
        const dividerSize = 4.0;
        final availableSize = totalSize - dividerSize;
        final firstSize = availableSize * split.ratio;
        final secondSize = availableSize * (1 - split.ratio);

        final children = <Widget>[
          SizedBox(
            width: isHorizontal ? firstSize : null,
            height: isHorizontal ? null : firstSize,
            child: PaneTreeWidget(
              node: split.first,
              focusedPaneId: focusedPaneId,
            ),
          ),
          PaneDivider(
            axis: split.axis,
            totalSize: totalSize,
            onDrag: (delta) {
              final newRatio = (split.ratio + delta).clamp(0.15, 0.85);
              ref
                  .read(sessionProvider.notifier)
                  .updateSplitRatio(split.id, newRatio);
            },
          ),
          SizedBox(
            width: isHorizontal ? secondSize : null,
            height: isHorizontal ? null : secondSize,
            child: PaneTreeWidget(
              node: split.second,
              focusedPaneId: focusedPaneId,
            ),
          ),
        ];

        if (isHorizontal) {
          return Row(children: children);
        }
        return Column(children: children);
      },
    );
  }
}
