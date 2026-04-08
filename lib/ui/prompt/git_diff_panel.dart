import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/theme/bolan_theme.dart';

/// Panel showing git diff with colored additions/deletions, a sidebar
/// of changed files, and old/new line numbers per line.
///
/// Mounted as an anchored overlay by the prompt area; the host overlay
/// owns barrier dismiss and Escape handling.
class GitDiffPanel extends StatefulWidget {
  final String cwd;
  final VoidCallback onClose;

  const GitDiffPanel({
    super.key,
    required this.cwd,
    required this.onClose,
  });

  @override
  State<GitDiffPanel> createState() => _GitDiffPanelState();
}

class _GitDiffPanelState extends State<GitDiffPanel> {
  List<_FileDiff>? _files;
  bool _loading = true;
  String? _error;

  /// Currently selected file path (matches [_FileDiff.path]). Null
  /// means "All files" — show every file's diff stacked.
  String? _selectedPath;

  /// True for one frame between clicking a sidebar entry and the
  /// new diff content actually rendering. Lets us show a loader on
  /// large diffs so the click feels responsive instead of laggy.
  bool _switching = false;

  /// Files with more lines than this trigger the inter-switch loader.
  /// Smaller files swap instantly without the visual blip.
  static const int _largeDiffThreshold = 500;

  @override
  void initState() {
    super.initState();
    _loadDiff();
  }

  /// Switches to a different file in the sidebar. For large diffs,
  /// shows a loader for one frame before kicking off the heavy
  /// rebuild on the next frame, so the click feels instant.
  void _selectFile(String? path) {
    if (path == _selectedPath) return;
    final files = _files;
    if (files == null) return;

    final targetLines = path == null
        ? files.fold<int>(0, (sum, f) => sum + f.lines.length)
        : files
            .firstWhere((f) => f.path == path, orElse: () => files.first)
            .lines
            .length;

    if (targetLines > _largeDiffThreshold) {
      setState(() => _switching = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _selectedPath = path;
          _switching = false;
        });
      });
    } else {
      setState(() => _selectedPath = path);
    }
  }

  Future<void> _loadDiff() async {
    try {
      final result = await Process.run(
        'git',
        ['diff', '--patch'],
        workingDirectory: widget.cwd,
      );
      if (!mounted) return;
      final raw = (result.stdout as String);
      final files = _parseDiff(raw);
      setState(() {
        _files = files;
        _loading = false;
        _selectedPath = files.isNotEmpty ? files.first.path : null;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);
    final media = MediaQuery.of(context).size;

    return Container(
      constraints: BoxConstraints(
        maxWidth: media.width * 0.9,
        maxHeight: media.height * 0.8,
      ),
      width: media.width * 0.9,
      decoration: BoxDecoration(
        color: theme.blockBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.blockBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(120),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(theme),
          Divider(height: 1, thickness: 1, color: theme.blockBorder),
          Flexible(child: _buildBody(theme)),
        ],
      ),
    );
  }

  Widget _buildHeader(BolonTheme theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.difference_outlined, size: 16, color: theme.foreground),
          const SizedBox(width: 8),
          Text(
            'Changes',
            style: TextStyle(
              color: theme.foreground,
              fontFamily: theme.fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
            ),
          ),
          if (_files != null && _files!.isNotEmpty) ...[
            const SizedBox(width: 10),
            Text(
              '${_files!.length} file${_files!.length == 1 ? '' : 's'}',
              style: TextStyle(
                color: theme.dimForeground,
                fontFamily: theme.fontFamily,
                fontSize: 12,
                decoration: TextDecoration.none,
              ),
            ),
          ],
          const Spacer(),
          Text(
            'esc to close',
            style: TextStyle(
              color: theme.dimForeground,
              fontFamily: theme.fontFamily,
              fontSize: 11,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: widget.onClose,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Icon(Icons.close, size: 16, color: theme.dimForeground),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BolonTheme theme) {
    if (_loading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: theme.cursor,
            ),
          ),
        ),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Failed to load diff: $_error',
          style: TextStyle(
            color: theme.exitFailureFg,
            fontFamily: theme.fontFamily,
            fontSize: 13,
            decoration: TextDecoration.none,
          ),
        ),
      );
    }
    final files = _files;
    if (files == null || files.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No changes',
          style: TextStyle(
            color: theme.dimForeground,
            fontFamily: theme.fontFamily,
            fontSize: 13,
            decoration: TextDecoration.none,
          ),
        ),
      );
    }

    final visibleFiles = _selectedPath == null
        ? files
        : files.where((f) => f.path == _selectedPath).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 240,
          child: _buildSidebar(theme, files),
        ),
        VerticalDivider(
          width: 1,
          thickness: 1,
          color: theme.blockBorder,
        ),
        Expanded(child: _buildDiffContent(theme, visibleFiles)),
      ],
    );
  }

  Widget _buildSidebar(BolonTheme theme, List<_FileDiff> files) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 6),
      children: [
        _SidebarRow(
          path: 'All files',
          icon: Icons.folder_outlined,
          adds: files.fold(0, (sum, f) => sum + f.additions),
          dels: files.fold(0, (sum, f) => sum + f.deletions),
          isSelected: _selectedPath == null,
          theme: theme,
          onTap: () => _selectFile(null),
        ),
        for (final file in files)
          _SidebarRow(
            path: file.path,
            icon: file.isBinary
                ? Icons.insert_drive_file_outlined
                : Icons.description_outlined,
            adds: file.additions,
            dels: file.deletions,
            isSelected: _selectedPath == file.path,
            theme: theme,
            onTap: () => _selectFile(file.path),
          ),
      ],
    );
  }

  Widget _buildDiffContent(BolonTheme theme, List<_FileDiff> visibleFiles) {
    // While switching between large files, render a loader for one
    // frame so the click feels instant. The next frame swaps the
    // loader for the actual content.
    if (_switching) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: theme.cursor,
            ),
          ),
        ),
      );
    }
    // SelectionArea lets the user drag-select across all the plain
    // Text widgets inside, without each line needing its own
    // SelectableText (which is heavyweight and made tab switching
    // visibly slow on large diffs).
    return SelectionArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final file in visibleFiles)
              _FileDiffView(file: file, theme: theme),
          ],
        ),
      ),
    );
  }
}

