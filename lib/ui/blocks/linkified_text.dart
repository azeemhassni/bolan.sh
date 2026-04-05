import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/terminal/url_detector.dart';

/// Post-processes a list of [TextSpan]s to make URLs clickable.
///
/// URLs are detected in each span's text. Matching segments get an underline
/// style and a tap recognizer that opens the URL on Cmd+click (macOS) or
/// Ctrl+click (Linux).
class LinkifiedText {
  LinkifiedText._();

  /// Transforms [spans] by splitting any span containing a URL into
  /// plain + linked segments. Returns a new list of spans.
  static List<InlineSpan> linkify(
    List<TextSpan> spans, {
    required Color linkColor,
  }) {
    final result = <InlineSpan>[];
    for (final span in spans) {
      final text = span.text;
      if (text == null || text.isEmpty) {
        result.add(span);
        continue;
      }

      final urls = UrlDetector.detectUrls(text);
      if (urls.isEmpty) {
        result.add(span);
        continue;
      }

      var lastEnd = 0;
      for (final url in urls) {
        // Text before this URL
        if (url.start > lastEnd) {
          result.add(TextSpan(
            text: text.substring(lastEnd, url.start),
            style: span.style,
          ));
        }
        // The URL itself
        result.add(TextSpan(
          text: url.text,
          style: span.style?.copyWith(
            color: linkColor,
            decoration: TextDecoration.underline,
            decorationColor: linkColor.withAlpha(120),
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => _openUrl(url.uri),
        ));
        lastEnd = url.end;
      }
      // Text after last URL
      if (lastEnd < text.length) {
        result.add(TextSpan(
          text: text.substring(lastEnd),
          style: span.style,
        ));
      }
    }
    return result;
  }

  static Future<void> _openUrl(String uri) async {
    // Only open if Cmd (macOS) or Ctrl (Linux) is held
    final modifierHeld = Platform.isMacOS
        ? HardwareKeyboard.instance.isMetaPressed
        : HardwareKeyboard.instance.isControlPressed;
    if (!modifierHeld) return;

    try {
      if (Platform.isMacOS) {
        await Process.run('open', [uri]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [uri]);
      }
    } on ProcessException {
      // Silently fail if open/xdg-open is unavailable
    }
  }
}
