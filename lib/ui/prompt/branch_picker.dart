import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/theme/bolan_theme.dart';

/// Searchable git branch picker. Renders inside an anchored popover.
/// Lists local branches first, then remote-tracking branches, with a
/// type-to-filter input. On select, [onSelect] is called with the
/// branch name; the caller is responsible for actually checking it
/// out (typically by writing `git checkout <branch>\n` to the PTY).
class BranchPicker extends StatefulWidget {
  /// Working directory to run git in.
  final String cwd;

  /// Currently checked-out branch, used to highlight the active row.
  final String currentBranch;

  final void Function(String branch) onSelect;
  final VoidCallback onDismiss;

  const BranchPicker({
    super.key,
    required this.cwd,
    required this.currentBranch,
    required this.onSelect,
    required this.onDismiss,
  });

  @override
  State<BranchPicker> createState() => _BranchPickerState();
}

class _BranchEntry {
  final String displayName;
  final String checkoutName;
  final bool isRemote;
  const _BranchEntry({
    required this.displayName,
    required this.checkoutName,
    required this.isRemote,
  });
}

class _BranchPickerState extends State<BranchPicker> {
  List<_BranchEntry> _branches = const [];
  String? _error;
  bool _loading = true;
  String _filter = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadBranches() async {
    try {
      final result = await Process.run(
        'git',
        ['branch', '-a', '--format=%(refname:short)'],
        workingDirectory: widget.cwd,
      );
      if (result.exitCode != 0) {
        if (mounted) {
          setState(() {
            _error = (result.stderr as String).trim();
            _loading = false;
          });
        }
        return;
      }
      final lines = (result.stdout as String)
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty);

      final entries = <_BranchEntry>[];
      for (final line in lines) {
        // `git branch -a` includes a synthetic "origin/HEAD" pointer
        // that isn't actually checkout-able. Drop it.
        if (line.endsWith('/HEAD')) continue;
        final isRemote =
            line.contains('/') && !line.startsWith('refs/');
        // For remotes, the checkout name is the part after the first
        // `/` (e.g. `origin/main` → `main`). Local checkout of a
        // remote-tracking branch creates a tracking local branch.
        final checkoutName =
            isRemote ? line.substring(line.indexOf('/') + 1) : line;
        entries.add(_BranchEntry(
          displayName: line,
          checkoutName: checkoutName,
          isRemote: isRemote,
        ));
      }

      // Local branches first, then remotes; alphabetical within each
      // group. Drop remote duplicates of branches that already exist
      // locally so the list isn't noisy.
      final localNames =
          entries.where((e) => !e.isRemote).map((e) => e.displayName).toSet();
      final filtered = entries.where((e) {
        if (e.isRemote && localNames.contains(e.checkoutName)) return false;
        return true;
      }).toList()
        ..sort((a, b) {
          if (a.isRemote != b.isRemote) return a.isRemote ? 1 : -1;
          return a.displayName.toLowerCase()
              .compareTo(b.displayName.toLowerCase());
        });

      if (mounted) {
        setState(() {
          _branches = filtered;
          _loading = false;
        });
      }
    } on ProcessException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  List<_BranchEntry> get _filtered {
    if (_filter.isEmpty) return _branches;
    final q = _filter.toLowerCase();
    return _branches
        .where((b) => b.displayName.toLowerCase().contains(q))
        .toList();
  }

  void _select(_BranchEntry entry) {
    widget.onSelect(entry.checkoutName);
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search input
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
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
                      if (f.isNotEmpty) _select(f.first);
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
                      hintText: 'Filter branches...',
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

        // List
        Flexible(
          child: _loading
              ? _buildEmpty(theme, 'Loading branches...')
              : _error != null
                  ? _buildEmpty(theme, _error!)
                  : _filtered.isEmpty
                      ? _buildEmpty(theme, 'No matching branches')
                      : ListView(
                          padding:
                              const EdgeInsets.symmetric(vertical: 4),
                          children: [
                            for (final entry in _filtered)
                              _buildRow(theme, entry),
                          ],
                        ),
        ),

        // Footer
        Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: theme.blockBorder, width: 1),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            'esc to cancel  ·  enter to checkout',
            style: TextStyle(
              color: theme.dimForeground,
              fontFamily: theme.fontFamily,
              fontSize: 11,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRow(BolonTheme theme, _BranchEntry entry) {
    final isCurrent = entry.checkoutName == widget.currentBranch;
    return GestureDetector(
      onTap: () => _select(entry),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Icon(
                isCurrent
                    ? Icons.check
                    : (entry.isRemote
                        ? Icons.cloud_outlined
                        : Icons.call_split),
                size: 14,
                color: isCurrent ? theme.cursor : theme.dimForeground,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.displayName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isCurrent ? theme.cursor : theme.foreground,
                    fontFamily: theme.fontFamily,
                    fontSize: 12,
                    fontWeight: isCurrent
                        ? FontWeight.w600
                        : FontWeight.normal,
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
}