// ─── Diff parser ────────────────────────────────────────────────────

enum _LineKind { context, added, removed, hunkHeader, fileHeader, info }

class _DiffLine {
  final _LineKind kind;
  final int? oldLine;
  final int? newLine;
  final String text;

  const _DiffLine({
    required this.kind,
    this.oldLine,
    this.newLine,
    required this.text,
  });
}

class _FileDiff {
  final String path;
  final List<_DiffLine> lines;
  final int additions;
  final int deletions;
  final bool isBinary;

  const _FileDiff({
    required this.path,
    required this.lines,
    required this.additions,
    required this.deletions,
    this.isBinary = false,
  });
}

/// Parses raw `git diff --patch` output into a list of [_FileDiff].
///
/// Tracks old/new line numbers as it walks each hunk so the renderer
/// can show gutter columns. Skips meta lines like `index abc..def`.
/// Binary files are marked as such with no body.
List<_FileDiff> _parseDiff(String raw) {
  final files = <_FileDiff>[];

  String? currentPath;
  var currentLines = <_DiffLine>[];
  var adds = 0;
  var dels = 0;
  var isBinary = false;

  int oldLine = 0;
  int newLine = 0;

  void flush() {
    if (currentPath == null) return;
    files.add(_FileDiff(
      path: currentPath!,
      lines: List.of(currentLines),
      additions: adds,
      deletions: dels,
      isBinary: isBinary,
    ));
    currentPath = null;
    currentLines = <_DiffLine>[];
    adds = 0;
    dels = 0;
    isBinary = false;
    oldLine = 0;
    newLine = 0;
  }

  for (final line in raw.split('\n')) {
    if (line.startsWith('diff --git ')) {
      flush();
      // `diff --git a/<old> b/<new>` — extract the new path.
      final parts = line.substring('diff --git '.length).split(' ');
      if (parts.length == 2 && parts[1].startsWith('b/')) {
        currentPath = parts[1].substring(2);
      } else {
        currentPath = '(unknown)';
      }
      continue;
    }
    if (currentPath == null) continue;

    if (line.startsWith('Binary files ')) {
      isBinary = true;
      currentLines.add(_DiffLine(kind: _LineKind.info, text: line));
      continue;
    }
    if (line.startsWith('index ') ||
        line.startsWith('--- ') ||
        line.startsWith('+++ ') ||
        line.startsWith('new file mode') ||
        line.startsWith('deleted file mode') ||
        line.startsWith('similarity index') ||
        line.startsWith('rename ')) {
      // Drop noisy meta lines from the rendered output.
      continue;
    }
    if (line.startsWith('@@')) {
      final match = RegExp(r'^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@')
          .firstMatch(line);
      if (match != null) {
        oldLine = int.parse(match.group(1)!);
        newLine = int.parse(match.group(2)!);
      }
      currentLines.add(_DiffLine(kind: _LineKind.hunkHeader, text: line));
      continue;
    }
    if (line.startsWith('+')) {
      currentLines.add(_DiffLine(
        kind: _LineKind.added,
        newLine: newLine,
        text: line.substring(1),
      ));
      newLine++;
      adds++;
      continue;
    }
    if (line.startsWith('-')) {
      currentLines.add(_DiffLine(
        kind: _LineKind.removed,
        oldLine: oldLine,
        text: line.substring(1),
      ));
      oldLine++;
      dels++;
      continue;
    }
    if (line.startsWith(' ')) {
      currentLines.add(_DiffLine(
        kind: _LineKind.context,
        oldLine: oldLine,
        newLine: newLine,
        text: line.substring(1),
      ));
      oldLine++;
      newLine++;
      continue;
    }
    if (line.startsWith(r'\ No newline at end of file')) {
      // Skip — visual noise.
      continue;
    }
    // Anything else (blank line between hunks, etc.) — preserve as info.
    if (line.isNotEmpty) {
      currentLines.add(_DiffLine(kind: _LineKind.info, text: line));
    }
  }

  flush();
  return files;
}

