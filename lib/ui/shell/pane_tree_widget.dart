import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final bool isSinglePane;

  const PaneTreeWidget({
    super.key,
    required this.node,
    required this.focusedPaneId,
    this.isSinglePane = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (node) {
      final LeafPane leaf => _LeafPaneWidget(
          leaf: leaf,
          isFocused: leaf.id == focusedPaneId,
          isSinglePane: isSinglePane,
        ),
      final SplitPane split => _SplitPaneWidget(
          split: split,
          focusedPaneId: focusedPaneId,
        ),
    };
  }
}

class _LeafPaneWidget extends ConsumerStatefulWidget {
  final LeafPane leaf;
  final bool isFocused;
  final bool isSinglePane;

  const _LeafPaneWidget({
    required this.leaf,
    required this.isFocused,
    this.isSinglePane = false,
  });

  @override
  ConsumerState<_LeafPaneWidget> createState() => _LeafPaneWidgetState();
}

class _LeafPaneWidgetState extends ConsumerState<_LeafPaneWidget> {
  DropPosition? _hoverPosition;

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);

    final Widget content = GestureDetector(
      onTap: () =>
          ref.read(sessionProvider.notifier).setFocusedPane(widget.leaf.id),
      onSecondaryTapDown: (details) =>
          _showContextMenu(context, details),
      child: Container(
        padding: widget.isSinglePane ? null : const EdgeInsets.all(4),
        decoration: widget.isSinglePane
            ? null
            : BoxDecoration(
                border: widget.isFocused
                    ? Border.all(color: theme.cursor.withAlpha(80), width: 1)
                    : Border.all(color: theme.blockBorder, width: 1),
              ),
        child: SessionView(
          key: ValueKey(widget.leaf.id),
          session: widget.leaf.session,
          isFocusedPane: widget.isFocused,
          paneId: widget.leaf.id,
          onSecondaryTap: (details) =>
              _showContextMenu(context, details),
        ),
      ),
    );

    // Wrap in DragTarget + Draggable for pane reordering
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) =>
          details.data != widget.leaf.id && !widget.isSinglePane,
      onAcceptWithDetails: (details) {
        if (_hoverPosition == null) return;
        ref.read(sessionProvider.notifier).movePane(
              details.data,
              widget.leaf.id,
              _hoverPosition!,
            );
        setState(() => _hoverPosition = null);
      },
      onMove: (details) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final local = box.globalToLocal(details.offset);
        final pos = _computeDropPosition(local, box.size);
        if (pos != _hoverPosition) setState(() => _hoverPosition = pos);
      },
      onLeave: (_) => setState(() => _hoverPosition = null),
      builder: (context, candidateData, rejectedData) {
        return Draggable<String>(
          data: widget.leaf.id,
          feedback: _buildDragFeedback(context, theme),
          childWhenDragging: Opacity(opacity: 0.3, child: content),
          child: Stack(
            children: [
              content,
              if (candidateData.isNotEmpty && _hoverPosition != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: _DropZoneOverlay(
                      activeZone: _hoverPosition!,
                      theme: theme,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  DropPosition _computeDropPosition(Offset local, Size size) {
    final nx = local.dx / size.width;
    final ny = local.dy / size.height;

    // Distance to each edge
    final dLeft = nx;
    final dRight = 1 - nx;
    final dTop = ny;
    final dBottom = 1 - ny;

    final minD = [dLeft, dRight, dTop, dBottom]
        .reduce((a, b) => a < b ? a : b);

    if (minD == dLeft) return DropPosition.left;
    if (minD == dRight) return DropPosition.right;
    if (minD == dTop) return DropPosition.top;
    return DropPosition.bottom;
  }

  Widget _buildDragFeedback(BuildContext context, BolonTheme theme) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 160,
        height: 80,
        decoration: BoxDecoration(
          color: theme.blockBackground.withAlpha(220),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.cursor.withAlpha(100), width: 1),
        ),
        alignment: Alignment.center,
        child: Text(
          widget.leaf.session.tabTitle,
          style: TextStyle(
            color: theme.foreground,
            fontFamily: 'Operator Mono',
            fontSize: 12,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }

  Future<void> _showContextMenu(
    BuildContext context,
    TapDownDetails details,
  ) async {
    final notifier = ref.read(sessionProvider.notifier);
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final hasClipboard = clipboardData?.text?.isNotEmpty ?? false;

    if (!context.mounted) return;

    final value = await showMenu<String>(
      context: context,
      popUpAnimationStyle: AnimationStyle.noAnimation,
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx,
        details.globalPosition.dy,
        details.globalPosition.dx,
        details.globalPosition.dy,
      ),
      items: [
        const PopupMenuItem(value: 'copy', child: Text('Copy')),
        PopupMenuItem(
          value: 'paste',
          enabled: hasClipboard,
          child: const Text('Paste'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
            value: 'split_right', child: Text('Split Right')),
        const PopupMenuItem(
            value: 'split_down', child: Text('Split Down')),
        if (!widget.isSinglePane) ...[
          const PopupMenuDivider(),
          const PopupMenuItem(value: 'close', child: Text('Close Pane')),
        ],
      ],
    );

    if (value == null) return;
    notifier.setFocusedPane(widget.leaf.id);

    switch (value) {
      case 'copy':
        final lastBlock = widget.leaf.session.blocks.lastOrNull;
        if (lastBlock != null && lastBlock.hasOutput) {
          await Clipboard.setData(ClipboardData(text: lastBlock.output));
        }
      case 'paste':
        final text = clipboardData?.text;
        if (text != null && text.isNotEmpty) {
          widget.leaf.session.writeInput(text);
        }
      case 'split_right':
        notifier.splitPane(Axis.horizontal);
      case 'split_down':
        notifier.splitPane(Axis.vertical);
      case 'close':
        notifier.closePane();
    }
  }
}

/// Visual overlay showing where a dragged pane will land.
class _DropZoneOverlay extends StatelessWidget {
  final DropPosition activeZone;
  final BolonTheme theme;

  const _DropZoneOverlay({
    required this.activeZone,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        Rect rect;
        switch (activeZone) {
          case DropPosition.left:
            rect = Rect.fromLTWH(0, 0, w / 2, h);
          case DropPosition.right:
            rect = Rect.fromLTWH(w / 2, 0, w / 2, h);
          case DropPosition.top:
            rect = Rect.fromLTWH(0, 0, w, h / 2);
          case DropPosition.bottom:
            rect = Rect.fromLTWH(0, h / 2, w, h / 2);
        }

        return Stack(
          children: [
            Positioned(
              left: rect.left,
              top: rect.top,
              width: rect.width,
              height: rect.height,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.cursor.withAlpha(30),
                  border: Border.all(
                    color: theme.cursor.withAlpha(80),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        );
      },
    );
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
        final totalSize =
            isHorizontal ? constraints.maxWidth : constraints.maxHeight;
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
