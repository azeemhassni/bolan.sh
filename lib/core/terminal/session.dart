import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:uuid/uuid.dart';
import 'package:xterm/xterm.dart';

import 'command_block.dart';
import 'shell_integration.dart';

/// Wraps a PTY process and an xterm Terminal model into a single session.
///
/// Handles bidirectional data flow: terminal keyboard output goes to PTY input,
/// PTY output goes to terminal screen. Tracks command blocks via OSC 133
/// shell integration sequences.
class TerminalSession extends ChangeNotifier {
  final String id;
  final String title;
  final Terminal terminal;
  final Pty _pty;
  StreamSubscription<List<int>>? _outputSub;
  bool _disposed = false;

  static const _uuid = Uuid();

  // Block model state
  final List<CommandBlock> _blocks = [];
  CommandBlock? _activeBlock;
  String _pendingCommand = '';
  bool _commandRunning = false;

  // Accumulated output lines for the active block
  final List<String> _outputBuffer = [];

  TerminalSession._({
    required this.id,
    required this.title,
    required this.terminal,
    required Pty pty,
  }) : _pty = pty;

  /// Creates a new terminal session by spawning a shell process.
  factory TerminalSession.start({
    required String id,
    String? title,
    String? workingDirectory,
    int rows = 25,
    int columns = 80,
  }) {
    final shell = _defaultShell();

    final terminal = Terminal(
      maxLines: 10000,
    );

    final pty = Pty.start(
      shell,
      columns: columns,
      rows: rows,
      workingDirectory: workingDirectory,
      environment: {
        'TERM': 'xterm-256color',
        'TERM_PROGRAM': 'Bolan',
      },
    );

    final session = TerminalSession._(
      id: id,
      title: title ?? shell.split('/').last,
      terminal: terminal,
      pty: pty,
    );

    session._connect();
    session._injectShellIntegration();
    return session;
  }

  bool get isDisposed => _disposed;
  int get pid => _pty.pid;

  /// Completed command blocks.
  List<CommandBlock> get blocks => List.unmodifiable(_blocks);

  /// The currently running command block, or null.
  CommandBlock? get activeBlock => _activeBlock;

  /// Whether a command is currently executing.
  bool get isCommandRunning => _commandRunning;

  /// Writes user input to the PTY.
  void writeInput(String data) {
    if (_disposed) return;
    _pty.write(const Utf8Encoder().convert(data));
  }

  /// Resizes the PTY and terminal to the given dimensions.
  void resize(int rows, int cols) {
    if (_disposed) return;
    _pty.resize(rows, cols);
    terminal.resize(cols, rows);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _outputSub?.cancel();
    _pty.kill();
    super.dispose();
  }

  void _connect() {
    // PTY output → Terminal screen
    _outputSub = _pty.output.listen((data) {
      terminal.write(utf8.decode(data, allowMalformed: true));
    });

    // Terminal keyboard/mouse output → PTY input
    terminal.onOutput = (data) {
      _pty.write(const Utf8Encoder().convert(data));
    };

    // Terminal resize → PTY resize
    terminal.onResize = (width, height, pixelWidth, pixelHeight) {
      _pty.resize(height, width);
    };

    // OSC 133 shell integration events
    terminal.onPrivateOSC = (String code, List<String> args) {
      if (code == '133') {
        final event = parseOsc133(args);
        if (event != null) _handleShellEvent(event);
      }
    };
  }

  void _handleShellEvent(ShellEvent event) {
    switch (event) {
      case PromptStart():
        // Prompt is being displayed — if there was a running command,
        // finalize it (the D marker may have been missed).
        if (_commandRunning && _activeBlock != null) {
          _finalizeBlock(exitCode: null);
        }
        _commandRunning = false;

      case PromptEnd():
        // User has typed a command, about to execute.
        // Capture what's on the current terminal line as the command text.
        _pendingCommand = _readCurrentLine();

      case CommandStart():
        // Command execution begins.
        if (_pendingCommand.isNotEmpty) {
          _activeBlock = CommandBlock(
            id: _uuid.v4(),
            command: _pendingCommand,
            startedAt: DateTime.now(),
          );
          _commandRunning = true;
          _outputBuffer.clear();
          notifyListeners();
        }

      case CommandEnd(:final exitCode):
        _finalizeBlock(exitCode: exitCode);
    }
  }

  void _finalizeBlock({int? exitCode}) {
    if (_activeBlock == null) return;

    _blocks.add(_activeBlock!.copyWith(
      exitCode: exitCode ?? -1,
      finishedAt: DateTime.now(),
      isRunning: false,
    ));
    _activeBlock = null;
    _commandRunning = false;
    _pendingCommand = '';
    notifyListeners();
  }

  /// Reads the current line from the terminal buffer (the command the user typed).
  String _readCurrentLine() {
    final buffer = terminal.buffer;
    if (buffer.lines.length == 0) return '';

    final cursorRow = buffer.cursorY + buffer.scrollBack;
    if (cursorRow < 0 || cursorRow >= buffer.lines.length) return '';

    final line = buffer.lines[cursorRow];
    return line.getText().trim();
  }

  void _injectShellIntegration() {
    // Source the shell integration script that emits OSC 133 markers.
    // The scripts are bundled as assets and copied to a known location,
    // but for now we emit the hooks inline for immediate functionality.
    final shellName = _defaultShell().split('/').last;

    if (shellName == 'zsh') {
      // Inline zsh integration — emits OSC 133 A/B/C/D markers.
      const script = r'''
__bolan_prompt_start() { printf '\e]133;A\a'; }
__bolan_prompt_end()   { printf '\e]133;B\a'; }
__bolan_cmd_start()    { printf '\e]133;C\a'; }
__bolan_cmd_end()      { printf "\e]133;D;$?\a"; }
autoload -Uz add-zsh-hook
add-zsh-hook precmd  __bolan_prompt_start
add-zsh-hook precmd  __bolan_cmd_end
add-zsh-hook preexec __bolan_prompt_end
add-zsh-hook preexec __bolan_cmd_start
''';
      // Use a small delay so the shell has time to initialize first.
      Future<void>.delayed(const Duration(milliseconds: 300), () {
        if (!_disposed) writeInput(script);
      });
    } else if (shellName == 'bash') {
      const script = r'''
__bolan_prompt_start() { printf '\e]133;A\a'; }
__bolan_prompt_end()   { printf '\e]133;B\a'; }
__bolan_cmd_start()    { printf '\e]133;C\a'; }
__bolan_cmd_end()      { printf "\e]133;D;$?\a"; }
__bolan_preexec() { __bolan_prompt_end; __bolan_cmd_start; }
__bolan_precmd() { __bolan_cmd_end; __bolan_prompt_start; }
trap '__bolan_preexec' DEBUG
PROMPT_COMMAND="__bolan_precmd;${PROMPT_COMMAND}"
''';
      Future<void>.delayed(const Duration(milliseconds: 300), () {
        if (!_disposed) writeInput(script);
      });
    }
  }

  static String _defaultShell() {
    if (Platform.isMacOS || Platform.isLinux) {
      return Platform.environment['SHELL'] ?? '/bin/bash';
    }
    return '/bin/sh';
  }
}
