import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:uuid/uuid.dart';
import 'package:xterm/xterm.dart';

import '../completion/completion_engine.dart';
import 'command_block.dart';
import 'command_history.dart';
import 'shell_integration.dart';

/// Wraps a PTY process and an xterm Terminal model into a single session.
///
/// Handles bidirectional data flow: terminal keyboard output goes to PTY input,
/// PTY output goes to terminal screen. Tracks command blocks via OSC 133
/// shell integration sequences, capturing command output text.
class TerminalSession extends ChangeNotifier {
  final String id;
  final String title;
  final Terminal terminal;
  final Pty _pty;
  StreamSubscription<String>? _outputSub;
  bool _disposed = false;

  static const _uuid = Uuid();

  // Block model state
  final List<CommandBlock> _blocks = [];
  CommandBlock? _activeBlock;
  bool _commandRunning = false;
  bool _usedAltBuffer = false;

  // Status bar state
  String _cwd = '';
  String _gitBranch = '';
  bool _gitDirty = false;

  // Buffer for capturing command output between C and D markers
  final StringBuffer _outputCapture = StringBuffer();

  // Completion engine — lazily initialized
  CompletionEngine? _completionEngine;

  /// Shared command history — persisted across sessions.
  final CommandHistory history;

  TerminalSession._({
    required this.id,
    required this.title,
    required this.terminal,
    required Pty pty,
    required this.history,
  }) : _pty = pty;

  /// Creates a new terminal session by spawning a shell process.
  factory TerminalSession.start({
    required String id,
    required CommandHistory history,
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
      history: history,
    );

    session._connect();
    session._injectShellIntegration();
    return session;
  }

  bool get isDisposed => _disposed;
  int get pid => _pty.pid;

  /// Completed command blocks with captured output.
  List<CommandBlock> get blocks => List.unmodifiable(_blocks);

  /// The currently running command block, or null.
  CommandBlock? get activeBlock => _activeBlock;

  /// Whether a command is currently executing.
  bool get isCommandRunning => _commandRunning;

  /// Current working directory, updated via OSC 7 or shell integration.
  String get cwd => _cwd;

  /// Abbreviated CWD for display (replaces $HOME with ~).
  String get abbreviatedCwd {
    if (_cwd.isEmpty) return '';
    final home = Platform.environment['HOME'] ?? '';
    if (home.isNotEmpty && _cwd.startsWith(home)) {
      return '~${_cwd.substring(home.length)}';
    }
    return _cwd;
  }

  /// Current git branch name, or empty if not in a repo.
  String get gitBranch => _gitBranch;

  /// Whether the git working tree has uncommitted changes.
  bool get gitDirty => _gitDirty;

  /// Shell name (e.g. "zsh", "bash").
  String get shellName => title;

  /// Terminal column count.
  int get cols => terminal.viewWidth;

  /// Terminal row count.
  int get rows => terminal.viewHeight;

