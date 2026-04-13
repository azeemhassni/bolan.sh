import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/terminal/path_detector.dart';
import '../../core/terminal/url_detector.dart';

/// Post-processes a list of [TextSpan]s to make URLs and file paths clickable.
///
/// URLs and filesystem paths are detected in each span's text. Matching
/// segments get an underline style and a tap recognizer that opens the
/// target on Cmd+click (macOS) or Ctrl+click (Linux).
class LinkifiedText {
  LinkifiedText._();

  /// Transforms [spans] by splitting any span containing a URL or file
  /// path into plain + linked segments. Returns a new list of spans.
  ///
  /// [cwd] is used to resolve relative paths. If null, relative paths
  /// are still detected but may not open correctly.
  static List<InlineSpan> linkify(
    List<TextSpan> spans, {
    required Color linkColor,
    Color? pathColor,
    String? cwd,
  }) {
    final effectivePathColor = pathColor ?? linkColor;
    final result = <InlineSpan>[];
    for (final span in spans) {
      final text = span.text;
      if (text == null || text.isEmpty) {
        result.add(span);
        continue;
      }

      // Collect all linkable ranges (URLs + paths), sorted by position.
      final links = <_Link>[];

      for (final url in UrlDetector.detectUrls(text)) {
        links.add(_Link(
          start: url.start,
          end: url.end,
          text: url.text,
          color: linkColor,
          onTap: () => _openUrl(url.uri),
        ));
      }

      for (final path in PathDetector.detectPaths(text)) {
        // Skip paths that overlap with an already-detected URL
        final overlaps = links.any(
            (l) => path.start < l.end && path.end > l.start);
        if (overlaps) continue;

        links.add(_Link(
          start: path.start,
          end: path.end,
          text: path.text,
          color: effectivePathColor,
          onTap: () => _openPath(path.path, cwd: cwd),
        ));
      }

      if (links.isEmpty) {
        result.add(span);
        continue;
      }

      links.sort((a, b) => a.start.compareTo(b.start));

      var lastEnd = 0;
      for (final link in links) {
        if (link.start > lastEnd) {
          result.add(TextSpan(
            text: text.substring(lastEnd, link.start),
            style: span.style,
          ));
        }
        final linkStyle = span.style?.copyWith(
          color: link.color,
          decoration: TextDecoration.underline,
          decorationColor: link.color.withAlpha(120),
        );
        result.add(WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Tooltip(
            message: Platform.isMacOS
                ? '\u2318+Click to open'
                : 'Ctrl+Click to open',
            waitDuration: const Duration(milliseconds: 400),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: link.onTap,
                child: Text(link.text, style: linkStyle),
              ),
            ),
          ),
        ));
        lastEnd = link.end;
      }
      if (lastEnd < text.length) {
        result.add(TextSpan(
          text: text.substring(lastEnd),
          style: span.style,
        ));
      }
    }
    return result;
  }

  static bool get _modifierHeld => Platform.isMacOS
      ? HardwareKeyboard.instance.isMetaPressed
      : HardwareKeyboard.instance.isControlPressed;

  static Future<void> _openUrl(String uri) async {
    if (!_modifierHeld) return;
    try {
      if (Platform.isMacOS) {
        await Process.run('open', [uri]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [uri]);
      }
    } on ProcessException {
      // Silently fail
    }
  }

  static Future<void> _openPath(String path, {String? cwd}) async {
    if (!_modifierHeld) return;

    // Resolve the path
    var resolved = path;
    final home = Platform.environment['HOME'] ?? '';
    if (resolved.startsWith('~/')) {
      resolved = '$home${resolved.substring(1)}';
    } else if (!resolved.startsWith('/') && cwd != null) {
      resolved = '$cwd/$resolved';
    }

    // Verify the path exists before opening
    if (!File(resolved).existsSync() &&
        !Directory(resolved).existsSync()) {
      return;
    }

    try {
      if (Platform.isMacOS) {
        await Process.run('open', [resolved]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [resolved]);
      }
    } on ProcessException {
      // Silently fail
    }
  }
}

class _Link {
  final int start;
  final int end;
  final String text;
  final Color color;
  final VoidCallback onTap;

  const _Link({
    required this.start,
    required this.end,
    required this.text,
    required this.color,
    required this.onTap,
  });
}
