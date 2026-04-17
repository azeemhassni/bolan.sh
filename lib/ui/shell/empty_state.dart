import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/platform_shortcuts.dart';
import '../../core/theme/bolan_theme.dart';
import '../../core/tips.dart';
import '../shared/bolan_button.dart';

class EmptyState extends StatefulWidget {
  final VoidCallback onNewSession;

  const EmptyState({super.key, required this.onNewSession});

  @override
  State<EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<EmptyState> {
  final _lines = <_BootLine>[];
  bool _bootDone = false;
  bool _buttonVisible = false;
  bool _cursorVisible = true;
  Timer? _cursorTimer;
  late final String _tip;

  static const _bootScript = [
    (null, 'bolan v0.4.2', null),
    (null, '', null),
    ('init', 'loading shell environment', 'done'),
    ('init', 'detecting ai providers', null),
    ('init', 'restoring workspace', 'default'),
    ('init', 'checking for updates', 'up to date'),
    (null, '', null),
    (null, 'ready.', null),
  ];

  @override
  void initState() {
    super.initState();
    _tip = randomTip();
    _cursorTimer = Timer.periodic(
      const Duration(milliseconds: 530),
      (_) {
        if (mounted) setState(() => _cursorVisible = !_cursorVisible);
      },
    );
    _runBoot();
  }

  Future<void> _runBoot() async {
    for (var i = 0; i < _bootScript.length; i++) {
      if (!mounted) return;
      final (prefix, text, status) = _bootScript[i];

      if (text.isEmpty) {
        setState(() => _lines.add(_BootLine(text: '', prefix: null)));
        await Future.delayed(const Duration(milliseconds: 60));
        continue;
      }

      final fullText = prefix != null ? '$prefix: $text' : text;

      // Add line and type it out
      setState(() => _lines.add(_BootLine(text: '', prefix: null, typing: true)));
      for (var c = 0; c <= fullText.length; c++) {
        if (!mounted) return;
        setState(() => _lines.last.text = fullText.substring(0, c));
        await Future.delayed(const Duration(milliseconds: 16));
      }

      // Show status
      setState(() {
        _lines.last
          ..status = status
          ..typing = false;
      });

      await Future.delayed(const Duration(milliseconds: 80));
    }

    if (!mounted) return;
    setState(() => _bootDone = true);
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) setState(() => _buttonVisible = true);
  }

  @override
  void dispose() {
    _cursorTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);
    final mod = Platform.isMacOS ? '⌘' : 'Ctrl';

    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.keyT &&
            isPrimaryModifierPressed) {
          widget.onNewSession();
          return KeyEventResult.handled;
        }
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.space)) {
          widget.onNewSession();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: SizedBox(
                  width: 500,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < _lines.length; i++)
                        _buildLine(theme, _lines[i],
                            isLast: i == _lines.length - 1),
                      if (_bootDone) ...[
                        const SizedBox(height: 8),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '> ',
                                style: TextStyle(color: theme.cursor),
                              ),
                              if (_cursorVisible)
                                TextSpan(
                                  text: '_',
                                  style: TextStyle(color: theme.cursor),
                                ),
                            ],
                          ),
                          style: TextStyle(
                            fontFamily: theme.fontFamily,
                            fontSize: 14,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            AnimatedOpacity(
              opacity: _buttonVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 500),
              child: Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BolanButton.primary(
                          label: 'New Session',
                          icon: Icons.terminal,
                          onTap: widget.onNewSession,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$mod+T',
                          style: TextStyle(
                            color: theme.dimForeground.withAlpha(80),
                            fontFamily: theme.fontFamily,
                            fontSize: 10,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 360,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Did you know?',
                            style: TextStyle(
                              color: theme.dimForeground.withAlpha(60),
                              fontFamily: theme.fontFamily,
                              fontSize: 10,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _tip,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: theme.dimForeground.withAlpha(120),
                              fontFamily: theme.fontFamily,
                              fontSize: 12,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLine(BolonTheme theme, _BootLine line, {bool isLast = false}) {
    if (line.text.isEmpty && !line.typing) return const SizedBox(height: 6);

    final isTitle = line.text.startsWith('bolan');
    final isReady = line.text == 'ready.';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: line.text),
                  if (line.typing && isLast && _cursorVisible)
                    TextSpan(
                      text: '_',
                      style: TextStyle(color: theme.cursor),
                    ),
                ],
              ),
              style: TextStyle(
                color: isTitle || isReady
                    ? theme.foreground
                    : theme.dimForeground,
                fontFamily: theme.fontFamily,
                fontSize: isTitle ? 15 : 13,
                fontWeight: isTitle || isReady
                    ? FontWeight.w600
                    : FontWeight.normal,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          if (line.status != null && !line.typing)
            Text(
              ' [${line.status}]',
              style: TextStyle(
                color: theme.ansiGreen,
                fontFamily: theme.fontFamily,
                fontSize: 13,
                decoration: TextDecoration.none,
              ),
            ),
        ],
      ),
    );
  }
}

class _BootLine {
  String text;
  String? prefix;
  String? status;
  bool typing;

  _BootLine({
    required this.text,
    this.prefix,
    this.status, // ignore: unused_element_parameter
    this.typing = false,
  });
}
