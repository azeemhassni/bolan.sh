import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:uuid/uuid.dart';
import 'package:xterm/xterm.dart';

import '../completion/completion_engine.dart';
import '../workspace/workspace_paths.dart';
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
  int _cursorYAtCommandStart = 0;
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

  // Live tool chips — populated by directory + tool detection.
  // nvm: detected when an `.nvmrc` file is found in cwd or an
  // ancestor and `node` is on PATH. Stores the active node version
  // string (e.g. "v20.11.0") and the requested version from .nvmrc.
  String _nodeVersion = '';
  String _nvmrcVersion = '';
  String _nvmrcDir = '';

  // kubectl: updated by `_refreshOnPrompt` (runs after every
  // command via the OSC 133 prompt-start hook). Global to the
  // machine, not directory-dependent.
  String _kubeContext = '';
  String _kubeNamespace = '';

  // python venv: detected by walking ancestors for `pyvenv.cfg`.
  // Stores the venv directory's basename and the python version
  // recorded inside pyvenv.cfg.
  String _pythonVenvName = '';
  String _pythonVenvVersion = '';
  String _pythonVenvPath = '';

  // Phase 2: shell-emitted env var chips. Updated by the OSC 7777
  // hook the shell integration emits on every prompt. Empty when
  // the shell integration hasn't run yet (first prompt).
  String _activeVirtualEnv = '';
  String _awsProfile = '';
  String _gcpProject = '';
  String _dockerContext = '';

  // terraform: detected by walking ancestors for `.terraform/environment`
  // (file-based, no shell hook needed).
  String _terraformWorkspace = '';

  // xterm.dart insert-mode workaround. xterm.dart 4.0.0 stores
  // insertMode when it sees CSI 4h/4l but its writeChar ignores it
  // — characters always overwrite instead of shifting right. We
  // track the mode ourselves and inject CSI @ (ICH) before each
  // printable character while insert mode is active, which correctly
  // shifts existing characters right. nano relies on this for every
  // keystroke.
  bool _termInsertMode = false;

  /// True between submitting a line at the Bolan prompt and the next
  /// PromptStart (133;A). Lets the UI show the live terminal while the
  /// shell is processing — including continuation prompts (zsh's
  /// `dquote>`, `cmdsubst>`, bash's `> `) for unfinished input that
  /// the shell can't execute yet.
  bool _awaitingShellResponse = false;
  bool get awaitingShellResponse => _awaitingShellResponse;

  // Buffer for capturing command output between C and D markers
  final StringBuffer _outputCapture = StringBuffer();

  // Live output stream for inline block rendering during command execution.
  final StreamController<String> _liveOutputController =
      StreamController<String>.broadcast();
  Stream<String> get liveOutput => _liveOutputController.stream;
  String get liveOutputSnapshot =>
      _stripForLiveDisplay(_outputCapture.toString());

  static final _oscRe =
      RegExp(r'\x1B\][^\x07\x1B]*(?:\x07|\x1B\\)');
  static final _csiNonSgrRe =
      RegExp(r'\x1B\[[0-9;]*[A-LN-Za-ln-z]');
  static final _charsetRe = RegExp(r'\x1B[()][0-9A-Za-z]');
  static final _feRe = RegExp(r'\x1B[<=>]');

  static String _stripForLiveDisplay(String s) {
    var result = s
        .replaceAll(_oscRe, '')
        .replaceAll(_csiNonSgrRe, '')
        .replaceAll(_charsetRe, '')
        .replaceAll(_feRe, '');
    // Collapse carriage returns the same way _finalizeBlock does:
    // keep only the text after the last \r on each line.
    result = _collapseCarriageReturns(
        _stripPartialLineMarker(result));
    return result;
  }

  // TUI mode: detected when the command uses alt-buffer or produces
  // excessive cursor repositioning (full-screen TUI apps).
  bool _isTuiMode = false;
  bool get isTuiMode => _isTuiMode;

  /// Set by the listener when an entire command lifecycle (C marker,
  /// output, D marker) arrives in a single PTY chunk. Consumed by the
  /// CommandStart handler to pre-populate _outputCapture so CommandEnd
  /// (which fires synchronously inside the same terminal.write) has
  /// data to read instead of an empty buffer.
  String? _pendingSingleChunkOutput;

  // Completion engine — lazily initialized
  CompletionEngine? _completionEngine;

  /// Shared command history — persisted across sessions.
  final CommandHistory history;

  final String _resolvedShell;

  TerminalSession._({
    required this.id,
    required this.title,
    required this.terminal,
    required Pty pty,
    required this.history,
    required String resolvedShell,
  })  : _pty = pty,
        _resolvedShell = resolvedShell;

  /// Creates a new terminal session by spawning a shell process.
  factory TerminalSession.start({
    required String id,
    required CommandHistory history,
    String? title,
    String? shell,
    String? workingDirectory,
    int rows = 25,
    int columns = 80,
  }) {
    var resolvedShell = (shell != null && shell.isNotEmpty)
        ? shell
        : _defaultShell();

    // Resolve bare names (e.g. "fish") to full paths via `which`.
    if (!resolvedShell.contains('/')) {
      try {
        final result = Process.runSync('which', [resolvedShell]);
        if (result.exitCode == 0) {
          resolvedShell = (result.stdout as String).trim();
        }
      } on ProcessException {
        // ignore
      }
    }

    // Validate the shell exists before spawning.
    if (!File(resolvedShell).existsSync()) {
      final fallback = _defaultShell();
      debugPrint('Shell not found: $resolvedShell — falling back to $fallback');
      resolvedShell = fallback;
    }

    final terminal = Terminal(
      maxLines: 10000,
    );

    // Expand ~ to the user's home directory.
    var resolvedDir = workingDirectory ?? Platform.environment['HOME'] ?? '/';
    final home = Platform.environment['HOME'] ?? '';
    if (resolvedDir.startsWith('~/')) {
      resolvedDir = '$home${resolvedDir.substring(1)}';
    } else if (resolvedDir == '~') {
      resolvedDir = home;
    }

    // Start the shell as a login shell so .zprofile / .bash_profile
    // runs and sets up PATH (including Homebrew, nvm, etc.).
    // Merge with the current environment so PATH, HOME, USER, etc.
    // propagate to the shell instead of being wiped.
    //
    // Layering (last write wins): host env -> workspace env -> our
    // TERM_*. Workspace overrides host (so AWS_PROFILE etc. are
    // workspace-scoped) but our TERM_* are sacrosanct.
    final ws = WorkspacePaths.activeWorkspace;
    final wsGitEnv = <String, String>{};
    // Use GIT_CONFIG_COUNT/KEY/VALUE so workspace git identity is
    // visible to `git config` queries, not just commits.
    var gitConfigIndex = 0;
    if (ws?.gitName != null && ws!.gitName!.isNotEmpty) {
      wsGitEnv['GIT_CONFIG_KEY_$gitConfigIndex'] = 'user.name';
      wsGitEnv['GIT_CONFIG_VALUE_$gitConfigIndex'] = ws.gitName!;
      gitConfigIndex++;
    }
    if (ws?.gitEmail != null && ws!.gitEmail!.isNotEmpty) {
      wsGitEnv['GIT_CONFIG_KEY_$gitConfigIndex'] = 'user.email';
      wsGitEnv['GIT_CONFIG_VALUE_$gitConfigIndex'] = ws.gitEmail!;
      gitConfigIndex++;
    }
    if (gitConfigIndex > 0) {
      wsGitEnv['GIT_CONFIG_COUNT'] = '$gitConfigIndex';
    }
    final pty = Pty.start(
      resolvedShell,
      arguments: ['-l'],
      columns: columns,
      rows: rows,
      workingDirectory: resolvedDir,
      environment: {
        ...Platform.environment,
        ...?ws?.envVars,
        ...?ws?.secrets,
        ...wsGitEnv,
        'TERM': 'xterm-256color',
        'TERM_PROGRAM': 'Bolan',
      },
    );

    final session = TerminalSession._(
      id: id,
      title: title ?? resolvedShell.split('/').last,
      terminal: terminal,
      pty: pty,
      history: history,
      resolvedShell: resolvedShell,
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

  /// Whether shell integration (OSC 133) is active.
  /// False for unsupported shells (fish, nushell, etc.) — the UI
  /// should show a raw terminal instead of blocks + prompt.
  bool get hasShellIntegration => _hasShellIntegration;
  bool _hasShellIntegration = false;

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

  // ── Live tool chip getters ───────────────────────────────────

  /// Active Node.js version (`v20.11.0`), or empty if Node isn't on
  /// PATH or this directory has no .nvmrc.
  String get nodeVersion => _nodeVersion;

  /// Version requested by the nearest `.nvmrc` file (`20.11.0`).
  String get nvmrcVersion => _nvmrcVersion;

  /// Whether the chip should be shown — i.e. an `.nvmrc` was found
  /// somewhere in the cwd ancestor chain.
  bool get hasNvmrc => _nvmrcVersion.isNotEmpty;

  /// Whether the active node version satisfies the `.nvmrc`
  /// requirement using nvm's prefix-matching rules:
  ///
  /// - `.nvmrc = 21`     matches any `21.*.*`  (e.g. `21.7.4`)
  /// - `.nvmrc = 21.5`   matches any `21.5.*`  (e.g. `21.5.0`)
  /// - `.nvmrc = 21.5.0` matches only `21.5.0`
  ///
  /// Non-numeric `.nvmrc` values (`lts/*`, `node`, `latest`, etc.)
  /// can't be resolved without invoking nvm itself, so we treat
  /// them as matching to avoid a false-positive mismatch warning.
  bool get nvmVersionMatches {
    if (_nvmrcVersion.isEmpty) return true;
    if (_nodeVersion.isEmpty) return true;
    final requested = _nvmrcVersion;
    // Special tags — don't try to resolve.
    if (!RegExp(r'^\d').hasMatch(requested)) return true;
    final active = _nodeVersion.startsWith('v')
        ? _nodeVersion.substring(1)
        : _nodeVersion;
    final r = requested.split('.');
    final a = active.split('.');
    if (r.length > a.length) return false;
    for (var i = 0; i < r.length; i++) {
      if (r[i] != a[i]) return false;
    }
    return true;
  }

  /// Current `kubectl` context, or empty if kubectl isn't installed.
  String get kubeContext => _kubeContext;

  /// Current `kubectl` namespace, or empty if not set.
  String get kubeNamespace => _kubeNamespace;

  /// Whether the kubectl chip should be shown.
  bool get hasKubeContext => _kubeContext.isNotEmpty;

  /// Basename of the Python venv directory found via ancestor walk.
  String get pythonVenvName => _pythonVenvName;

  /// Python version recorded in the venv's `pyvenv.cfg` (e.g. "3.12").
  String get pythonVenvVersion => _pythonVenvVersion;

  /// Absolute path to the venv directory (used to compose the
  /// activate command when the user clicks the chip).
  String get pythonVenvPath => _pythonVenvPath;

  /// Whether the python venv chip should be shown.
  bool get hasPythonVenv => _pythonVenvName.isNotEmpty;

  /// Absolute path to the venv currently activated in the shell
  /// (`$VIRTUAL_ENV` from the shell-integration hook). Empty if
  /// none is active.
  String get activeVirtualEnv => _activeVirtualEnv;

  /// `$AWS_PROFILE` from the shell, or empty if unset (in which
  /// case the AWS CLI uses "default").
  String get awsProfile => _awsProfile;
  bool get hasAwsProfile => _awsProfile.isNotEmpty;

  /// `$CLOUDSDK_CORE_PROJECT` or `$GCP_PROJECT` from the shell,
  /// whichever is set.
  String get gcpProject => _gcpProject;
  bool get hasGcpProject => _gcpProject.isNotEmpty;

  /// `$DOCKER_CONTEXT` from the shell, or empty if unset.
  String get dockerContext => _dockerContext;
  bool get hasDockerContext => _dockerContext.isNotEmpty;

  /// Active terraform workspace from the nearest `.terraform/environment`,
  /// or empty if not in a terraform project.
  String get terraformWorkspace => _terraformWorkspace;
  bool get hasTerraformWorkspace => _terraformWorkspace.isNotEmpty;

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

  /// Submits a line from the Bolan prompt. Marks the session as
  /// awaiting a shell response so the UI shows the live terminal —
  /// covering the case where the shell can't execute the input
  /// immediately (e.g. unfinished quote → continuation prompt) and
  /// no OSC 133 markers fire.
  void submitFromPrompt(String data) {
    if (_disposed) return;
    _awaitingShellResponse = true;
    notifyListeners();
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
    _liveOutputController.close();
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
      var cleaned = _stripUnsupportedCsi(decoded);
      cleaned = _patchInsertMode(cleaned);

      // If this single chunk contains an entire command lifecycle
      // (CommandStart marker followed later by a CommandEnd marker),
      // pre-extract the output slice so the CommandStart handler can
      // populate _outputCapture before CommandEnd's _finalizeBlock
      // runs synchronously inside terminal.write.
      _pendingSingleChunkOutput = _extractSingleChunkOutput(decoded);

      try {
        terminal.write(cleaned);
      } on RangeError catch (e, st) {
        debugPrint('terminal.write RangeError (xterm.dart resize race): $e\n$st');
      } on Object catch (e, st) {
        debugPrint('terminal.write failed: $e\n$st');
      }

      // Clear in case the CommandStart handler didn't fire (defensive).
      _pendingSingleChunkOutput = null;

      // Capture output while a command is running (multi-chunk path).
      if (_commandRunning) {
        _outputCapture.write(decoded);
        // Emit cleaned output for the live output block — strip
        // OSC sequences (shell integration markers), CSI non-SGR
        // (cursor movement), and charset switches so the inline
        // display only sees plain text + SGR color codes.
        _liveOutputController.add(_stripForLiveDisplay(decoded));
        // Detect alternate screen buffer usage (vim, less, top, etc.)
        if (!_usedAltBuffer && terminal.isUsingAltBuffer) {
          _usedAltBuffer = true;
          if (!_isTuiMode) {
            _isTuiMode = true;
            notifyListeners();
          }
        }
        // Count in-place redraw sequences. Catches both classic
        // cursor-up redraws (spinners, progress bars) and Ink-style
        // TUIs (Claude Code, modern Node.js CLIs) that draw via
        // cursor positioning + erase-line on the main screen buffer.
        _redrawSequenceCount += _countRedrawSequences(decoded);
        // Detect TUI mode from excessive redraw sequences or
        // full-screen cursor addressing (less -X, git log pager).
        if (!_isTuiMode) {
          final isTui = (_redrawSequenceCount > 50 &&
                  _outputCapture.length > 0 &&
                  _redrawSequenceCount / _outputCapture.length > 0.05) ||
              // Cursor home + clear screen = full-screen app.
              (decoded.contains('\x1B[H') &&
                  (decoded.contains('\x1B[2J') ||
                   decoded.contains('\x1B[J'))) ||
              // Cursor hide = interactive app waiting for input.
              decoded.contains('\x1B[?25l');
          if (isTui) {
            _isTuiMode = true;
            notifyListeners();
          }
        }
      }
    });

    // Terminal keyboard/mouse output → PTY input.
    //
    // Shift+Enter: xterm sends \r for both Enter and Shift+Enter.
    // Modern TUIs (Claude Code, opencode, gemini-cli, codex) treat
    // \r as "submit" and \n as "insert newline". We intercept \r
    // here and transform to \n when Shift is currently held, letting
    // users compose multi-line prompts inside those TUIs.
    terminal.onOutput = (data) {
      var out = data;
      if (out == '\r' && HardwareKeyboard.instance.isShiftPressed) {
        out = '\n';
      }
      _pty.write(const Utf8Encoder().convert(out));
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

    // OSC sequences: shell integration (133), CWD (7), Bolan
    // env-var snapshot (7777, custom — see _injectShellIntegration).
    terminal.onPrivateOSC = (String code, List<String> args) {
      if (code == '133') {
        final event = parseOsc133(args);
        if (event != null) _handleShellEvent(event);
      } else if (code == '7' && args.isNotEmpty) {
        _handleOsc7(args[0]);
      } else if (code == '7777') {
        _handleOscEnv(args);
      }
    };

    // Kick off the live tool detection for the initial cwd. Every
    // chip after this point refreshes via `_refreshOnPrompt` on
    // each PromptStart event — no polling timers.
    _updateNvmStatus();
    _updatePythonVenvStatus();
    _updateKubeStatus();
    _updateTerraformStatus();
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
        _isTuiMode = false;
        // Shell is back at a primary prompt — leave terminal-passthrough
        // mode (used for continuation prompts and other interactive
        // states with no OSC 133 markers).
        _awaitingShellResponse = false;
        // Refresh every live chip on each prompt so they reflect
        // changes from the just-finished command (git checkout,
        // terraform workspace select, kubectl config use-context,
        // etc.). Env-var chips are already refreshed by the OSC
        // 7777 hook on the same prompt cycle.
        _refreshOnPrompt();

      case PromptEnd():
        break;

      case CommandStart(:final command):
        if (command.isNotEmpty) {
          _outputCapture.clear();
          // For the single-chunk lifecycle case, pre-populate the
          // capture buffer with the output slice the listener
          // extracted before terminal.write was called. Otherwise
          // CommandEnd's _finalizeBlock would read empty output.
          if (_pendingSingleChunkOutput case final pending?) {
            _outputCapture.write(pending);
            _pendingSingleChunkOutput = null;
          }
          _usedAltBuffer = false;
          _redrawSequenceCount = 0;
          _isTuiMode = false;
          _cursorYAtCommandStart = terminal.buffer.absoluteCursorY;
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
      _isTuiMode = false;
      _outputCapture.clear();
      notifyListeners();
      return;
    }

    // TUI programs (vim, nano, Claude Code, etc.) produce output that
    // is mostly cursor positioning and would be garbled if captured as
    // raw bytes. Instead, read the terminal's rendered buffer — what
    // was actually on screen. This gives clean output for TUIs like
    // Claude Code that print a summary on exit.
    final capturedLength = _outputCapture.length;
    final isTui = _usedAltBuffer ||
        (_redrawSequenceCount > 50 && capturedLength > 0 &&
            _redrawSequenceCount / (capturedLength / 100) > 5);
    if (isTui) {
      final (plain, colored) = _readRenderedBuffer();
      _blocks.add(_activeBlock!.copyWith(
        output: plain,
        rawOutput: colored,
        exitCode: exitCode ?? -1,
        finishedAt: DateTime.now(),
        isRunning: false,
      ));
      _activeBlock = null;
      _commandRunning = false;
      _isTuiMode = false;
      _outputCapture.clear();
      _usedAltBuffer = false;
      _redrawSequenceCount = 0;
      notifyListeners();
      return;
    }

    // Clean up the captured output.
    // 1. Strip partial-line marker (zsh PROMPT_EOL_MARK).
    // 2. Collapse carriage returns: for each line, keep only the text
    //    after the last \r. This simulates what the terminal renders
    //    for progress bars, spinners, and interactive prompts that
    //    overwrite lines in place (composer progress, npm spinners).
    // 3. rawOutput preserves SGR color codes for colored rendering.
    //    output is fully stripped for plain-text copy.
    final captured = _collapseCarriageReturns(
        _stripPartialLineMarker(_outputCapture.toString()));
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
    _isTuiMode = false;
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
  /// Matches escape sequences that xterm.dart 4.0.0 does not
  /// implement and either misparses, drops only the introducer (and
  /// then renders the payload as text), or leaks the trailing byte
  /// as a literal character. Stripping them is safe because none of
  /// these affect visual rendering — they're purely
  /// host↔terminal protocol negotiation or out-of-band features
  /// (sixel, kitty graphics, terminfo queries) that xterm.dart can't
  /// render anyway.
  ///
  /// Covered:
  ///   `\e[>...FINAL`  — private CSI `>` (e.g. XTMODKEYS `\e[>4m`,
  ///                     which xterm.dart misreads as `\e[4m`
  ///                     underline because it drops the `>` prefix)
  ///   `\e[<...FINAL`  — private CSI `<` (kitty keyboard restore)
  ///   `\e=`           — DECKPAM (Application Keypad Mode)
  ///   `\e>`           — DECKPNM (Normal Keypad Mode)
  ///   `\eP...ST`      — DCS (Device Control String, sixel etc.)
  ///   `\e^...ST`      — PM  (Privacy Message)
  ///   `\e_...ST`      — APC (Application Program Command, kitty
  ///                     graphics, iTerm2 image protocol)
  ///   `\eX...ST`      — SOS (Start of String)
  ///
  /// For the last four, xterm.dart's parser only consumes the 2-byte
  /// introducer (`\eP`, `\e_`, …) and discards just that — the
  /// payload that should run until ST (`\e\` or BEL) then renders
  /// verbatim into the buffer, which can manifest as a long line of
  /// gibberish or a stray `⊠`-like glyph for ESC followed by random
  /// content. Stripping the entire string solves both at once.
  ///
  /// `\e=` and `\e>` were the source of the mysterious `⊠>` at the
  /// bottom of `git diff` (less emits them around its session).
  static final _unsupportedEscapeRe = RegExp(
    r'\x1B\[[<>][0-9;]*[a-zA-Z]'
    r'|\x1B[=>]'
    r'|\x1B[P^_X][^\x07\x1B]*(?:\x07|\x1B\\)',
  );

  static String _stripUnsupportedCsi(String input) {
    return input.replaceAll(_unsupportedEscapeRe, '');
  }

  /// Workaround for xterm.dart's broken insert mode. When `\e[4h`
  /// (Set Insert Mode) is seen, we track the state. While insert mode
  /// is active, we inject `\e[@` (Insert Character, shifts existing
  /// chars right by 1) before each printable character. This makes
  /// nano work correctly — without it, characters overwrite instead
  /// of inserting because xterm.dart's `writeChar` ignores insertMode.
  ///
  /// State is maintained across chunks so split sequences work.
  String _patchInsertMode(String input) {
    final buf = StringBuffer();
    var i = 0;
    while (i < input.length) {
      // Check for ESC
      if (input.codeUnitAt(i) == 0x1B && i + 1 < input.length) {
        // Look for CSI: ESC [
        if (input.codeUnitAt(i + 1) == 0x5B) {
          // Find the end of the CSI sequence
          var j = i + 2;
          while (j < input.length) {
            final c = input.codeUnitAt(j);
            if (c >= 0x40 && c <= 0x7E) break; // final byte
            j++;
          }
          if (j < input.length) {
            final seq = input.substring(i, j + 1);
            if (seq == '\x1b[4h') {
              _termInsertMode = true;
            } else if (seq == '\x1b[4l') {
              _termInsertMode = false;
            }
            buf.write(seq);
            i = j + 1;
            continue;
          }
        }
        // Non-CSI escape — pass through
        buf.write(input[i]);
        i++;
        continue;
      }

      final c = input.codeUnitAt(i);
      // Printable character while insert mode is on → inject ICH
      if (_termInsertMode && c >= 0x20 && c != 0x7F) {
        buf.write('\x1b[@');
      }
      buf.write(input[i]);
      i++;
    }
    return buf.toString();
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
  static final _partialLineMarkerRe =
      RegExp(r'(?:\x1B\[[0-9;]*m)*\x1B\[7m[%#](?:\x1B\[[0-9;]*m)+ *\r');

  static String _stripPartialLineMarker(String input) {
    return input.replaceAll(_partialLineMarkerRe, '');
  }

  static final _ansiEscapeRe = RegExp(
      r'\x1B\[[0-9;?]*[a-zA-Z]|\x1B\][^\x07\x1B]*(?:\x07|\x1B\\)|\x1B[()][0-9A-Z]|\x1B[>=<]');

  static String _stripAnsiEscapes(String input) {
    return input.replaceAll(_ansiEscapeRe, '');
  }

  /// Strips all escape sequences EXCEPT SGR color codes (\e[...m).
  /// Used to preserve colors for rich text rendering in blocks.
  static final _nonSgrEscapeRe = RegExp(
    r'\x1B\[[0-9;?>]*[a-ln-zA-Z]' // CSI except 'm'
    r'|\x1B\][^\x07\x1B]*(?:\x07|\x1B\\)' // OSC
    r'|\x1B[()*/+][0-9A-Z%]?' // Charset
    r'|\x1B[@-Z\\^_]' // Single-char Fe (C1)
    r'|\x1B[<=>]', // Private two-char (DECKPAM, DECKPNM, etc.)
  );

  static String _stripNonSgrEscapes(String input) {
    return input.replaceAll(_nonSgrEscapeRe, '');
  }

  /// Collapses carriage returns within each line. When a line contains
  /// `\r` (without `\n`), the terminal overwrites from the start of
  /// the line. We simulate this by keeping only the text after the
  /// last `\r` on each line. This cleans up progress bars, spinners,
  /// and interactive prompts that redraw in place.
  /// Reads the terminal's rendered buffer as text with ANSI SGR color
  /// codes reconstructed from cell attributes. Used for TUI programs
  /// where the raw byte capture is garbled but the terminal buffer
  /// has the properly rendered result with colors intact.
  (String plain, String colored) _readRenderedBuffer() {
    final buf = terminal.buffer;
    final plainBuf = StringBuffer();
    final colorBuf = StringBuffer();

    var lastFg = 0;
    var lastBg = 0;
    var lastFlags = 0;
    var lineCount = 0;

    // Start from where the cursor was when the command began, not
    // from the top of the buffer. This avoids capturing output from
    // previous commands. Uses cursor Y (not buffer height) because
    // circular buffers don't grow past their max size.
    final startRow = _cursorYAtCommandStart;

    for (var row = startRow; row < buf.height; row++) {
      final line = buf.lines[row];

      if (row > startRow) {
        plainBuf.write('\n');
        colorBuf.write('\n');
      }

      // Walk cells manually instead of using getText() which skips
      // empty cells (codepoint 0). Empty cells are visual spaces —
      // TUIs use cursor positioning to lay out text, leaving gaps
      // that must be preserved as spaces.
      final width = buf.viewWidth;
      final plainLineBuf = StringBuffer();
      for (var col = 0; col < width; col++) {
        final fg = line.getForeground(col);
        final bg = line.getBackground(col);
        final flags = line.getAttributes(col);
        final cp = line.getCodePoint(col);
        final ch = cp > 0 ? cp : 0x20; // empty cell = space

        if (fg != lastFg || bg != lastBg || flags != lastFlags) {
          colorBuf.write(_cellAttrsToSgr(fg, bg, flags));
          lastFg = fg;
          lastBg = bg;
          lastFlags = flags;
        }

        colorBuf.writeCharCode(ch);
        plainLineBuf.writeCharCode(ch);
      }

      final plainLine = plainLineBuf.toString().trimRight();
      plainBuf.write(plainLine);
      if (plainLine.isNotEmpty) lineCount = row - startRow + 1;
    }

    // Reset at the end
    if (lastFg != 0 || lastBg != 0 || lastFlags != 0) {
      colorBuf.write('\x1B[0m');
    }

    // Trim trailing empty lines
    final plainLines = plainBuf.toString().split('\n');
    while (plainLines.length > lineCount && plainLines.isNotEmpty) {
      plainLines.removeLast();
    }
    final colorLines = colorBuf.toString().split('\n');
    while (colorLines.length > lineCount && colorLines.isNotEmpty) {
      colorLines.removeLast();
    }

    return (plainLines.join('\n'), colorLines.join('\n'));
  }

  /// Converts xterm.dart cell attributes back to an ANSI SGR sequence.
  static String _cellAttrsToSgr(int fg, int bg, int flags) {
    final codes = <String>['0']; // reset first

    // Flags
    if (flags & CellAttr.bold != 0) codes.add('1');
    if (flags & CellAttr.faint != 0) codes.add('2');
    if (flags & CellAttr.italic != 0) codes.add('3');
    if (flags & CellAttr.underline != 0) codes.add('4');
    if (flags & CellAttr.inverse != 0) codes.add('7');
    if (flags & CellAttr.strikethrough != 0) codes.add('9');

    // Foreground
    final fgType = fg & CellColor.typeMask;
    final fgVal = fg & CellColor.valueMask;
    if (fgType == CellColor.named) {
      codes.add(fgVal < 8 ? '${30 + fgVal}' : '${90 + fgVal - 8}');
    } else if (fgType == CellColor.palette) {
      codes.add('38;5;$fgVal');
    } else if (fgType == CellColor.rgb) {
      codes.add('38;2;${(fgVal >> 16) & 0xFF};${(fgVal >> 8) & 0xFF};${fgVal & 0xFF}');
    }

    // Background
    final bgType = bg & CellColor.typeMask;
    final bgVal = bg & CellColor.valueMask;
    if (bgType == CellColor.named) {
      codes.add(bgVal < 8 ? '${40 + bgVal}' : '${100 + bgVal - 8}');
    } else if (bgType == CellColor.palette) {
      codes.add('48;5;$bgVal');
    } else if (bgType == CellColor.rgb) {
      codes.add('48;2;${(bgVal >> 16) & 0xFF};${(bgVal >> 8) & 0xFF};${bgVal & 0xFF}');
    }

    return '\x1B[${codes.join(";")}m';
  }

  static String _collapseCarriageReturns(String input) {
    final lines = input.split('\n');
    final result = StringBuffer();
    for (var i = 0; i < lines.length; i++) {
      if (i > 0) result.write('\n');
      var line = lines[i];
      // Strip a single trailing \r (normal line ending in raw capture).
      if (line.endsWith('\r')) {
        line = line.substring(0, line.length - 1);
      }
      // If there are still \r characters inside the line, the terminal
      // overwrote content in place (progress bars, spinners). Keep
      // only the text after the last \r.
      final lastCr = line.lastIndexOf('\r');
      if (lastCr >= 0) {
        result.write(line.substring(lastCr + 1));
      } else {
        result.write(line);
      }
    }
    return result.toString();
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
        _updateNvmStatus();
        _updatePythonVenvStatus();
        _updateTerraformStatus();
        notifyListeners();
      }
    } on FormatException {
      // Ignore malformed URIs
    }
  }

  /// Handles OSC 7777 — Bolan-specific env var snapshot emitted by
  /// the shell integration on every prompt. Args is a list of
  /// `KEY=VALUE` strings; missing keys/values are normalized to
  /// empty strings here.
  void _handleOscEnv(List<String> args) {
    var changed = false;
    for (final pair in args) {
      final eq = pair.indexOf('=');
      if (eq < 0) continue;
      final key = pair.substring(0, eq);
      final value = pair.substring(eq + 1);
      switch (key) {
        case 'AWS_PROFILE':
          if (_awsProfile != value) {
            _awsProfile = value;
            changed = true;
          }
        case 'GCP_PROJECT':
          if (_gcpProject != value) {
            _gcpProject = value;
            changed = true;
          }
        case 'DOCKER_CONTEXT':
          if (_dockerContext != value) {
            _dockerContext = value;
            changed = true;
          }
        case 'VIRTUAL_ENV':
          if (_activeVirtualEnv != value) {
            _activeVirtualEnv = value;
            changed = true;
          }
        case 'NODE_VERSION':
          // Comes from the SHELL's `node --version`, which sees
          // whichever node nvm has switched into the parent shell's
          // PATH. Spawning `node` ourselves wouldn't see those
          // mutations because subprocesses re-read PATH from scratch.
          if (_nodeVersion != value) {
            _nodeVersion = value;
            changed = true;
          }
      }
    }
    if (changed) notifyListeners();
  }

  /// Walks up the cwd ancestor chain looking for `.terraform/environment`,
  /// the file Terraform writes to track the active workspace per
  /// project. Reads it directly — no `terraform` command needed.
  Future<void> _updateTerraformStatus() async {
    if (_cwd.isEmpty) return;
    final found = _findAncestorFile(_cwd, '.terraform/environment');
    if (found == null) {
      if (_terraformWorkspace.isNotEmpty) {
        _terraformWorkspace = '';
        notifyListeners();
      }
      return;
    }
    try {
      final raw = await File(found).readAsString();
      final ws = raw.trim();
      if (ws != _terraformWorkspace) {
        _terraformWorkspace = ws;
        notifyListeners();
      }
    } on FileSystemException {
      // Best effort.
    }
  }

  /// Walks up the cwd ancestor chain looking for an `.nvmrc` file
  /// and reads the requested version. The currently *active* node
  /// version is NOT detected here — that comes from the shell's
  /// own `node --version` via the OSC 7777 env-var hook, because a
  /// child process spawned from Bolan re-reads PATH from scratch
  /// and would never see nvm's runtime PATH mutations.
  Future<void> _updateNvmStatus() async {
    if (_cwd.isEmpty) return;
    final found = _findAncestorFile(_cwd, '.nvmrc');
    if (found == null) {
      if (_nvmrcVersion.isNotEmpty || _nvmrcDir.isNotEmpty) {
        _nvmrcVersion = '';
        _nvmrcDir = '';
        notifyListeners();
      }
      return;
    }
    try {
      final raw = await File(found).readAsString();
      final requested = raw.trim().replaceFirst(RegExp(r'^v'), '');
      if (requested != _nvmrcVersion) {
        _nvmrcVersion = requested;
        _nvmrcDir = found.substring(0, found.length - '.nvmrc'.length);
        notifyListeners();
      }
    } on FileSystemException {
      if (_nvmrcVersion.isNotEmpty) {
        _nvmrcVersion = '';
        _nvmrcDir = '';
        notifyListeners();
      }
    }
  }

  /// Re-runs every file/command-based detector that could change
  /// between commands. Called on every `PromptStart` (OSC 133;A)
  /// so chips reflect the live state of the terminal after every
  /// command, not just on cwd changes. Env-var-driven chips
  /// (AWS / GCP / Docker / VIRTUAL_ENV / NODE_VERSION) are
  /// already refreshed by `_handleOscEnv` on the same prompt.
  void _refreshOnPrompt() {
    if (_cwd.isEmpty) return;
    _updateGitStatus();
    _updateNvmStatus();
    _updatePythonVenvStatus();
    _updateTerraformStatus();
    _updateKubeStatus();
  }

  /// Walks up the cwd ancestor chain for `pyvenv.cfg`. The directory
  /// containing it is the venv root; its basename is shown in the
  /// chip and the python version is read from the cfg file.
  Future<void> _updatePythonVenvStatus() async {
    if (_cwd.isEmpty) return;
    final cfgPath = _findAncestorFile(_cwd, 'pyvenv.cfg');
    if (cfgPath == null) {
      if (_pythonVenvName.isNotEmpty) {
        _pythonVenvName = '';
        _pythonVenvVersion = '';
        _pythonVenvPath = '';
        notifyListeners();
      }
      return;
    }
    final venvDir = cfgPath.substring(0, cfgPath.length - '/pyvenv.cfg'.length);
    final venvName = venvDir.split('/').last;
    String version = '';
    try {
      final raw = await File(cfgPath).readAsString();
      for (final line in raw.split('\n')) {
        final m = _pyvenvVersionRe.firstMatch(line.trim());
        if (m != null) {
          version = m.group(1)!.trim();
          break;
        }
      }
    } on FileSystemException {
      // Best effort — show the venv even if we can't parse the cfg.
    }
    if (_pythonVenvName != venvName ||
        _pythonVenvVersion != version ||
        _pythonVenvPath != venvDir) {
      _pythonVenvName = venvName;
      _pythonVenvVersion = version;
      _pythonVenvPath = venvDir;
      notifyListeners();
    }
  }

  /// Polls `kubectl config current-context` (and the active
  /// namespace) at a low frequency. The chip shows whatever is
  /// currently active across the whole machine, not per-cwd.
  Future<void> _updateKubeStatus() async {
    try {
      final ctxResult = await Process.run(
        'kubectl',
        ['config', 'current-context'],
      );
      if (ctxResult.exitCode != 0) {
        if (_kubeContext.isNotEmpty || _kubeNamespace.isNotEmpty) {
          _kubeContext = '';
          _kubeNamespace = '';
          notifyListeners();
        }
        return;
      }
      final newContext = (ctxResult.stdout as String).trim();

      final nsResult = await Process.run(
        'kubectl',
        [
          'config',
          'view',
          '--minify',
          '--output',
          'jsonpath={..namespace}',
        ],
      );
      final newNamespace = nsResult.exitCode == 0
          ? (nsResult.stdout as String).trim()
          : '';

      if (newContext != _kubeContext || newNamespace != _kubeNamespace) {
        _kubeContext = newContext;
        _kubeNamespace = newNamespace;
        notifyListeners();
      }
    } on ProcessException {
      // kubectl not installed — leave state empty, the chip won't render.
      if (_kubeContext.isNotEmpty || _kubeNamespace.isNotEmpty) {
        _kubeContext = '';
        _kubeNamespace = '';
        notifyListeners();
      }
    }
  }

  /// Walks up from [start] looking for [filename]. Returns the
  /// absolute path of the first match, or null if it reaches the
  /// filesystem root without finding it.
  String? _findAncestorFile(String start, String filename) {
    var dir = start;
    while (dir.isNotEmpty && dir != '/') {
      final candidate = '$dir/$filename';
      if (File(candidate).existsSync()) return candidate;
      final i = dir.lastIndexOf('/');
      if (i <= 0) break;
      dir = dir.substring(0, i);
    }
    // Check the root too.
    final rootCandidate = '/$filename';
    if (File(rootCandidate).existsSync()) return rootCandidate;
    return null;
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
    final shellName = _resolvedShell.split('/').last;
    String? script;

    if (shellName == 'zsh') {
      // Hide the shell's native prompt — Bolan renders its own prompt area.
      // Set PS1 to empty so no prompt text appears in the terminal output.
      //
      // OSC 7777 (Bolan-specific) emits a snapshot of selected env
      // vars on every prompt. The session parses these and updates
      // the live tool chips that depend on shell-side state — AWS
      // profile, GCP project, Docker context, active Python venv.
      script = r"""
PS1=''
RPS1=''
PROMPT=''
__bolan_prompt_start() { printf '\e]133;A\a'; }
__bolan_prompt_end()   { printf '\e]133;B\a'; }
__bolan_cmd_start()    { printf '\e]133;C;%s\a' "$1"; }
__bolan_cmd_end()      { local ec=$?; printf "\e]133;D;$ec\a"; }
__bolan_osc7()         { printf '\e]7;file://%s%s\a' "$HOST" "$PWD"; }
__bolan_env() {
  local node_version=""
  if command -v node >/dev/null 2>&1; then
    node_version=$(node --version 2>/dev/null)
  fi
  printf '\e]7777;AWS_PROFILE=%s;GCP_PROJECT=%s;DOCKER_CONTEXT=%s;VIRTUAL_ENV=%s;NODE_VERSION=%s\a' \
    "${AWS_PROFILE:-}" \
    "${CLOUDSDK_CORE_PROJECT:-${GCP_PROJECT:-}}" \
    "${DOCKER_CONTEXT:-}" \
    "${VIRTUAL_ENV:-}" \
    "$node_version"
}
autoload -Uz add-zsh-hook
add-zsh-hook precmd  __bolan_cmd_end
add-zsh-hook precmd  __bolan_prompt_start
add-zsh-hook precmd  __bolan_osc7
add-zsh-hook precmd  __bolan_env
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
__bolan_env() {
  local node_version=""
  if command -v node >/dev/null 2>&1; then
    node_version=$(node --version 2>/dev/null)
  fi
  printf '\e]7777;AWS_PROFILE=%s;GCP_PROJECT=%s;DOCKER_CONTEXT=%s;VIRTUAL_ENV=%s;NODE_VERSION=%s\a' \
    "${AWS_PROFILE:-}" \
    "${CLOUDSDK_CORE_PROJECT:-${GCP_PROJECT:-}}" \
    "${DOCKER_CONTEXT:-}" \
    "${VIRTUAL_ENV:-}" \
    "$node_version"
}
# bash's DEBUG trap fires for EVERY simple command, including the
# ones that run inside PROMPT_COMMAND. Without a guard, every prompt
# would re-fire __bolan_preexec for `__bolan_cmd_end`,
# `__bolan_prompt_start`, etc. and Bolan would record `__bolan_precmd`
# as the running command. We use a guard variable that's set while
# PROMPT_COMMAND is running so the DEBUG trap can ignore those calls
# (this is the same technique bash-preexec.sh uses).
#
# We SUBSUME the user's existing PROMPT_COMMAND (e.g. Ubuntu's
# __vte_prompt_command from /etc/bash.bashrc) into our precmd hook
# rather than chaining after it, so those commands execute INSIDE
# the guard and don't trip the DEBUG trap. Chaining caused a
# spurious `__vte_prompt_command` CommandStart at every prompt on
# Linux, leaving Bolan stuck in "command running" mode and hiding
# the prompt/block UI.
__bolan_existing_prompt_command="${PROMPT_COMMAND:-}"
__bolan_inside_precmd=0
__bolan_preexec_invoke() {
  # Skip if we're already inside PROMPT_COMMAND.
  if [[ "$__bolan_inside_precmd" -eq 1 ]]; then return; fi
  # Skip readline completion machinery.
  if [[ -n "$COMP_LINE" ]]; then return; fi
  # Skip our own internal functions.
  case "$BASH_COMMAND" in
    __bolan_*) return ;;
  esac
  __bolan_prompt_end
  __bolan_cmd_start
}
__bolan_precmd_invoke() {
  local __bolan_last_ec=$?
  __bolan_inside_precmd=1
  # Preserve $? for __bolan_cmd_end so the D marker carries the
  # real exit code of the just-finished command.
  (exit $__bolan_last_ec); __bolan_cmd_end
  __bolan_prompt_start
  __bolan_osc7
  __bolan_env
  # Run whatever the user (or system bashrc) had in PROMPT_COMMAND
  # before us. The guard above keeps any DEBUG trap firings for
  # these commands from generating spurious OSC 133 markers.
  if [[ -n "$__bolan_existing_prompt_command" ]]; then
    eval "$__bolan_existing_prompt_command"
  fi
  __bolan_inside_precmd=0
}
# Install PROMPT_COMMAND BEFORE the DEBUG trap so the assignment
# itself doesn't fire a spurious CommandStart during sourcing.
PROMPT_COMMAND=__bolan_precmd_invoke
trap '__bolan_preexec_invoke' DEBUG
""";
    }

    if (script == null) {
      _hasShellIntegration = false;
      return;
    }

    _hasShellIntegration = true;
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

    final filesMatch = _shortstatFilesRe.firstMatch(output);
    final insMatch = _shortstatInsRe.firstMatch(output);
    final delMatch = _shortstatDelRe.firstMatch(output);

    if (filesMatch != null) _gitFilesChanged = int.parse(filesMatch.group(1)!);
    if (insMatch != null) _gitInsertions = int.parse(insMatch.group(1)!);
    if (delMatch != null) _gitDeletions = int.parse(delMatch.group(1)!);
  }

  static final _pyvenvVersionRe = RegExp(r'^version\s*=\s*(.+)$');
  /// If [chunk] contains a complete OSC 133 command lifecycle
  /// (CommandStart `\e]133;C[;...]\a` followed by CommandEnd
  /// `\e]133;D[;...]\a`), returns the bytes between the two markers.
  /// Otherwise returns null. Used to pre-populate the output capture
  /// buffer for short commands whose entire run fits in one PTY chunk.
  static String? _extractSingleChunkOutput(String chunk) {
    final cIdx = chunk.indexOf('\x1b]133;C');
    if (cIdx < 0) return null;
    final cBel = chunk.indexOf('\x07', cIdx);
    if (cBel < 0) return null;
    final outputStart = cBel + 1;
    final dIdx = chunk.indexOf('\x1b]133;D', outputStart);
    if (dIdx < outputStart) return null;
    return chunk.substring(outputStart, dIdx);
  }

  static final _shortstatFilesRe = RegExp(r'(\d+) files? changed');
  static final _shortstatInsRe = RegExp(r'(\d+) insertions?');
  static final _shortstatDelRe = RegExp(r'(\d+) deletions?');

  static String _defaultShell() {
    if (Platform.isMacOS || Platform.isLinux) {
      if (File('/bin/zsh').existsSync()) return '/bin/zsh';
      if (File('/usr/bin/zsh').existsSync()) return '/usr/bin/zsh';
      return Platform.environment['SHELL'] ?? '/bin/bash';
    }
    return '/bin/sh';
  }
}
