import 'package:flutter/material.dart';

import '../../core/terminal/command_block.dart';
import 'command_block_widget.dart';

/// Scrollable list of [CommandBlockWidget]s for completed and active commands.
class BlockList extends StatefulWidget {
  final List<CommandBlock> blocks;
  final CommandBlock? activeBlock;

  const BlockList({
    super.key,
    required this.blocks,
    this.activeBlock,
  });

  @override
  State<BlockList> createState() => _BlockListState();
}

class _BlockListState extends State<BlockList> {
  final ScrollController _scroll = ScrollController();

  @override
  void didUpdateWidget(BlockList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-scroll when new blocks arrive
    if (widget.blocks.length > oldWidget.blocks.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allBlocks = [
      ...widget.blocks,
      if (widget.activeBlock != null) widget.activeBlock!,
    ];

    if (allBlocks.isEmpty) return const SizedBox.shrink();

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: allBlocks.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: CommandBlockWidget(block: allBlocks[index]),
        );
      },
    );
  }

  void _scrollToBottom() {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    }
  }
}
