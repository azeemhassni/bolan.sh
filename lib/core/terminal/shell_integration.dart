/// Represents shell integration events detected via OSC 133 sequences.
///
/// The shell integration scripts emit these markers:
///   A — prompt start
///   B — prompt end (user has typed command, about to execute)
///   C — command output start
///   D;exitCode — command finished
sealed class ShellEvent {
  const ShellEvent();
}

/// The shell is displaying a prompt (ready for input).
class PromptStart extends ShellEvent {
  const PromptStart();
}

/// The user has finished typing and the command is about to execute.
class PromptEnd extends ShellEvent {
  const PromptEnd();
}

/// Command output has started.
class CommandStart extends ShellEvent {
  const CommandStart();
}

/// Command has finished executing.
class CommandEnd extends ShellEvent {
  final int exitCode;
  const CommandEnd(this.exitCode);
}

/// Parses OSC 133 sequence parameters into [ShellEvent]s.
///
/// Called from [Terminal.onPrivateOSC] when code is "133".
/// The [args] list contains the sub-command (A/B/C/D) and optional parameters.
ShellEvent? parseOsc133(List<String> args) {
  if (args.isEmpty) return null;

  return switch (args[0]) {
    'A' => const PromptStart(),
    'B' => const PromptEnd(),
    'C' => const CommandStart(),
    'D' => CommandEnd(_parseExitCode(args)),
    _ => null,
  };
}

int _parseExitCode(List<String> args) {
  if (args.length < 2) return 0;
  return int.tryParse(args[1]) ?? 0;
}
