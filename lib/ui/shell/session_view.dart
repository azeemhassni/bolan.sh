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
import '../prompt/prompt_input.dart';
import '../shared/font_size_toast.dart';
import 'pane_focus_registry.dart';

/// Renders a terminal session with Warp-style flowing layout.
///
/// Completed commands are rendered as styled block widgets. During command
/// execution, a live TerminalView shows output. The prompt area flows
/// right after the last content.
class SessionView extends ConsumerStatefulWidget {
  final TerminalSession session;
  final bool isFocusedPane;
  final String? paneId;
  final void Function(TapDownDetails)? onSecondaryTap;

  const SessionView({
    super.key,
    required this.session,
    this.isFocusedPane = true,
    this.paneId,
    this.onSecondaryTap,
  });

  @override
  ConsumerState<SessionView> createState() => _SessionViewState();
}

class _SessionViewState extends ConsumerState<SessionView> {
  final _terminalController = TerminalController();
  final _scrollController = ScrollController();
  late final FocusNode _terminalFocusNode;
  final _promptKey = GlobalKey<PromptInputState>();
  bool _showToast = false;
  bool _wasRunning = false;

  @override
  void initState() {
    super.initState();
    _terminalFocusNode = FocusNode(debugLabel: 'terminal-${widget.session.id}');
    widget.session.addListener(_onSessionChanged);
    // Register prompt for global focus forwarding after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.paneId != null && _promptKey.currentState != null) {
        PaneFocusRegistry.register(widget.paneId!, _promptKey.currentState!);
      }
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
    if (widget.paneId != null) PaneFocusRegistry.unregister(widget.paneId!);
    widget.session.removeListener(_onSessionChanged);
    _terminalController.dispose();
    _scrollController.dispose();
    _terminalFocusNode.dispose();
    super.dispose();
  }

  void _onSessionChanged() {
    if (!mounted) return;
    final isRunning = widget.session.isCommandRunning;

    setState(() {});

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Command just started → focus the terminal
      if (isRunning && !_wasRunning) {
        _terminalFocusNode.requestFocus();
        // Wait two frames for TerminalView to layout and autoResize,
        // then re-send dimensions so the program gets the correct size.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final t = widget.session.terminal;
          widget.session.resize(t.viewHeight, t.viewWidth);
        });
      }

      // Command just finished → focus the prompt input
      if (!isRunning && _wasRunning) {
        _promptKey.currentState?.requestFocus();
      }

      // Auto-scroll blocks list
      if (!isRunning && _scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }

      _wasRunning = isRunning;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);
    final fontSize = ref.watch(fontSizeProvider);
    final configLoader = ref.watch(configLoaderProvider);
    final lineHeight = configLoader?.config.editor.lineHeight ?? 1.0;
    final fontFamily = configLoader?.config.editor.fontFamily ?? 'Operator Mono';
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
          // Two modes: full-screen terminal when running, blocks when idle
          if (isRunning)
            TerminalView(
              widget.session.terminal,
              controller: _terminalController,
              theme: bolonToXtermTheme(theme),
              textStyle: TerminalStyle(
                fontSize: fontSize,
                height: 1.2,
                fontFamily: fontFamily,
                fontFamilyFallback: const [
                  'JetBrains Mono',
                  'Menlo',
                  'Monaco',
                  'Consolas',
                  'Liberation Mono',
                  'Courier New',
                ],
              ),
              padding: const EdgeInsets.all(8),
              focusNode: _terminalFocusNode,
              autofocus: true,
              cursorType: TerminalCursorType.block,
              backgroundOpacity: 0,
            )
          else
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => _promptKey.currentState?.requestFocus(),
              child: ListView(
              controller: _scrollController,
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.only(top: 8),
              children: [
                for (final block in blocks)
                  CommandBlockWidget(
                    block: block,
                    fontSize: fontSize,
                    lineHeight: lineHeight,
                    onSecondaryTap: widget.onSecondaryTap,
                  ),
                PromptArea(
                  session: widget.session,
                  fontSize: fontSize,
                  geminiModel: configLoader?.config.ai.geminiModel ?? 'gemini-2.5-flash',
                  promptInputKey: _promptKey,
                ),
              ],
            ),
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
