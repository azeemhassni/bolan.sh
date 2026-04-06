import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/ai/ai_provider_helper.dart';
import '../../core/ai/features/smart_history_search.dart';
import '../../core/theme/bolan_theme.dart';

/// Inline history search popup triggered by Ctrl+R.
///
/// Supports two modes:
/// - Regular: simple string matching (instant)
/// - Smart: AI-powered natural language search (when query looks like NL)
class HistorySearch extends StatefulWidget {
  final List<String> Function(String query) onSearch;
  final List<String> fullHistory;
  final ValueChanged<String> onSelect;
  final VoidCallback onDismiss;
  final double fontSize;
  final bool smartSearchEnabled;
  final String aiProvider;
  final String geminiModel;
  final String anthropicMode;

  const HistorySearch({
    super.key,
    required this.onSearch,
    required this.fullHistory,
    required this.onSelect,
    required this.onDismiss,
    this.fontSize = 13,
    this.smartSearchEnabled = true,
    this.aiProvider = 'gemini',
    this.geminiModel = 'gemma-3-27b-it',
    this.anthropicMode = 'claude-code',
  });

  @override
  State<HistorySearch> createState() => _HistorySearchState();
}

class _HistorySearchState extends State<HistorySearch> {
  final _controller = TextEditingController();
  late final FocusNode _focusNode;
  List<String> _results = [];
  int _selectedIndex = 0;
  bool _aiSearching = false;
  bool _isSmartMode = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(onKeyEvent: _handleKey);
    _results = widget.onSearch('');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
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

    final ctrl = HardwareKeyboard.instance.isControlPressed;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.escape:
        widget.onDismiss();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.enter:
        if (_results.isNotEmpty && _selectedIndex < _results.length) {
          widget.onSelect(_results[_selectedIndex]);
        }
        return KeyEventResult.handled;

      case LogicalKeyboardKey.arrowUp:
      case LogicalKeyboardKey.keyR when ctrl:
        if (_results.isNotEmpty) {
          setState(() {
            _selectedIndex = (_selectedIndex + 1) % _results.length;
          });
        }
        return KeyEventResult.handled;

      case LogicalKeyboardKey.arrowDown:
        if (_results.isNotEmpty) {
          setState(() {
            _selectedIndex =
                (_selectedIndex - 1 + _results.length) % _results.length;
          });
        }
        return KeyEventResult.handled;

      default:
        return KeyEventResult.ignored;
    }
  }

  void _onSearchChanged(String query) {
    final isNL = widget.smartSearchEnabled &&
        SmartHistorySearch.isNaturalLanguage(query);

    if (isNL && !_aiSearching) {
      // Debounce AI search
      setState(() => _isSmartMode = true);
      _doSmartSearch(query);
    } else if (!isNL) {
      setState(() {
        _isSmartMode = false;
        _results = widget.onSearch(query);
        _selectedIndex = 0;
      });
    }
  }

  Future<void> _doSmartSearch(String query) async {
    setState(() => _aiSearching = true);

    try {
      final provider = await AiProviderHelper.create(
        providerName: widget.aiProvider,
        geminiModel: widget.geminiModel,
        anthropicMode: widget.anthropicMode,
      );
      if (provider == null) return;

      final searcher = SmartHistorySearch(provider: provider);

      final results = await searcher.search(
        query: query,
        history: widget.fullHistory,
      );

      if (!mounted) return;
      setState(() {
        _results = results;
        _selectedIndex = 0;
      });
    } on Exception {
      // Fall back to regular search
      if (mounted) {
        setState(() {
          _results = widget.onSearch(query);
          _selectedIndex = 0;
        });
      }
    } finally {
      if (mounted) setState(() => _aiSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);
    final itemHeight = widget.fontSize * 1.8;
    final maxVisible = _results.length.clamp(0, 10);

    return Container(
      decoration: BoxDecoration(
        color: theme.promptBackground,
        border: Border(
          top: BorderSide(color: theme.blockBorder, width: 1),
          bottom: BorderSide(color: theme.blockBorder, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // Mode indicator
                if (_isSmartMode || _aiSearching)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _aiSearching
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: theme.ansiMagenta,
                            ),
                          )
                        : Icon(Icons.auto_awesome,
                            size: 14, color: theme.ansiMagenta),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      'history:',
                      style: TextStyle(
                        color: theme.statusShellFg,
                        fontFamily: theme.fontFamily,
                        fontSize: widget.fontSize,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      onChanged: _onSearchChanged,
                      style: TextStyle(
                        color: theme.foreground,
                        fontFamily: theme.fontFamily,
                        fontSize: widget.fontSize,
                        decoration: TextDecoration.none,
                      ),
                      cursorColor: theme.cursor,
                      cursorWidth: 2,
                      decoration: InputDecoration(
                        hintText: _isSmartMode
                            ? 'Ask in plain English...'
                            : 'search...',
                        hintStyle: TextStyle(
                          color: theme.dimForeground,
                          fontFamily: theme.fontFamily,
                          fontSize: widget.fontSize,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                    ),
                  ),
                ),
                Text(
                  _isSmartMode ? 'AI search' : 'esc to close',
                  style: TextStyle(
                    color: _isSmartMode
                        ? theme.ansiMagenta
                        : theme.dimForeground,
                    fontFamily: theme.fontFamily,
                    fontSize: widget.fontSize - 2,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),

          // Results list
          if (_results.isNotEmpty)
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxVisible * itemHeight),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _results.length,
                itemExtent: itemHeight,
                itemBuilder: (context, index) {
                  final isSelected = index == _selectedIndex;
                  return GestureDetector(
                    onTap: () => widget.onSelect(_results[index]),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      color: isSelected
                          ? theme.statusChipBg
                          : Colors.transparent,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _results[index],
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                          color: isSelected
                              ? theme.foreground
                              : theme.blockHeaderFg,
                          fontFamily: theme.fontFamily,
                          fontSize: widget.fontSize,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