  /// Generates tab completions for the given input.
  Future<CompletionResult> requestCompletion(String input, int cursorPos) {
    _completionEngine ??= CompletionEngine(shell: _defaultShell());
    return _completionEngine!.complete(input, cursorPos, _cwd);
  }

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
    _completionEngine?.dispose();
    super.dispose();
  }

  void _connect() {
    // PTY output → Terminal screen + output capture.
    // Use a streaming UTF-8 decoder so multi-byte characters split
    // across chunks are handled correctly (no replacement characters).
    _outputSub = _pty.output
        .cast<List<int>>()
        .transform(utf8.decoder)
        .listen((decoded) {
      // Strip private CSI sequences that xterm.dart can't handle and
      // misinterprets. \e[>4m (XTMODKEYS) gets parsed as \e[4m (underline).
      // \e[<u (kitty keyboard restore) also causes issues.
      final cleaned = _stripUnsupportedCsi(decoded);
      terminal.write(cleaned);

      // Capture output while a command is running
      if (_commandRunning) {
        _outputCapture.write(decoded);
        // Detect alternate screen buffer usage (TUI programs)
        if (!_usedAltBuffer && terminal.isUsingAltBuffer) {
          _usedAltBuffer = true;
        }
      }
    });

    // Terminal keyboard/mouse output → PTY input
    terminal.onOutput = (data) {
      _pty.write(const Utf8Encoder().convert(data));
    };

    // Terminal resize → PTY resize
    terminal.onResize = (width, height, pixelWidth, pixelHeight) {
      _pty.resize(height, width);
    };

    // OSC sequences: shell integration (133) and CWD (7)
    terminal.onPrivateOSC = (String code, List<String> args) {
      if (code == '133') {
        final event = parseOsc133(args);
        if (event != null) _handleShellEvent(event);
      } else if (code == '7' && args.isNotEmpty) {
        _handleOsc7(args[0]);
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
        break;

      case CommandStart(:final command):
        if (command.isNotEmpty) {
          _outputCapture.clear();
          _usedAltBuffer = false;
          _activeBlock = CommandBlock(
            id: _uuid.v4(),
            command: command,
            startedAt: DateTime.now(),
          );
          _commandRunning = true;
          notifyListeners();
        }

      case CommandEnd(:final exitCode):
        _finalizeBlock(exitCode: exitCode);
    }
  }

  /// Clears all completed blocks. Used when the user runs `clear`.
  void clearBlocks() {
    _blocks.clear();
    notifyListeners();
  }

  void _finalizeBlock({int? exitCode}) {
    if (_activeBlock == null) return;

    final cmd = _activeBlock!.command.trim();

    // Handle `clear` — clear all blocks instead of adding a new one.
    if (cmd == 'clear' || cmd == 'reset') {
      _blocks.clear();
      _activeBlock = null;
      _commandRunning = false;
      _outputCapture.clear();
      notifyListeners();
      return;
    }

    // Skip output for programs that used the alternate screen buffer
    // (vim, nano, less, top, ssh, etc.) — their output is TUI rendering
    // and not useful as a block.
    if (_usedAltBuffer) {
      _activeBlock = null;
      _commandRunning = false;
      _outputCapture.clear();
      _usedAltBuffer = false;
      notifyListeners();
      return;
    }

    // Clean up the captured output — strip ANSI escape sequences,
    // expand tabs to spaces, trim trailing whitespace.
    final rawOutput = _outputCapture.toString();
    final cleanOutput = _expandTabs(_stripAnsiEscapes(rawOutput)).trim();

    _blocks.add(_activeBlock!.copyWith(
      output: cleanOutput,
      exitCode: exitCode ?? -1,
      finishedAt: DateTime.now(),
      isRunning: false,
    ));
    _activeBlock = null;
    _commandRunning = false;
    _outputCapture.clear();

    notifyListeners();
  }

  /// Strips private CSI sequences that xterm.dart misinterprets.
  ///
  /// `\e[>4m` (XTMODKEYS) gets parsed as `\e[4m` (SGR underline).
  /// `\e[<u` and `\e[>Xq` are kitty keyboard / XTMODKEYS sequences.
  /// These are all private CSI with `>` or `<` prefixes.
  static final _unsupportedCsiRe = RegExp(
    r'\x1B\[[<>][0-9;]*[a-zA-Z]',
  );

  static String _stripUnsupportedCsi(String input) {
    return input.replaceAll(_unsupportedCsiRe, '');
  }

  /// Strips ANSI escape sequences from terminal output for clean text display.
  static String _stripAnsiEscapes(String input) {
    return input.replaceAll(
      RegExp(r'\x1B\[[0-9;]*[a-zA-Z]|\x1B\][^\x07\x1B]*(?:\x07|\x1B\\)|\x1B[()][0-9A-Z]|\x1B[>=<]'),
      '',
    );
  }

  /// Expands tab characters to spaces using 8-character tab stops.
  static String _expandTabs(String input) {
    final sb = StringBuffer();
    var col = 0;
    for (final char in input.codeUnits) {
      if (char == 0x09) {
        // Tab — expand to next 8-character stop
        final spaces = 8 - (col % 8);
        sb.write(' ' * spaces);
        col += spaces;
      } else if (char == 0x0A) {
        // Newline — reset column
        sb.writeCharCode(char);
        col = 0;
      } else {
        sb.writeCharCode(char);
        col++;
      }
    }
    return sb.toString();
  }

  /// Handles OSC 7 — current working directory notification.
  /// Format: file://hostname/path
  void _handleOsc7(String uri) {
    try {
      final parsed = Uri.parse(uri);
      final newCwd = Uri.decodeComponent(parsed.path);
      if (newCwd.isNotEmpty && newCwd != _cwd) {
        _cwd = newCwd;
        _updateGitStatus();
        notifyListeners();
      }
    } on FormatException {
      // Ignore malformed URIs
    }
  }

  /// Queries git status for the current working directory.
  Future<void> _updateGitStatus() async {
    if (_cwd.isEmpty) return;

    try {
      final branchResult = await Process.run(
        'git',
        ['rev-parse', '--abbrev-ref', 'HEAD'],
        workingDirectory: _cwd,
      );
      if (branchResult.exitCode == 0) {
        _gitBranch = (branchResult.stdout as String).trim();

        final statusResult = await Process.run(
          'git',
          ['status', '--porcelain'],
          workingDirectory: _cwd,
        );
        _gitDirty = (statusResult.stdout as String).trim().isNotEmpty;
        notifyListeners();
      } else {
        _gitBranch = '';
        _gitDirty = false;
      }
    } on ProcessException {
      _gitBranch = '';
      _gitDirty = false;
    }
  }

  void _injectShellIntegration() {
    final shellName = _defaultShell().split('/').last;
    String? script;

    if (shellName == 'zsh') {
      // Hide the shell's native prompt — Bolan renders its own prompt area.
      // Set PS1 to empty so no prompt text appears in the terminal output.
      script = r"""
PS1=''
RPS1=''
PROMPT=''
__bolan_prompt_start() { printf '\e]133;A\a'; }
__bolan_prompt_end()   { printf '\e]133;B\a'; }
__bolan_cmd_start()    { printf '\e]133;C;%s\a' "$1"; }
__bolan_cmd_end()      { printf "\e]133;D;$?\a"; }
__bolan_osc7()         { printf '\e]7;file://%s%s\a' "$HOST" "$PWD"; }
autoload -Uz add-zsh-hook
add-zsh-hook precmd  __bolan_prompt_start
add-zsh-hook precmd  __bolan_cmd_end
add-zsh-hook precmd  __bolan_osc7
add-zsh-hook preexec __bolan_prompt_end
add-zsh-hook preexec __bolan_cmd_start
""";
    } else if (shellName == 'bash') {
      script = r"""
PS1=''
__bolan_prompt_start() { printf '\e]133;A\a'; }
__bolan_prompt_end()   { printf '\e]133;B\a'; }
__bolan_cmd_start()    { printf '\e]133;C;%s\a' "$BASH_COMMAND"; }
__bolan_cmd_end()      { printf "\e]133;D;$?\a"; }
__bolan_osc7()         { printf '\e]7;file://%s%s\a' "$HOSTNAME" "$PWD"; }
__bolan_preexec() { __bolan_prompt_end; __bolan_cmd_start; }
__bolan_precmd() { __bolan_cmd_end; __bolan_prompt_start; __bolan_osc7; }
trap '__bolan_preexec' DEBUG
PROMPT_COMMAND="__bolan_precmd;${PROMPT_COMMAND}"
""";
    }

    if (script == null) return;

    Future<void>.delayed(const Duration(milliseconds: 300), () async {
      if (_disposed) return;
      final tmpDir = Directory.systemTemp;
      final scriptFile = File('${tmpDir.path}/bolan_shell_integration_$id.sh');
      await scriptFile.writeAsString(script!);
      writeInput('source ${scriptFile.path} && clear\n');
    });
  }

  static String _defaultShell() {
    if (Platform.isMacOS || Platform.isLinux) {
      return Platform.environment['SHELL'] ?? '/bin/bash';
    }
    return '/bin/sh';
  }
}
