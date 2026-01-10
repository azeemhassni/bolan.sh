import 'package:flutter/material.dart';

import '../../core/terminal/command_block.dart';
import '../../core/theme/bolan_theme.dart';
import 'block_header.dart';

/// Renders a single completed (or running) command as a styled block card.
class CommandBlockWidget extends StatelessWidget {
  final CommandBlock block;

  const CommandBlockWidget({super.key, required this.block});

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.blockBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.blockBorder, width: 1),
      ),
      child: BlockHeader(block: block),
    );
  }
}
