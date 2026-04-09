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

/// Tab status indicator.
enum TabStatus { idle, running, error }

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
  // Counts in-place redraw sequences (cursor positioning + erase
  // line/screen) — TUI apps like Claude/Ink that DON'T use the alt
  // screen buffer still rewrite text in place using these primitives,
  // and the captured output is garbage. If this count crosses a
  // threshold, treat the command as a TUI and skip output capture.
  int _redrawSequenceCount = 0;
  String _oscTitle = ''; // title set by program via OSC 0

  /// Callback invoked when a command finishes. Used by SessionNotifier
  /// to send long-running command notifications.
  void Function(String command, Duration duration, int exitCode)?
      onCommandFinished;

  // Status bar state
  String _cwd = '';
  String _gitBranch = '';
  bool _gitDirty = false;
  int _gitFilesChanged = 0;
  int _gitInsertions = 0;
  int _gitDeletions = 0;

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
      workingDirectory:
          workingDirectory ?? Platform.environment['HOME'],
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

    // Initialize CWD so completions work before the first OSC 7
    session._cwd = workingDirectory ??
        Platform.environment['HOME'] ??
        Directory.current.path;

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

  /// Number of files with changes.
  int get gitFilesChanged => _gitFilesChanged;

  /// Lines added across all changed files.
  int get gitInsertions => _gitInsertions;

  /// Lines removed across all changed files.
  int get gitDeletions => _gitDeletions;

  /// Whether there are trackable git stats to show.
  bool get hasGitStats => _gitFilesChanged > 0;

  /// Shell name (e.g. "zsh", "bash").
  String get shellName => title;

  /// Dynamic tab title — prefers OSC 0 title from program, then
  /// current/last command name, then CWD basename.
  String get tabTitle {
    // Program-set title takes priority (e.g. Claude Code sets its own)
    if (_oscTitle.isNotEmpty && _commandRunning) {
      return _oscTitle;
    }
    if (_commandRunning && _activeBlock != null) {
      return _extractProgramName(_activeBlock!.command);
    }
    if (_blocks.isNotEmpty) {
      return _extractProgramName(_blocks.last.command);
    }
    if (_cwd.isNotEmpty) {
      final basename = _cwd.split('/').last;
      if (basename.isNotEmpty) return basename;
    }
    return title;
  }

  /// Full command text for tooltip.
  String get fullTabTitle {
    if (_oscTitle.isNotEmpty && _commandRunning) {
      return _oscTitle;
    }
    if (_commandRunning && _activeBlock != null) {
      return _activeBlock!.command.trim();
    }
    if (_blocks.isNotEmpty) {
      return _blocks.last.command.trim();
    }
    if (_cwd.isNotEmpty) return abbreviatedCwd;
    return title;
  }

  /// Tab status for icon display.
  TabStatus get tabStatus {
    if (_commandRunning) return TabStatus.running;
    if (_blocks.isNotEmpty &&
        _blocks.last.exitCode != null &&
        _blocks.last.exitCode! > 0) {
      return TabStatus.error;
    }
    return TabStatus.idle;
  }

  static String _extractProgramName(String command) {
    final trimmed = command.trim();
    if (trimmed.isEmpty) return 'zsh';
    const prefixes = {'sudo', 'env', 'nice', 'nohup', 'time'};
    final parts = trimmed.split(RegExp(r'\s+'));
    for (final part in parts) {
      if (prefixes.contains(part)) continue;
      return part.split('/').last;
    }
    return parts.first.split('/').last;
  }

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

      // xterm.dart 4.0.0 has a buffer-line resize race: when the
      // terminal column count changes (window/pane resize or zoom),
      // existing buffer lines occasionally aren't re-allocated in
      // time and `setCell` writes past the underlying Uint32List
      // capacity, throwing RangeError. A dropped chunk of output is
      // far better than a dead session — log the error and continue.
      try {
        terminal.write(cleaned);
      } on RangeError catch (e, st) {
        debugPrint('terminal.write RangeError (xterm.dart resize race): $e\n$st');
      } on Object catch (e, st) {
        debugPrint('terminal.write failed: $e\n$st');
      }

      // Capture output while a command is running
      if (_commandRunning) {
        _outputCapture.write(decoded);
        // Detect alternate screen buffer usage (vim, less, top, etc.)
        if (!_usedAltBuffer && terminal.isUsingAltBuffer) {
          _usedAltBuffer = true;
        }
        // Count in-place redraw sequences. Catches both classic
        // cursor-up redraws (spinners, progress bars) and Ink-style
        // TUIs (Claude Code, modern Node.js CLIs) that draw via
        // cursor positioning + erase-line on the main screen buffer.
        _redrawSequenceCount += _countRedrawSequences(decoded);
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

    // OSC 0 — program-set window/tab title
    terminal.onTitleChange = (newTitle) {
      _oscTitle = newTitle;
      notifyListeners();
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
          _redrawSequenceCount = 0;
          _activeBlock = CommandBlock(
            id: _uuid.v4(),
            command: command,
            startedAt: DateTime.now(),
            cwd: abbreviatedCwd,
            shellName: shellName,
            gitBranch: _gitBranch.isNotEmpty ? _gitBranch : null,
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

    // Skip output for TUI programs:
    // 1. Used the alternate screen buffer (vim, nano, less, top, etc.)
    // 2. Heavy in-place redraw activity (Claude Code, Ink CLIs,
    //    spinners, progress bars) — these rewrite previous content
    //    via cursor positioning + erase, producing garbage if we
    //    naively concatenate the byte stream.
    if (_usedAltBuffer || _redrawSequenceCount > 10) {
      _activeBlock = null;
      _commandRunning = false;
      _outputCapture.clear();
      _usedAltBuffer = false;
      _redrawSequenceCount = 0;
      notifyListeners();
      return;
    }

    // Clean up the captured output.
    // rawOutput preserves SGR color codes for colored rendering.
    // output is fully stripped for plain-text copy.
    final captured = _stripPartialLineMarker(_outputCapture.toString());
    final cleanOutput = _expandTabs(_stripAnsiEscapes(captured)).trim();
    final colorOutput = _expandTabs(_stripNonSgrEscapes(captured)).trim();

    _blocks.add(_activeBlock!.copyWith(
      output: cleanOutput,
      rawOutput: colorOutput,
      exitCode: exitCode ?? -1,
      finishedAt: DateTime.now(),
      isRunning: false,
    ));
    final finishedBlock = _blocks.last;
    _activeBlock = null;
    _commandRunning = false;
    _outputCapture.clear();

    // Notify about finished command for long-running notifications
    if (finishedBlock.finishedAt != null) {
      final duration =
          finishedBlock.finishedAt!.difference(finishedBlock.startedAt);
      onCommandFinished?.call(
        finishedBlock.command,
        duration,
        finishedBlock.exitCode ?? -1,
      );
    }

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

  /// Matches in-place redraw CSI sequences. Catches:
  ///   A B C D — cursor up / down / forward / back
  ///   H f     — cursor position (row;col)
  ///   G       — cursor horizontal absolute (column)
  ///   J       — erase in display
  ///   K       — erase in line
  ///
  /// SGR `m` (color) is intentionally excluded — it doesn't move
  /// the cursor and shouldn't trigger TUI detection.
  static final _redrawSequenceRe = RegExp(r'\x1B\[[\d;]*[ABCDHfGJK]');

  static int _countRedrawSequences(String input) {
    return _redrawSequenceRe.allMatches(input).length;
  }

  /// Strips ANSI escape sequences from terminal output for clean text display.
  /// Strips zsh's PROMPT_EOL_MARK — the inverse-video % (or #) followed by
  /// spaces and a carriage return that zsh prints when output doesn't end
  /// with a newline.
  static String _stripPartialLineMarker(String input) {
    // zsh wraps it with bold + inverse: \e[1m\e[7m%\e[27m\e[1m\e[0m + spaces + \r
    // Require inverse video (\e[7m) before the marker to avoid false matches.
    return input.replaceAll(
      RegExp(r'(?:\x1B\[[0-9;]*m)*\x1B\[7m[%#](?:\x1B\[[0-9;]*m)+ *\r'),
      '',
    );
  }

  static String _stripAnsiEscapes(String input) {
    return input.replaceAll(
      RegExp(r'\x1B\[[0-9;?]*[a-zA-Z]|\x1B\][^\x07\x1B]*(?:\x07|\x1B\\)|\x1B[()][0-9A-Z]|\x1B[>=<]'),
      '',
    );
  }

  /// Strips all escape sequences EXCEPT SGR color codes (\e[...m).
  /// Used to preserve colors for rich text rendering in blocks.
  static String _stripNonSgrEscapes(String input) {
    return input.replaceAll(
      RegExp(
        r'\x1B\[[0-9;?]*[a-ln-zA-Z]'  // CSI except 'm'
        r'|\x1B\][^\x07\x1B]*(?:\x07|\x1B\\)'  // OSC
        r'|\x1B[()*/+][0-9A-Z%]?'  // Charset
        r'|\x1B[@-Z\\^_]',  // Single-char Fe
      ),
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

        // Get change stats
        final shortstat = await Process.run(
          'git',
          ['diff', '--shortstat'],
          workingDirectory: _cwd,
        );
        _parseShortstat((shortstat.stdout as String).trim());

        notifyListeners();
      } else {
        _gitBranch = '';
        _gitDirty = false;
        _gitFilesChanged = 0;
        _gitInsertions = 0;
        _gitDeletions = 0;
      }
    } on ProcessException {
      _gitBranch = '';
      _gitDirty = false;
      _gitFilesChanged = 0;
      _gitInsertions = 0;
      _gitDeletions = 0;
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
__bolan_cmd_end()      { local ec=$?; printf "\e]133;D;$ec\a"; }
__bolan_osc7()         { printf '\e]7;file://%s%s\a' "$HOST" "$PWD"; }
autoload -Uz add-zsh-hook
add-zsh-hook precmd  __bolan_cmd_end
add-zsh-hook precmd  __bolan_prompt_start
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
__bolan_cmd_end()      { local ec=$?; printf "\e]133;D;$ec\a"; }
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

  /// Runs startup commands after the shell is ready.
  ///
  /// Must be called after [_injectShellIntegration] has had time to complete.
  /// Each command is written to the PTY with a newline appended.
  void runStartupCommands(List<String> commands) {
    if (commands.isEmpty) return;
    // Wait for shell integration to finish (300ms + source + clear)
    Future<void>.delayed(const Duration(milliseconds: 800), () {
      if (_disposed) return;
      for (final command in commands) {
        final trimmed = command.trim();
        if (trimmed.isNotEmpty) {
          writeInput('$trimmed\n');
        }
      }
    });
  }

  /// Parses `git diff --shortstat` output like:
  /// "3 files changed, 218 insertions(+), 19 deletions(-)"
  void _parseShortstat(String output) {
    _gitFilesChanged = 0;
    _gitInsertions = 0;
    _gitDeletions = 0;
    if (output.isEmpty) return;

    final filesMatch = RegExp(r'(\d+) files? changed').firstMatch(output);
    final insMatch = RegExp(r'(\d+) insertions?').firstMatch(output);
    final delMatch = RegExp(r'(\d+) deletions?').firstMatch(output);

    if (filesMatch != null) _gitFilesChanged = int.parse(filesMatch.group(1)!);
    if (insMatch != null) _gitInsertions = int.parse(insMatch.group(1)!);
    if (delMatch != null) _gitDeletions = int.parse(delMatch.group(1)!);
  }

  static String _defaultShell() {
    if (Platform.isMacOS || Platform.isLinux) {
      return Platform.environment['SHELL'] ?? '/bin/bash';
    }
    return '/bin/sh';
  }
}
