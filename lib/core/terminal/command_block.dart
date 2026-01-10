/// Data model for a single command and its output in the block model.
///
/// Each command typed at the prompt becomes a [CommandBlock] once executed.
/// The block tracks the command text, output lines, timing, and exit code.
class CommandBlock {
  final String id;
  final String command;
  final List<String> outputLines;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final int? exitCode;
  final bool isRunning;

  const CommandBlock({
    required this.id,
    required this.command,
    this.outputLines = const [],
    required this.startedAt,
    this.finishedAt,
    this.exitCode,
    this.isRunning = true,
  });

  CommandBlock copyWith({
    String? id,
    String? command,
    List<String>? outputLines,
    DateTime? startedAt,
    DateTime? finishedAt,
    int? exitCode,
    bool? isRunning,
  }) {
    return CommandBlock(
      id: id ?? this.id,
      command: command ?? this.command,
      outputLines: outputLines ?? this.outputLines,
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
}
