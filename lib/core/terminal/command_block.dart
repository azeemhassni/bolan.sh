/// Data model for a single command and its output in the block model.
///
/// Each command typed at the prompt becomes a [CommandBlock] once executed.
/// The block captures the full output text, timing, and exit code.
/// Output can be copied with a single click.
class CommandBlock {
  final String id;
  final String command;
  final String output;
  final String rawOutput; // preserves ANSI color codes for rendering
  final DateTime startedAt;
  final DateTime? finishedAt;
  final int? exitCode;
  final bool isRunning;

  const CommandBlock({
    required this.id,
    required this.command,
    this.output = '',
    this.rawOutput = '',
    required this.startedAt,
    this.finishedAt,
    this.exitCode,
    this.isRunning = true,
  });

  CommandBlock copyWith({
    String? id,
    String? command,
    String? output,
    String? rawOutput,
    DateTime? startedAt,
    DateTime? finishedAt,
    int? exitCode,
    bool? isRunning,
  }) {
    return CommandBlock(
      id: id ?? this.id,
      command: command ?? this.command,
      output: output ?? this.output,
      rawOutput: rawOutput ?? this.rawOutput,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      exitCode: exitCode ?? this.exitCode,
      isRunning: isRunning ?? this.isRunning,
    );
  }

  /// Duration from start to finish, or null if still running.
  Duration? get duration => finishedAt?.difference(startedAt);

  /// Whether the command exited successfully (code 0).
  bool get succeeded => exitCode == 0;

  /// Whether this block has any output to display.
  bool get hasOutput => output.isNotEmpty;
}
