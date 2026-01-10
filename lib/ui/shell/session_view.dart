import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

import '../../core/terminal/session.dart';
import '../../core/theme/bolan_theme.dart';
import '../../core/theme/xterm_theme.dart';
import '../blocks/block_list.dart';

/// Renders a single terminal session.
///
/// Shows completed command blocks above the live terminal view.
/// The terminal view handles the currently running command and prompt.
class SessionView extends StatefulWidget {
  final TerminalSession session;

  const SessionView({super.key, required this.session});

  @override
  State<SessionView> createState() => _SessionViewState();
}

class _SessionViewState extends State<SessionView> {
  final _controller = TerminalController();
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'terminal-${widget.session.id}');
    widget.session.addListener(_onSessionChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void didUpdateWidget(SessionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      oldWidget.session.removeListener(_onSessionChanged);
      widget.session.addListener(_onSessionChanged);
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSessionChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSessionChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);
    final blocks = widget.session.blocks;
    final activeBlock = widget.session.activeBlock;

    return Column(
      children: [
        // Completed blocks — shown above the terminal
        if (blocks.isNotEmpty || activeBlock != null)
          Flexible(
            flex: 0,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: BlockList(
                blocks: blocks,
                activeBlock: activeBlock,
              ),
            ),
          ),

        // Thin separator between blocks and terminal
        if (blocks.isNotEmpty || activeBlock != null)
          Divider(
            height: 1,
            thickness: 1,
            color: theme.blockBorder,
          ),

        // Live terminal — always visible for the running command and prompt
        Expanded(
          child: TerminalView(
            widget.session.terminal,
            controller: _controller,
            theme: bolonToXtermTheme(theme),
            textStyle: const TerminalStyle(
              fontSize: 13,
              fontFamily: 'JetBrainsMono',
              fontFamilyFallback: [
                'Menlo',
                'Monaco',
                'Consolas',
                'Liberation Mono',
                'Courier New',
              ],
            ),
            padding: const EdgeInsets.all(8),
            focusNode: _focusNode,
            autofocus: true,
            cursorType: TerminalCursorType.block,
            backgroundOpacity: 0,
          ),
        ),
      ],
    );
  }
}
