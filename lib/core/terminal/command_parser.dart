// Lightweight shell command parser for extracting command names
// from pipelines and chains. Handles quoting so that commands
// inside string arguments aren't mistaken for real commands.

/// Extracts the command names from a shell command string,
/// splitting on `&&`, `||`, `;`, and `|` while respecting
/// single/double quotes and backslash escapes.
///
/// Examples:
///   "ls -la" → ["ls"]
///   "echo 'hello' && mysql -u root" → ["echo", "mysql"]
///   'echo " && mysql" && sleep 2' → ["echo", "sleep"]
///   "sudo su -" → ["su"]
///   "ls | grep foo && ssh user@host" → ["ls", "grep", "ssh"]
List<String> extractCommandNames(String input) {
  final segments = _splitOutsideQuotes(input.trim());
  final names = <String>[];
  for (final seg in segments) {
    final name = _extractCommandName(seg.trim());
    if (name.isNotEmpty) names.add(name);
  }
  return names;
}

/// Splits a command string on `&&`, `||`, `;`, `|` but only
/// when they appear outside of single/double quotes.
List<String> _splitOutsideQuotes(String input) {
  final segments = <String>[];
  final current = StringBuffer();
  var inSingle = false;
  var inDouble = false;
  var escaped = false;

  for (var i = 0; i < input.length; i++) {
    if (escaped) {
      current.writeCharCode(input.codeUnitAt(i));
      escaped = false;
      continue;
    }

    final c = input[i];

    if (c == '\\' && !inSingle) {
      escaped = true;
      current.write(c);
      continue;
    }

    if (c == "'" && !inDouble) {
      inSingle = !inSingle;
      current.write(c);
      continue;
    }

    if (c == '"' && !inSingle) {
      inDouble = !inDouble;
      current.write(c);
      continue;
    }

    // Only split when outside quotes.
    if (!inSingle && !inDouble) {
      // Check for && and ||
      if (i + 1 < input.length) {
        final pair = input.substring(i, i + 2);
        if (pair == '&&' || pair == '||') {
          segments.add(current.toString());
          current.clear();
          i++; // skip the second character
          continue;
        }
      }
      // Check for ; and |
      if (c == ';' || c == '|') {
        segments.add(current.toString());
        current.clear();
        continue;
      }
    }

    current.write(c);
  }

  if (current.isNotEmpty) {
    segments.add(current.toString());
  }

  return segments;
}

/// Extracts the command name from a single command segment.
/// Strips leading env assignments (FOO=bar), sudo/env prefixes,
/// and returns the base command name.
String _extractCommandName(String segment) {
  final words = _tokenize(segment);
  if (words.isEmpty) return '';

  var i = 0;

  // Skip env var assignments and command prefixes. These can
  // interleave: `sudo env FOO=bar nohup python3`.
  var changed = true;
  while (changed && i < words.length) {
    changed = false;
    // Skip KEY=value assignments.
    while (i < words.length &&
        words[i].contains('=') &&
        !words[i].startsWith('-')) {
      i++;
      changed = true;
    }
    // Skip known command prefixes.
    if (i < words.length) {
      final w = words[i];
      if (w == 'sudo' ||
          w == 'env' ||
          w == 'nice' ||
          w == 'nohup' ||
          w == 'time' ||
          w == 'command' ||
          w == 'builtin' ||
          w == 'exec') {
        i++;
        changed = true;
        // Skip flags after prefix (e.g. sudo -u root)
        while (i < words.length && words[i].startsWith('-')) {
          i++;
          // Skip flag argument if the flag expects one
          if (i < words.length &&
              !words[i].startsWith('-') &&
              !words[i].contains('=')) {
            i++;
          }
        }
      }
    }
  }

  if (i >= words.length) return '';

  // Return just the base name (strip path).
  final cmd = words[i];
  final slash = cmd.lastIndexOf('/');
  return slash >= 0 ? cmd.substring(slash + 1) : cmd;
}

/// Simple tokenizer that splits on whitespace but respects quotes.
List<String> _tokenize(String input) {
  final tokens = <String>[];
  final current = StringBuffer();
  var inSingle = false;
  var inDouble = false;
  var escaped = false;

  for (var i = 0; i < input.length; i++) {
    if (escaped) {
      current.writeCharCode(input.codeUnitAt(i));
      escaped = false;
      continue;
    }

    final c = input[i];

    if (c == '\\' && !inSingle) {
      escaped = true;
      continue;
    }

    if (c == "'" && !inDouble) {
      inSingle = !inSingle;
      continue;
    }

    if (c == '"' && !inSingle) {
      inDouble = !inDouble;
      continue;
    }

    if (c == ' ' && !inSingle && !inDouble) {
      if (current.isNotEmpty) {
        tokens.add(current.toString());
        current.clear();
      }
      continue;
    }

    current.write(c);
  }

  if (current.isNotEmpty) {
    tokens.add(current.toString());
  }

  return tokens;
}
