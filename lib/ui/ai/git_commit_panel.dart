import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/bolan_theme.dart';

/// Bottom sheet editor for reviewing/editing an AI-generated commit message.
///
/// Shows the message in an editable text field. User can:
/// - Edit the message
/// - Press Enter or click Commit to accept
/// - Press Escape or click Cancel to abort
class GitCommitPanel extends StatefulWidget {
  final String message;
  final ValueChanged<String> onCommit;
  final VoidCallback onCancel;

  const GitCommitPanel({
    super.key,
    required this.message,
    required this.onCommit,
    required this.onCancel,
  });

  @override
  State<GitCommitPanel> createState() => _GitCommitPanelState();
}

class _GitCommitPanelState extends State<GitCommitPanel> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.message);
    _focusNode = FocusNode(onKeyEvent: _handleKey);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      // Select all for easy replacement
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final meta = HardwareKeyboard.instance.isMetaPressed;

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onCancel();
      return KeyEventResult.handled;
    }

    // Cmd+Enter to commit
    if (event.logicalKey == LogicalKeyboardKey.enter && meta) {
      widget.onCommit(_controller.text.trim());
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.promptBackground,
        border: Border(
          top: BorderSide(color: theme.blockBorder, width: 1),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 16, color: theme.ansiMagenta),
              const SizedBox(width: 8),
              Text(
                'AI Commit Message',
                style: TextStyle(
                  color: theme.foreground,
                  fontFamily: 'Operator Mono',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
              const Spacer(),
              Text(
                'Cmd+Enter to commit · Esc to cancel',
                style: TextStyle(
                  color: theme.dimForeground,
                  fontFamily: 'Operator Mono',
                  fontSize: 11,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Editable message
          Material(
            color: theme.statusChipBg,
            borderRadius: BorderRadius.circular(6),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              maxLines: null,
              minLines: 3,
              style: TextStyle(
                color: theme.foreground,
                fontFamily: 'Operator Mono',
                fontSize: 13,
                height: 1.5,
                decoration: TextDecoration.none,
              ),
              cursorColor: theme.cursor,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: theme.blockBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: theme.blockBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: theme.cursor),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _Button(
                label: 'Cancel',
                color: theme.dimForeground,
                onTap: widget.onCancel,
              ),
              const SizedBox(width: 8),
              _Button(
                label: 'Commit',
                color: theme.exitSuccessFg,
                onTap: () => widget.onCommit(_controller.text.trim()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Button extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _Button({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withAlpha(60), width: 1),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontFamily: 'Operator Mono',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}
