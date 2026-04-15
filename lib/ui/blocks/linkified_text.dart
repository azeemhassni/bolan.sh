import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/terminal/path_detector.dart';
import '../../core/terminal/url_detector.dart';

/// Bounded LRU of resolved absolute paths → existence. Shared across
/// all link spans so the same path in repeated output doesn't re-stat.
/// A missing entry means "not yet checked".
final _pathExistsCache = <String, bool>{};
const _pathExistsCacheMax = 256;

void _rememberPathExists(String resolved, bool exists) {
  if (_pathExistsCache.containsKey(resolved)) {
    _pathExistsCache.remove(resolved);
  } else if (_pathExistsCache.length >= _pathExistsCacheMax) {
    _pathExistsCache.remove(_pathExistsCache.keys.first);
  }
  _pathExistsCache[resolved] = exists;
}

String _resolvePath(String path, String? cwd) {
  var resolved = path;
  final home = Platform.environment['HOME'] ?? '';
  if (resolved.startsWith('~/')) {
    resolved = '$home${resolved.substring(1)}';
  } else if (!resolved.startsWith('/') && cwd != null) {
    resolved = '$cwd/$resolved';
  }
  return resolved;
}

bool _modifierHeldNow() => Platform.isMacOS
    ? HardwareKeyboard.instance.isMetaPressed
    : HardwareKeyboard.instance.isControlPressed;

/// Post-processes a list of [TextSpan]s to make URLs and file paths clickable.
///
/// Matching segments stay visually indistinguishable from surrounding text
/// until the user hovers them with the platform modifier (Cmd on macOS,
/// Ctrl on Linux) held. Only then do they upgrade to underline + link
/// color and a pointer cursor. File paths additionally check existence
/// at that moment — stale references never reveal.
class LinkifiedText {
  LinkifiedText._();

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

      final links = <_Link>[];

      for (final url in UrlDetector.detectUrls(text)) {
        links.add(_Link(
          start: url.start,
          end: url.end,
          text: url.text,
          color: linkColor,
          kind: _LinkKind.url,
          target: url.uri,
        ));
      }

      for (final path in PathDetector.detectPaths(text)) {
        final overlaps = links.any(
            (l) => path.start < l.end && path.end > l.start);
        if (overlaps) continue;

        links.add(_Link(
          start: path.start,
          end: path.end,
          text: path.text,
          color: effectivePathColor,
          kind: _LinkKind.path,
          target: path.path,
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
        result.add(WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: _RevealLink(
            text: link.text,
            baseStyle: span.style,
            linkColor: link.color,
            kind: link.kind,
            target: link.target,
            cwd: cwd,
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
}

enum _LinkKind { url, path }

class _Link {
  final int start;
  final int end;
  final String text;
  final Color color;
  final _LinkKind kind;
  final String target;

  const _Link({
    required this.start,
    required this.end,
    required this.text,
    required this.color,
    required this.kind,
    required this.target,
  });
}

/// Renders a link candidate as plain text until hovered with the
/// platform modifier held. URLs always reveal; file paths reveal only
/// if the resolved path exists on disk at hover time.
class _RevealLink extends StatefulWidget {
  final String text;
  final TextStyle? baseStyle;
  final Color linkColor;
  final _LinkKind kind;
  final String target;
  final String? cwd;

  const _RevealLink({
    required this.text,
    required this.baseStyle,
    required this.linkColor,
    required this.kind,
    required this.target,
    required this.cwd,
  });

  @override
  State<_RevealLink> createState() => _RevealLinkState();
}

class _RevealLinkState extends State<_RevealLink> {
  bool _hovered = false;
  bool _modifierHeld = false;

  /// For path links, tri-state: null = not yet checked, true/false = known.
  /// URL links leave this null; [_canActivate] short-circuits to true.
  bool? _pathExists;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
    _modifierHeld = _modifierHeldNow();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    final held = _modifierHeldNow();
    if (held == _modifierHeld) return false;
    setState(() => _modifierHeld = held);
    if (held && _hovered) _ensurePathChecked();
    return false;
  }

  void _ensurePathChecked() {
    if (widget.kind != _LinkKind.path) return;
    if (_pathExists != null) return;
    final resolved = _resolvePath(widget.target, widget.cwd);
    final cached = _pathExistsCache[resolved];
    if (cached != null) {
      setState(() => _pathExists = cached);
      return;
    }
    final exists =
        File(resolved).existsSync() || Directory(resolved).existsSync();
    _rememberPathExists(resolved, exists);
    if (mounted) setState(() => _pathExists = exists);
  }

  bool get _canActivate =>
      widget.kind == _LinkKind.url || (_pathExists ?? false);

  bool get _revealed => _hovered && _modifierHeld && _canActivate;

  Future<void> _activate() async {
    if (!_modifierHeld || !_canActivate) return;
    try {
      if (widget.kind == _LinkKind.url) {
        await _open(widget.target);
      } else {
        final resolved = _resolvePath(widget.target, widget.cwd);
        // Re-check right before opening — the file may have vanished
        // since the hover stat. Cheap, same thread.
        if (!File(resolved).existsSync() &&
            !Directory(resolved).existsSync()) {
          _rememberPathExists(resolved, false);
          if (mounted) setState(() => _pathExists = false);
          return;
        }
        await _open(resolved);
      }
    } on ProcessException {
      // Silently fail — keep UI responsive.
    }
  }

  Future<void> _open(String target) async {
    if (Platform.isMacOS) {
      await Process.run('open', [target]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [target]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _revealed
        ? widget.baseStyle?.copyWith(
            color: widget.linkColor,
            decoration: TextDecoration.underline,
            decorationColor: widget.linkColor.withAlpha(120),
          )
        : widget.baseStyle;
    final cursor =
        _revealed ? SystemMouseCursors.click : MouseCursor.defer;

    return MouseRegion(
      cursor: cursor,
      onEnter: (_) {
        setState(() => _hovered = true);
        if (_modifierHeld) _ensurePathChecked();
      },
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _activate,
        child: Text.rich(
          TextSpan(text: widget.text, style: style),
        ),
      ),
    );
  }
}
