import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/ai/ai_provider_helper.dart';
import '../../core/ai/features/command_suggest.dart';
import '../../core/ai/features/git_commit.dart';
import '../../core/ai/features/nlp_to_command.dart';
import '../../core/ai/history_sanitizer.dart';
import '../../core/completion/completion_engine.dart';
import '../../core/platform_shortcuts.dart';
import '../../core/terminal/session.dart';
import '../../core/theme/bolan_theme.dart';
import '../ai/git_commit_panel.dart';
import 'completion_popup.dart';
import 'history_search.dart';

/// Prompt input with ghost text from history and tab completion.
///
/// - Arrow Up/Down navigates command history.
/// - Ctrl+R opens inline history search.
/// - While typing, shows closest history match as ghost text.
/// - Tab triggers file/command completion with ghost text cycling.
/// - Right Arrow at end of input accepts ghost text.
class PromptInput extends StatefulWidget {
  final TerminalSession session;
  final double fontSize;
  final bool aiEnabled;
  final String aiProvider;
  final String geminiModel;
  final String anthropicMode;
  final bool commandSuggestions;
  final bool smartHistorySearch;
  final bool shareHistory;

  const PromptInput({
    super.key,
    required this.session,
    this.fontSize = 13.0,
    this.aiEnabled = false,
    this.aiProvider = 'gemini',
    this.geminiModel = 'gemma-3-27b-it',
    this.anthropicMode = 'claude-code',
    this.commandSuggestions = true,
    this.smartHistorySearch = true,
    this.shareHistory = false,
  });

  @override
  State<PromptInput> createState() => PromptInputState();
}

class PromptInputState extends State<PromptInput> {
  // Custom controller renders the ghost text as an extra TextSpan
  // appended to the editor's own RichText. This puts the ghost in
  // the SAME render object as the input — there's no overlay, so
  // there's nothing to misalign. See [_GhostTextController].
  final _controller = _GhostTextController();
  late final FocusNode _focusNode;
  int _historyIndex = -1;
  String _savedInput = '';

  // Completion state
  List<CompletionItem> _completions = [];
  int _completionIndex = 0;
  CompletionResult? _activeResult;
  bool _completionLoading = false;
  final _completionLayerLink = LayerLink();
  OverlayEntry? _completionOverlay;

  // History search state
  bool _showHistorySearch = false;

  // AI state
  bool _aiLoading = false;
  bool _isAiMode = false;
  String? _aiSuggestion; // ghost text suggestion from AI

  /// Notifier for parent widgets to react to AI mode changes.
  final aiModeNotifier = ValueNotifier<bool>(false);

  // Git commit panel state
  bool _showCommitPanel = false;
  String _commitMessage = '';

  /// Authoritative line metric shared by the prompt TextField AND
  /// the ghost text RichText overlaid on top of it. Without
  /// `forceStrutHeight: true`, TextField (with isDense) and RichText
  /// compute slightly different baselines and the ghost text drifts
  /// vertically by a pixel or two.
  StrutStyle _promptStrutStyle(BolonTheme theme) => StrutStyle(
        fontFamily: theme.fontFamily,
        fontSize: widget.fontSize,
        height: 1.4,
        forceStrutHeight: true,
      );

  /// Ghost text: AI loading indicator, completions, or history match.
  String get _ghostText {
    if (_aiLoading) return 'Thinking...';

    // Tab completion ghost takes priority
    if (_completions.isNotEmpty && _activeResult != null) {
      final current = _completions[_completionIndex].text;
      final prefix = _activeResult!.prefix;
      if (current.length > prefix.length) {
        return current.substring(prefix.length);
      }
    }
    // History ghost — show matching command from history
    final text = _controller.text;
    if (text.isNotEmpty && _historyIndex == -1) {
      final match = widget.session.history.findMatch(text);
      if (match != null) {
        return match.substring(text.length);
      }
    }
    // AI suggestion ghost — when input is empty
    if (text.isEmpty && _aiSuggestion != null) {
      return _aiSuggestion!;
    }
    return '';
  }