// ─── Sidebar row ───────────────────────────────────────────────────

class _SidebarRow extends StatefulWidget {
  final String path;
  final IconData icon;
  final int adds;
  final int dels;
  final bool isSelected;
  final BolonTheme theme;
  final VoidCallback onTap;

  const _SidebarRow({
    required this.path,
    required this.icon,
    required this.adds,
    required this.dels,
    required this.isSelected,
    required this.theme,
    required this.onTap,
  });

  @override
  State<_SidebarRow> createState() => _SidebarRowState();
}

class _SidebarRowState extends State<_SidebarRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final bg = widget.isSelected
        ? t.statusChipBg
        : (_hovered ? t.statusChipBg.withAlpha(120) : Colors.transparent);
    final fg = widget.isSelected ? t.foreground : t.dimForeground;

    return GestureDetector(
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Container(
          color: bg,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              Icon(widget.icon, size: 13, color: fg),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.path,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    color: fg,
                    fontFamily: t.fontFamily,
                    fontSize: 12,
                    fontWeight: widget.isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              if (widget.adds > 0) ...[
                const SizedBox(width: 6),
                Text(
                  '+${widget.adds}',
                  style: TextStyle(
                    color: t.exitSuccessFg,
                    fontFamily: t.fontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
              if (widget.dels > 0) ...[
                const SizedBox(width: 4),
                Text(
                  '-${widget.dels}',
                  style: TextStyle(
                    color: t.exitFailureFg,
                    fontFamily: t.fontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── File diff view ───────────────────────────────────────────────

class _FileDiffView extends StatelessWidget {
  final _FileDiff file;
  final BolonTheme theme;

  static const double _diffFontSize = 14;
  static const double _gutterFontSize = 12;
  static const double _gutterWidth = 44;
  static const double _lineHeight = 1.4;

  const _FileDiffView({required this.file, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // File header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: theme.statusChipBg,
            child: Row(
              children: [
                Icon(Icons.description_outlined,
                    size: 13, color: theme.dimForeground),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    file.path,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.foreground,
                      fontFamily: theme.fontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                Text(
                  '+${file.additions}',
                  style: TextStyle(
                    color: theme.exitSuccessFg,
                    fontFamily: theme.fontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '-${file.deletions}',
                  style: TextStyle(
                    color: theme.exitFailureFg,
                    fontFamily: theme.fontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),

          // Body — line-by-line
          if (file.isBinary)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Binary file — diff not shown',
                style: TextStyle(
                  color: theme.dimForeground,
                  fontFamily: theme.fontFamily,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  decoration: TextDecoration.none,
                ),
              ),
            )
          else
            for (final line in file.lines) _buildLine(line),
        ],
      ),
    );
  }

  Widget _buildLine(_DiffLine line) {
    Color rowBg;
    Color contentColor;
    String prefix;

    switch (line.kind) {
      case _LineKind.added:
        rowBg = theme.exitSuccessFg.withAlpha(28);
        contentColor = theme.exitSuccessFg;
        prefix = '+';
        break;
      case _LineKind.removed:
        rowBg = theme.exitFailureFg.withAlpha(28);
        contentColor = theme.exitFailureFg;
        prefix = '-';
        break;
      case _LineKind.context:
        rowBg = Colors.transparent;
        contentColor = theme.foreground;
        prefix = ' ';
        break;
      case _LineKind.hunkHeader:
        rowBg = theme.ansiCyan.withAlpha(20);
        contentColor = theme.ansiCyan;
        prefix = ' ';
        break;
      case _LineKind.fileHeader:
      case _LineKind.info:
        rowBg = Colors.transparent;
        contentColor = theme.dimForeground;
        prefix = ' ';
        break;
    }

    return Container(
      color: rowBg,
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Old line number gutter
          SizedBox(
            width: _gutterWidth,
            child: Text(
              line.oldLine?.toString() ?? '',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: theme.dimForeground.withAlpha(180),
                fontFamily: theme.fontFamily,
                fontSize: _gutterFontSize,
                height: _lineHeight,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // New line number gutter
          SizedBox(
            width: _gutterWidth,
            child: Text(
              line.newLine?.toString() ?? '',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: theme.dimForeground.withAlpha(180),
                fontFamily: theme.fontFamily,
                fontSize: _gutterFontSize,
                height: _lineHeight,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Content. Plain Text (not SelectableText) for speed —
          // the parent diff content is wrapped in a SelectionArea so
          // selection still works across lines.
          Expanded(
            child: Text(
              '$prefix${line.text}',
              style: TextStyle(
                color: contentColor,
                fontFamily: theme.fontFamily,
                fontSize: _diffFontSize,
                height: _lineHeight,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
