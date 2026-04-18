import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/theme/bolan_theme.dart';

// Lightweight path helpers — Bolan only runs on macOS / Linux where
// the separator is always `/`, so we don't need package:path.
String _basename(String path) {
  final i = path.lastIndexOf('/');
  return i < 0 ? path : path.substring(i + 1);
}

String _dirname(String path) {
  if (path == '/') return '/';
  final stripped = path.endsWith('/')
      ? path.substring(0, path.length - 1)
      : path;
  final i = stripped.lastIndexOf('/');
  if (i < 0) return '.';
  if (i == 0) return '/';
  return stripped.substring(0, i);
}

String _join(String a, String b) {
  if (a.endsWith('/')) return '$a$b';
  return '$a/$b';
}

/// Searchable directory navigator. Renders inside an anchored
/// popover. Lets the user navigate the filesystem starting from
/// [initialPath], filter by typing, and confirm a directory by
/// clicking "Use this directory" or pressing Enter on a folder.
///
/// On confirm, [onSelect] is called with the absolute path. The
/// caller is responsible for actually changing the session's cwd
/// (typically by writing `cd <path>\n` to the PTY).
class DirectoryPicker extends StatefulWidget {
  final String initialPath;
  final void Function(String path) onSelect;
  final VoidCallback onDismiss;

  const DirectoryPicker({
    super.key,
    required this.initialPath,
    required this.onSelect,
    required this.onDismiss,
  });

  @override
  State<DirectoryPicker> createState() => _DirectoryPickerState();
}

class _DirectoryPickerState extends State<DirectoryPicker> {
  late String _currentPath;
  String _filter = '';
  List<String> _entries = const [];
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _currentPath = widget.initialPath;
    _refresh();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _refresh() {
    try {
      final dir = Directory(_currentPath);
      final entries = <String>[];
      for (final entry in dir.listSync(followLinks: false)) {
        if (entry is Directory) {
          final name = _basename(entry.path);
          if (name.startsWith('.')) continue; // skip hidden by default
          entries.add(name);
        }
      }
      entries.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      setState(() {
        _entries = entries;
        _error = null;
      });
    } on FileSystemException catch (e) {
      setState(() {
        _entries = const [];
        _error = e.message;
      });
    }
  }

  List<String> get _filtered {
    if (_filter.isEmpty) return _entries;
    final q = _filter.toLowerCase();
    return _entries.where((e) => e.toLowerCase().contains(q)).toList();
  }

  void _navigateInto(String name) {
    setState(() {
      _currentPath = _join(_currentPath, name);
      _filter = '';
      _searchController.clear();
    });
    _refresh();
  }

  void _navigateUp() {
    final parent = _dirname(_currentPath);
    if (parent == _currentPath) return; // already at root
    setState(() {
      _currentPath = parent;
      _filter = '';
      _searchController.clear();
    });
    _refresh();
  }

  void _confirmCurrent() {
    widget.onSelect(_currentPath);
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header — current path
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Row(
            children: [
              Icon(Icons.folder_outlined,
                  size: 14, color: theme.dimForeground),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _abbreviate(_currentPath),
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
            ],
          ),
        ),

        // Search input
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.statusChipBg,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: theme.blockBorder, width: 1),
            ),
            child: Row(
              children: [
                Icon(Icons.search,
                    size: 14, color: theme.dimForeground),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    autofocus: true,
                    onChanged: (v) => setState(() => _filter = v),
                    onSubmitted: (_) {
                      final f = _filtered;
                      if (f.isNotEmpty) _navigateInto(f.first);
                    },
                    style: TextStyle(
                      color: theme.foreground,
                      fontFamily: theme.fontFamily,
                      fontSize: 12,
                      decoration: TextDecoration.none,
                    ),
                    cursorColor: theme.cursor,
                    decoration: InputDecoration(
                      isDense: true,
                      isCollapsed: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      hintText: 'Filter folders...',
                      hintStyle: TextStyle(
                        color: theme.dimForeground,
                        fontFamily: theme.fontFamily,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Entries
        Flexible(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 4),
            children: [
              if (_currentPath != '/')
                _buildRow(
                  theme,
                  icon: Icons.arrow_upward,
                  label: '..',
                  onTap: _navigateUp,
                ),
              if (_error != null)
                _buildEmpty(theme, _error!)
              else if (_filtered.isEmpty)
                _buildEmpty(theme, 'No subdirectories')
              else
                for (final name in _filtered)
                  _buildRow(
                    theme,
                    icon: Icons.folder_outlined,
                    label: name,
                    onTap: () => _navigateInto(name),
                  ),
            ],
          ),
        ),

        // Footer — confirm action
        Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: theme.blockBorder, width: 1),
            ),
          ),
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'esc to cancel',
                style: TextStyle(
                  color: theme.dimForeground,
                  fontFamily: theme.fontFamily,
                  fontSize: 11,
                  decoration: TextDecoration.none,
                ),
              ),
              GestureDetector(
                onTap: _confirmCurrent,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.cursor,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      'cd here',
                      style: TextStyle(
                        color: theme.background,
                        fontFamily: theme.fontFamily,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRow(
    BolonTheme theme, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Icon(icon, size: 14, color: theme.dimForeground),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.foreground,
                    fontFamily: theme.fontFamily,
                    fontSize: 12,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(BolonTheme theme, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: theme.dimForeground,
            fontFamily: theme.fontFamily,
            fontSize: 12,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }

  /// Replaces $HOME with `~` so the header reads naturally.
  String _abbreviate(String path) {
    final home = Platform.environment['HOME'];
    if (home != null && home.isNotEmpty && path.startsWith(home)) {
      return '~${path.substring(home.length)}';
    }
    return path;
  }
}