  int _lastBlockCount = 0;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(onKeyEvent: _handleKeyEvent);
    _controller.addListener(_onTextChanged);
    widget.session.addListener(_onSessionChanged);
    _lastBlockCount = widget.session.blocks.length;
  }

  void requestFocus() => _focusNode.requestFocus();

  void selectAll() {
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  bool get isHistorySearchOpen => _showHistorySearch;
  bool get isAiMode => _isAiMode || _aiLoading;

  @override
  void dispose() {
    _removeCompletionOverlay();
    widget.session.removeListener(_onSessionChanged);
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    aiModeNotifier.dispose();
    super.dispose();
  }

  void _updateCompletionOverlay() {
    if (_completions.length > 1) {
      if (_completionOverlay != null) {
        _completionOverlay!.markNeedsBuild();
      } else {
        _completionOverlay = OverlayEntry(
          builder: (_) => _buildCompletionOverlay(),
        );
        Overlay.of(context).insert(_completionOverlay!);
      }
    } else {
      _removeCompletionOverlay();
    }
  }

  void _removeCompletionOverlay() {
    _completionOverlay?.remove();
    _completionOverlay = null;
  }

  Widget _buildCompletionOverlay() {
    final theme = BolonTheme.of(context);
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return const SizedBox.shrink();

    final position = box.localToGlobal(Offset.zero);
    final screenHeight = MediaQuery.of(context).size.height;
    final spaceBelow = screenHeight - position.dy - box.size.height;
    final itemHeight = widget.fontSize * 2.2;
    final popupHeight = _completions.length.clamp(1, 8) * itemHeight + 8;

    // Show below if there's room, otherwise above
    final showBelow = spaceBelow >= popupHeight;

    // Calculate cursor x position
    final cursorOffset = _controller.selection.baseOffset;
    final textBeforeCursor = _controller.text.substring(0, cursorOffset);
    final tp = TextPainter(
      text: TextSpan(
        text: textBeforeCursor,
        style: TextStyle(
          fontFamily: theme.fontFamily,
          fontSize: widget.fontSize,
          height: 1.4,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final cursorX = tp.width;

    return CompositedTransformFollower(
      link: _completionLayerLink,
      showWhenUnlinked: false,
      targetAnchor: showBelow ? Alignment.bottomLeft : Alignment.topLeft,
      followerAnchor: showBelow ? Alignment.topLeft : Alignment.bottomLeft,
      offset: Offset(cursorX, showBelow ? 4 : -4),
      child: Align(
        alignment: showBelow ? Alignment.topLeft : Alignment.bottomLeft,
        child: BolonThemeProvider(
          theme: theme,
          child: Material(
            color: Colors.transparent,
            child: CompletionPopup(
              items: _completions,
              selectedIndex: _completionIndex,
              prefix: _activeResult?.prefix ?? '',
              fontSize: widget.fontSize,
              onSelect: _acceptCompletion,
            ),
          ),
        ),
      ),
    );
  }

  void _onSessionChanged() {
    // Detect when a new block is added (command completed)
    final blocks = widget.session.blocks;
    if (blocks.length > _lastBlockCount && widget.commandSuggestions) {
      _lastBlockCount = blocks.length;
      final lastBlock = blocks.last;
      _requestSuggestion(lastBlock.command, lastBlock.output,
          lastBlock.exitCode ?? 0);
    }
    _lastBlockCount = blocks.length;
  }

  /// Last text value seen by [_onTextChanged]. Used to filter out
  /// notifications fired by [_GhostTextController.updateGhost],
  /// which mutate the controller's ghost state but NOT its `text`
  /// value. Without this filter, every ghost update would clobber
  /// active completions.
  String _lastObservedText = '';

  void _onTextChanged() {
    if (_controller.text == _lastObservedText) {
      // Ghost-only notification — nothing to do here.
      return;
    }
    _lastObservedText = _controller.text;

    final aiMode = widget.aiEnabled &&
        _controller.text.startsWith('#') &&
        _controller.text.length > 1;

    // Dismiss tab completions when typing
    if (_completions.isNotEmpty) {
      setState(() {
        _completions = [];
        _activeResult = null;
        _completionIndex = 0;
        _isAiMode = aiMode;
      });
      _removeCompletionOverlay();
    } else {
      setState(() {
        _isAiMode = aiMode;
        // Clear AI suggestion when user starts typing
        if (_controller.text.isNotEmpty) _aiSuggestion = null;
      });
    }
    aiModeNotifier.value = _isAiMode || _aiLoading;
  }

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);
    final ghost = _ghostText;

    // Push the current ghost into the custom controller so its
    // `buildTextSpan` renders it as an inline suffix. The controller
    // defers its notifyListeners() to a post-frame callback so this
    // call is safe inside build.
    _controller.updateGhost(
      ghost,
      TextStyle(
        color: theme.dimForeground,
        fontFamily: theme.fontFamily,
        fontSize: widget.fontSize,
        height: 1.4,
        decoration: TextDecoration.none,
      ),
    );

    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Git commit panel
          if (_showCommitPanel)
            GitCommitPanel(
              message: _commitMessage,
              onCommit: _doCommit,
              onCancel: _cancelCommit,
            ),

          // History search popup
          if (_showHistorySearch)
            HistorySearch(
              fontSize: widget.fontSize,
              onSearch: widget.session.history.search,
              fullHistory: widget.session.history.entries,
              onSelect: _acceptHistorySearch,
              onDismiss: _dismissHistorySearch,
              smartSearchEnabled: widget.smartHistorySearch,
              aiProvider: widget.aiProvider,
              geminiModel: widget.geminiModel,
              anthropicMode: widget.anthropicMode,
            ),

          // Input + ghost text + completion popup.
          //
          // The ghost text is rendered INSIDE the TextField via a
          // custom controller (`_GhostTextController`) that overrides
          // `buildTextSpan` to append a dim TextSpan after the real
          // text. One render path = one baseline = perfect alignment
          // at every font size, with no overlay/strut acrobatics.
          // The current ghost is pushed into the controller at the
          // top of build (see above this Column); the controller
          // defers its notification to a post-frame callback so
          // we never call setState during build.
          CompositedTransformTarget(
            link: _completionLayerLink,
            child: Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, top: 4, bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      autofocus: true,
                      maxLines: null,
                      minLines: 1,
                      contextMenuBuilder: (_, __) => const SizedBox.shrink(),
                      style: TextStyle(
                        color: theme.foreground,
                        fontFamily: theme.fontFamily,
                        fontSize: widget.fontSize,
                        height: 1.4,
                        decoration: TextDecoration.none,
                      ),
                      strutStyle: _promptStrutStyle(theme),
                      cursorColor:
                          _isAiMode ? theme.ansiMagenta : theme.cursor,
                      cursorWidth: 2,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                    ),
                  ),

                  // AI mode indicator icon
                  if (_isAiMode || _aiLoading)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _aiLoading
                          ? SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: theme.ansiMagenta,
                              ),
                            )
                          : Icon(
                              Icons.auto_awesome,
                              size: 16,
                              color: theme.ansiMagenta,
                            ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final ctrl = HardwareKeyboard.instance.isControlPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final meta = isPrimaryModifierPressed;

    // Tab completion popup navigation
    if (_completions.length > 1) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.tab:
        case LogicalKeyboardKey.arrowDown:
          setState(() {
            _completionIndex =
                (_completionIndex + 1) % _completions.length;
          });
          _updateCompletionOverlay();
          return KeyEventResult.handled;

        case LogicalKeyboardKey.arrowUp:
          setState(() {
            _completionIndex =
                (_completionIndex - 1 + _completions.length) %
                    _completions.length;
          });
          _updateCompletionOverlay();
          return KeyEventResult.handled;

        case LogicalKeyboardKey.enter:
          _acceptCompletion(_completionIndex);
          return KeyEventResult.handled;

        case LogicalKeyboardKey.escape:
          setState(() {
            _completions = [];
            _activeResult = null;
          });
          _removeCompletionOverlay();
          return KeyEventResult.handled;

        default:
          break;
      }
    }

    switch (event.logicalKey) {
      // Tab — file/command completion
      case LogicalKeyboardKey.tab:
        if (_completions.isEmpty) {
          _requestCompletion();
        } else if (_completions.length == 1) {
          _acceptCompletion(0);
        }
        return KeyEventResult.handled;

      // Right Arrow at end — accept ghost text
      case LogicalKeyboardKey.arrowRight
          when _ghostText.isNotEmpty &&
              _controller.selection.baseOffset == _controller.text.length:
        _acceptGhostText();
        return KeyEventResult.handled;

      // Ctrl+R — open history search
      case LogicalKeyboardKey.keyR when ctrl:
        setState(() => _showHistorySearch = true);
        return KeyEventResult.handled;

      // Escape — dismiss completions/ghost
      case LogicalKeyboardKey.escape:
        if (_completions.isNotEmpty) {
          setState(() {
            _completions = [];
            _activeResult = null;
          });
          _removeCompletionOverlay();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;

      // Enter — submit
      case LogicalKeyboardKey.enter when !shift:
        _onSubmit(_controller.text);
        return KeyEventResult.handled;

      // Shift+Enter — newline
      case LogicalKeyboardKey.enter when shift:
        final pos = _controller.selection.baseOffset;
        final text = _controller.text;
        _withoutListener(() {
          _controller.text =
              '${text.substring(0, pos)}\n${text.substring(pos)}';
          _controller.selection = TextSelection.collapsed(offset: pos + 1);
        });
        return KeyEventResult.handled;

      // Arrow Up — history back
      case LogicalKeyboardKey.arrowUp when !ctrl:
        _navigateHistory(back: true);
        return KeyEventResult.handled;

      // Arrow Down — history forward
      case LogicalKeyboardKey.arrowDown when !ctrl:
        _navigateHistory(back: false);
        return KeyEventResult.handled;

      case LogicalKeyboardKey.keyA when ctrl:
        _controller.selection = const TextSelection.collapsed(offset: 0);
        return KeyEventResult.handled;

      case LogicalKeyboardKey.keyE when ctrl:
        _controller.selection = TextSelection.collapsed(
          offset: _controller.text.length,
        );
        return KeyEventResult.handled;

      case LogicalKeyboardKey.keyU when ctrl:
        final pos = _controller.selection.baseOffset;
        _withoutListener(() {
          _controller.text = _controller.text.substring(pos);
          _controller.selection = const TextSelection.collapsed(offset: 0);
        });
        return KeyEventResult.handled;

      case LogicalKeyboardKey.keyK when ctrl:
        final pos = _controller.selection.baseOffset;
        _withoutListener(() {
          _controller.text = _controller.text.substring(0, pos);
          _controller.selection = TextSelection.collapsed(offset: pos);
        });
        return KeyEventResult.handled;

      case LogicalKeyboardKey.keyW when ctrl:
        _deleteWordBefore();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.keyC when ctrl:
        widget.session.writeInput('\x03');
        _controller.clear();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.keyL when ctrl:
        widget.session.clearBlocks();
        widget.session.writeInput('\x0c');
        return KeyEventResult.handled;

      // Cmd+K — clear everything (blocks + scrollback)
      case LogicalKeyboardKey.keyK when meta:
        widget.session.clearBlocks();
        widget.session.terminal.buffer.clear();
        widget.session.writeInput('\x0c');
        return KeyEventResult.handled;

      default:
        return KeyEventResult.ignored;
    }
  }

  // --- History ---

  void _navigateHistory({required bool back}) {
    final history = widget.session.history;
    if (history.length == 0) return;

    if (back) {
      if (_historyIndex == -1) {
        _savedInput = _controller.text;
        _historyIndex = 0;
      } else if (_historyIndex < history.length - 1) {
        _historyIndex++;
      }
      _withoutListener(() {
        _controller.text = history.entryFromEnd(_historyIndex) ?? '';
        _controller.selection = TextSelection.collapsed(
          offset: _controller.text.length,
        );
      });
      setState(() {});
    } else {
      if (_historyIndex == -1) return;
      if (_historyIndex > 0) {
        _historyIndex--;
        _withoutListener(() {
          _controller.text = history.entryFromEnd(_historyIndex) ?? '';
          _controller.selection = TextSelection.collapsed(
            offset: _controller.text.length,
          );
        });
      } else {
        _historyIndex = -1;
        _withoutListener(() {
          _controller.text = _savedInput;
          _controller.selection = TextSelection.collapsed(
            offset: _controller.text.length,
          );
        });
      }
      setState(() {});
    }
  }

  void _acceptHistorySearch(String command) {
    _withoutListener(() {
      _controller.text = command;
      _controller.selection = TextSelection.collapsed(
        offset: command.length,
      );
    });
    setState(() => _showHistorySearch = false);
    _focusNode.requestFocus();
  }

  void _dismissHistorySearch() {
    setState(() => _showHistorySearch = false);
    _focusNode.requestFocus();
  }

  // --- Ghost text ---

  void _acceptGhostText() {
    final ghost = _ghostText;
    if (ghost.isEmpty) return;

    // If from tab completion, accept that
    if (_completions.isNotEmpty && _activeResult != null) {
      _acceptCompletion(_completionIndex);
      return;
    }

    // Accept history or AI suggestion ghost
    final text = _controller.text;
    _withoutListener(() {
      _controller.text = '$text$ghost';
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    });
    _aiSuggestion = null;
    setState(() {});
  }

  // --- Tab completion ---

  Future<void> _requestCompletion() async {
    if (_completionLoading) return;
    _completionLoading = true;

    try {
      final result = await widget.session.requestCompletion(
        _controller.text,
        _controller.selection.baseOffset,
      );

      if (!mounted) return;

      if (result.isSingle) {
        _applyCompletion(result.items.first.text, result);
      } else if (result.items.isNotEmpty) {
        final lcp = longestCommonPrefix(result.texts);
        if (lcp.length > result.prefix.length) {
          _applyCompletion(lcp, result);
        }
        setState(() {
          _completions = result.items;
          _completionIndex = 0;
          _activeResult = result;
        });
        _updateCompletionOverlay();
      }
    } finally {
      _completionLoading = false;
    }
  }

  void _acceptCompletion(int index) {
    if (_activeResult == null || index >= _completions.length) return;
    _applyCompletion(_completions[index].text, _activeResult!);
    setState(() {
      _completions = [];
      _activeResult = null;
    });
    _removeCompletionOverlay();
  }

  void _applyCompletion(String completion, CompletionResult result) {
    final text = _controller.text;
    final before = text.substring(0, result.replaceStart);
    final after = text.substring(result.replaceEnd);
    final suffix = completion.endsWith('/') ? '' : ' ';
    final newText = '$before$completion$suffix$after';
    final newPos = result.replaceStart + completion.length + suffix.length;

    _withoutListener(() {
      _controller.text = newText;
      _controller.selection = TextSelection.collapsed(offset: newPos);
    });
    setState(() {
      _completions = [];
      _activeResult = null;
    });
    _removeCompletionOverlay();
  }

  // --- Submit ---

  void _onSubmit(String text) {
    final command = text.trim();

    // Git commit intercept: generate AI commit message (only when enabled)
    if (widget.aiEnabled && _isGitCommitWithoutMessage(command)) {
      _handleGitCommit();
      return;
    }

    // NLP-to-command: # prefix triggers AI (only when enabled)
    if (widget.aiEnabled && command.startsWith('#') && command.length > 1) {
      final query = command.substring(1).trim();
      if (query.isNotEmpty) {
        _handleNlpQuery(query);
        return;
      }
    }

    if (command.isEmpty) {
      widget.session.writeInput('\n');
    } else {
      widget.session.writeInput('$command\n');
      widget.session.history.add(command);
    }
    _controller.clear();
    _historyIndex = -1;
    _focusNode.requestFocus();
  }

  // --- NLP-to-command ---

  Future<void> _handleNlpQuery(String query) async {
    if (_aiLoading) return;

    _withoutListener(() => _controller.clear());
    setState(() => _aiLoading = true);
    aiModeNotifier.value = true;

    try {
      final provider = await AiProviderHelper.create(
        providerName: widget.aiProvider,
        geminiModel: widget.geminiModel,
        anthropicMode: widget.anthropicMode,
      );
      if (provider == null) {
        throw Exception('No AI provider available. Check Settings > AI.');
      }

      final nlp = NlpToCommand(provider: provider);

      final recentCommands = HistorySanitizer.sanitize(
        widget.session.blocks
            .map((b) => b.command.trim())
            .where((c) => c.isNotEmpty)
            .toList(),
      );

      final result = await nlp.convert(
        query: query,
        cwd: widget.session.cwd,
        shellName: widget.session.shellName,
        recentCommands: recentCommands,
      );

      if (!mounted) return;

      // Place the generated command in the input for user review
      _withoutListener(() {
        _controller.text = result;
        _controller.selection = TextSelection.collapsed(
          offset: result.length,
        );
      });
      setState(() {});
    } on Exception catch (e) {
      if (!mounted) return;
      _showAiError('AI error: $e');
    } finally {
      if (mounted) {
        setState(() => _aiLoading = false);
        aiModeNotifier.value = _isAiMode;
      }
    }
  }

  void _showAiError(String message) {
    _withoutListener(() {
      _controller.text = '# $message';
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    });
    setState(() {});
  }

  // --- AI command suggestion ---

  Future<void> _requestSuggestion(
    String lastCommand,
    String lastOutput,
    int lastExitCode,
  ) async {
    if (_aiLoading) return;

    try {
      final provider = await AiProviderHelper.create(
        providerName: widget.aiProvider,
        geminiModel: widget.geminiModel,
        anthropicMode: widget.anthropicMode,
      );
      if (provider == null) return;

      final suggestor = CommandSuggestor(provider: provider);

      // Build history list — only if user consented, always sanitized
      final rawHistory = widget.shareHistory
          ? widget.session.history.entries
              .reversed
              .take(20)
              .toList()
              .reversed
              .toList()
          : <String>[lastCommand];
      final history = HistorySanitizer.sanitize(rawHistory);

      final suggestion = await suggestor.suggest(
        lastCommand: lastCommand,
        lastOutput: lastOutput,
        lastExitCode: lastExitCode,
        cwd: widget.session.cwd,
        shellName: widget.session.shellName,
        recentHistory: history,
        gitBranch: widget.session.gitBranch.isNotEmpty
            ? widget.session.gitBranch
            : null,
        gitDirty: widget.session.gitDirty,
      );

      if (!mounted) return;
      if (suggestion != null && _controller.text.isEmpty) {
        setState(() => _aiSuggestion = suggestion);
      }
    } on Exception {
      // Silently fail — suggestions are best-effort
    }
  }

  // --- Git commit ---

  bool _isGitCommitWithoutMessage(String cmd) {
    final trimmed = cmd.trim();
    if (trimmed == 'git commit' || trimmed == 'git commit -m' ||
        trimmed == 'git commit --message') {
      return true;
    }
    if (!trimmed.startsWith('git commit')) return false;
    // Has -m with an actual value — don't intercept
    final mFlag = RegExp(r'-m\s+\S');
    final msgFlag = RegExp(r'--message\s+\S|--message=\S');
    if (mFlag.hasMatch(trimmed) || msgFlag.hasMatch(trimmed)) return false;
    // git commit with other flags but no message value
    return true;
  }

  Future<void> _handleGitCommit() async {
    if (_aiLoading) return;

    _withoutListener(() => _controller.clear());
    setState(() => _aiLoading = true);
    aiModeNotifier.value = true;

    try {
      final provider = await AiProviderHelper.create(
        providerName: widget.aiProvider,
        geminiModel: widget.geminiModel,
        anthropicMode: widget.anthropicMode,
      );
      if (provider == null) {
        _showAiError('No AI provider available. Check Settings > AI.');
        return;
      }

      final generator = GitCommitGenerator(provider: provider);
      final message = await generator.generate(widget.session.cwd);

      if (!mounted) return;

      if (message == null || message.isEmpty) {
        _showAiError('No staged changes found. Stage files with git add first.');
        return;
      }

      setState(() {
        _commitMessage = message;
        _showCommitPanel = true;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      _showAiError('AI error: $e');
    } finally {
      if (mounted) {
        setState(() => _aiLoading = false);
        aiModeNotifier.value = false;
      }
    }
  }

  void _doCommit(String message) {
    if (message.isEmpty) return;
    // Use Process.run to commit directly — avoids shell escaping issues
    // with newlines, quotes, and special characters.
    _runGitCommit(message);
  }

  Future<void> _runGitCommit(String message) async {
    try {
      final result = await Process.run(
        'git',
        ['commit', '-m', message],
        workingDirectory: widget.session.cwd,
      );
      if (!mounted) return;

      final stdout = (result.stdout as String).trim();
      final error = (result.stderr as String).trim();

      // Write result directly to the terminal — avoids shell escaping issues
      if (result.exitCode == 0) {
        widget.session.terminal.write('$stdout\r\n');
      } else {
        widget.session.terminal.write('Commit failed: $error\r\n');
      }
    } on Exception catch (e) {
      if (!mounted) return;
      widget.session.terminal.write('Commit error: $e\r\n');
    }

    await widget.session.history.add('git commit');
    setState(() {
      _showCommitPanel = false;
      _commitMessage = '';
    });
    _controller.clear();
    _focusNode.requestFocus();
  }

  void _cancelCommit() {
    setState(() {
      _showCommitPanel = false;
      _commitMessage = '';
    });
    _focusNode.requestFocus();
  }

  // --- Helpers ---

  void _deleteWordBefore() {
    final text = _controller.text;
    final pos = _controller.selection.baseOffset;
    if (pos <= 0) return;

    var i = pos - 1;
    while (i > 0 && text[i] == ' ') {
      i--;
    }
    while (i > 0 && text[i - 1] != ' ') {
      i--;
    }

    _withoutListener(() {
      _controller.text = text.substring(0, i) + text.substring(pos);
      _controller.selection = TextSelection.collapsed(offset: i);
    });
  }

  void _withoutListener(VoidCallback fn) {
    _controller.removeListener(_onTextChanged);
    fn();
    _controller.addListener(_onTextChanged);
  }
}

/// `TextEditingController` that renders an inline ghost text suffix
/// directly inside the editor's own RichText. The ghost is appended
/// in `buildTextSpan` AFTER the real text but is NOT part of the
/// controller's `text` value, so it doesn't affect the cursor
/// position, selection, or what the user submits.
///
/// This eliminates the entire alignment problem: real text and ghost
/// text are spans of the same RenderParagraph inside one EditableText
/// — they share a single baseline, single line metric, single layout.
class _GhostTextController extends TextEditingController {
  String _ghostText = '';
  TextStyle? _ghostStyle;

  /// Updates the ghost text and schedules a rebuild of the field.
  /// Cheap no-op if neither value changed.
  ///
  /// The notification is deferred to a post-frame callback because
  /// callers (like the prompt widget's build method) typically invoke
  /// `updateGhost` *during* a build phase, and `notifyListeners()`
  /// would otherwise trigger `setState()` in any widget listening to
  /// this controller — which is illegal mid-build.
  void updateGhost(String text, TextStyle style) {
    if (text == _ghostText && style == _ghostStyle) return;
    _ghostText = text;
    _ghostStyle = style;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    // Reuse the framework's composing-region handling for IME input.
    final base = super.buildTextSpan(
      context: context,
      style: style,
      withComposing: withComposing,
    );
    if (_ghostText.isEmpty || _ghostStyle == null) return base;
    return TextSpan(
      style: style,
      children: [
        base,
        TextSpan(text: _ghostText, style: _ghostStyle),
      ],
    );
  }
}
