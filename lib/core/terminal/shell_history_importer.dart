import 'dart:io';

/// Detects the user's login shell and parses its history file into a
/// flat list of commands suitable for seeding [CommandHistory].
///
/// Supports bash and zsh. Skips multi-line entries (Bolan history is
/// one-line-per-entry; supporting multi-line will require a storage
/// format change). Skips entries beginning with a single space — zsh's
/// `HIST_IGNORE_SPACE` convention indicates the user intentionally
/// hid those commands and we should respect that.
class ShellHistoryImporter {
  ShellHistoryImporter._();

  /// Returns parsed history entries from the user's shell, or `null`
  /// if the shell can't be detected or has no readable history file.
  /// Order is oldest → newest, deduped (last occurrence wins).
  static Future<List<String>?> autoDetect() async {
    final shellPath = Platform.environment['SHELL'] ?? '';
    final shell = shellPath.split('/').last.toLowerCase();
    final home = Platform.environment['HOME'] ?? '';
    if (home.isEmpty) return null;

    final histFileEnv = Platform.environment['HISTFILE'];

    File? file;
    List<String> Function(String)? parser;

    switch (shell) {
      case 'zsh':
        file = File(histFileEnv ?? '$home/.zsh_history');
        parser = parseZsh;
        break;
      case 'bash':
        file = File(histFileEnv ?? '$home/.bash_history');
        parser = parseBash;
        break;
      default:
        // Try zsh then bash as fallbacks — many users have an unusual
        // SHELL but still keep one of these files around.
        final zsh = File('$home/.zsh_history');
        if (zsh.existsSync()) {
          file = zsh;
          parser = parseZsh;
          break;
        }
        final bash = File('$home/.bash_history');
        if (bash.existsSync()) {
          file = bash;
          parser = parseBash;
          break;
        }
        return null;
    }

    if (!file.existsSync()) return null;

    String content;
    try {
      // zsh history is sometimes meta-encoded with bytes > 0x7f xor'd
      // with 0x20. Reading as latin-1 then sanitizing avoids decoder
      // errors on non-UTF8 entries.
      content = file.readAsStringSync(encoding: const SystemEncoding());
    } on FileSystemException {
      return null;
    } on FormatException {
      try {
        content = String.fromCharCodes(file.readAsBytesSync());
      } on Exception {
        return null;
      }
    }

    final parsed = parser(content);
    return _dedupePreservingOrder(parsed);
  }

  /// Parses a bash history file. Strips `#<timestamp>` lines that
  /// appear when `HISTTIMEFORMAT` is set, blank lines, and entries
  /// that start with a space.
  static List<String> parseBash(String content) {
    final out = <String>[];
    for (final raw in content.split('\n')) {
      if (raw.isEmpty) continue;
      // HISTTIMEFORMAT timestamp lines look like "#1700000000".
      if (raw.startsWith('#') && raw.length > 1 &&
          raw.codeUnitAt(1) >= 0x30 && raw.codeUnitAt(1) <= 0x39) {
        continue;
      }
      if (raw.startsWith(' ')) continue;
      final trimmed = raw.trimRight();
      if (trimmed.isEmpty) continue;
      out.add(trimmed);
    }
    return out;
  }

  /// Parses a zsh history file. Handles both plain and EXTENDED_HISTORY
  /// formats. Multi-line entries (commands continued via `\<LF>`) are
  /// skipped — the format is `: <ts>:<duration>;<command>` and a
  /// trailing backslash before the newline indicates continuation.
  static List<String> parseZsh(String content) {
    final out = <String>[];
    final lines = content.split('\n');
    var i = 0;
    while (i < lines.length) {
      var line = lines[i];
      i++;
      if (line.isEmpty) continue;

      // EXTENDED_HISTORY entries start with ": <ts>:<n>;<cmd>".
      if (line.startsWith(': ')) {
        final semi = line.indexOf(';');
        if (semi == -1) continue;
        line = line.substring(semi + 1);
      }

      // Skip multi-line: a trailing unescaped `\` means the entry
      // continues on the next line. Drop the whole entry.
      if (line.endsWith('\\')) {
        // Consume continuation lines until we hit one without a
        // trailing backslash, then discard the lot.
        while (i < lines.length && lines[i].endsWith('\\')) {
          i++;
        }
        if (i < lines.length) i++;
        continue;
      }

      if (line.startsWith(' ')) continue;
      final trimmed = line.trimRight();
      if (trimmed.isEmpty) continue;
      out.add(trimmed);
    }
    return out;
  }

  /// Removes duplicates while keeping the most recent occurrence of
  /// each command. Order in the result matches the input order with
  /// earlier duplicates dropped.
  static List<String> _dedupePreservingOrder(List<String> entries) {
    final seenLastIndex = <String, int>{};
    for (var i = 0; i < entries.length; i++) {
      seenLastIndex[entries[i]] = i;
    }
    final keep = <String>[];
    for (var i = 0; i < entries.length; i++) {
      if (seenLastIndex[entries[i]] == i) keep.add(entries[i]);
    }
    return keep;
  }
}
