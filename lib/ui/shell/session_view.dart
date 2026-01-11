import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';

import '../../core/terminal/session.dart';
import '../../core/theme/bolan_theme.dart';
import '../../core/theme/xterm_theme.dart';
import '../../providers/config_provider.dart';
import '../../providers/font_size_provider.dart';
import '../blocks/command_block_widget.dart';
import '../prompt/prompt_area.dart';
import '../shared/font_size_toast.dart';

/// Renders a terminal session with Warp-style flowing layout.
///
/// Completed commands are rendered as styled block widgets. During command
/// execution, a live TerminalView shows output. The prompt area flows
/// right after the last content.
class SessionView extends ConsumerStatefulWidget {
  final TerminalSession session;

  const SessionView({super.key, required this.session});

  @override
  ConsumerState<SessionView> createState() => _SessionViewState();
}

class _SessionViewState extends ConsumerState<SessionView> {
  final _terminalController = TerminalController();
  final _scrollController = ScrollController();
  late final FocusNode _terminalFocusNode;
  bool _showToast = false;

  @override
  void initState() {
    super.initState();
    _terminalFocusNode = FocusNode(debugLabel: 'terminal-${widget.session.id}');
    widget.session.addListener(_onSessionChanged);
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
    _terminalController.dispose();
    _scrollController.dispose();
    _terminalFocusNode.dispose();
    super.dispose();
  }

  void _onSessionChanged() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);
    final fontSize = ref.watch(fontSizeProvider);
    final configLoader = ref.watch(configLoaderProvider);
    final lineHeight = configLoader?.config.editor.lineHeight ?? 1.2;
    final blocks = widget.session.blocks;
    final isRunning = widget.session.isCommandRunning;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.equal, meta: true):
            _increaseFontSize,
        const SingleActivator(LogicalKeyboardKey.minus, meta: true):
            _decreaseFontSize,
        const SingleActivator(LogicalKeyboardKey.digit0, meta: true):
            _resetFontSize,
      },
      child: Stack(
        children: [
          ListView(
            controller: _scrollController,
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.only(top: 8),
            children: [
              // Completed command blocks
              for (final block in blocks)
                CommandBlockWidget(
                  block: block,
                  fontSize: fontSize,
                  lineHeight: lineHeight,
                ),

              // Live terminal output (only while a command is running)
              if (isRunning)
                SizedBox(
                  height: _liveTerminalHeight(fontSize, lineHeight),
                  child: TerminalView(
                    widget.session.terminal,
                    controller: _terminalController,
                    theme: bolonToXtermTheme(theme),
                    textStyle: TerminalStyle(
                      fontSize: fontSize,
                      height: lineHeight,
                      fontFamily: 'JetBrainsMono',
                      fontFamilyFallback: const [
                        'Menlo',
                        'Monaco',
                        'Consolas',
                        'Liberation Mono',
                        'Courier New',
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    focusNode: _terminalFocusNode,
                    cursorType: TerminalCursorType.block,
                    backgroundOpacity: 0,
                    readOnly: true,
                  ),
                ),

              // Prompt area — flows right after content
              PromptArea(
                session: widget.session,
                fontSize: fontSize,
              ),
            ],
          ),

          // Font size toast
          if (_showToast)
            Center(
              child: FontSizeToast(
                fontSize: fontSize,
                onDismissed: () {
                  if (mounted) setState(() => _showToast = false);
                },
              ),
            ),
        ],
      ),
    );
  }

  /// Fixed height for the live terminal view — uses the full terminal height
  /// to avoid layout jumps as output grows.
  double _liveTerminalHeight(double fontSize, double lineHeight) {
    final cellHeight = fontSize * lineHeight;
    return widget.session.terminal.viewHeight * cellHeight + 16;
  }

  void _increaseFontSize() {
    ref.read(fontSizeProvider.notifier).increase();
    setState(() => _showToast = true);
  }

  void _decreaseFontSize() {
    ref.read(fontSizeProvider.notifier).decrease();
    setState(() => _showToast = true);
  }

  void _resetFontSize() {
    ref.read(fontSizeProvider.notifier).reset();
    setState(() => _showToast = true);
  }
}
