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

  /// Called with the picked branch. The picker passes the full
  /// `_BranchEntry` info so the caller knows whether it's a local
  /// or remote branch and can issue the appropriate git command:
  ///
  ///   - local  → `git checkout <name>`
  ///   - remote → `git checkout -t <remote>/<branch>` (creates a
  ///              tracking local branch with the right short name)
  final void Function(BranchSelection selection) onSelect;
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

/// Result type passed to [BranchPicker.onSelect]. Tells the caller
/// exactly how to check the branch out without Bolan ever having to
/// guess which segment of a remote ref is the remote name vs the
/// branch name (that assumption is unsafe — branch names can contain
/// segments that coincidentally match a remote name).
///
/// For local branches, the caller runs `git checkout <localName>`.
/// For remote branches, the caller runs `git checkout -t <remoteRef>`
/// and lets git itself derive the tracking local name from the full
/// ref, which is the only reliable way to do it.
class BranchSelection {
  /// Full ref as it appears in `git branch` / `git branch -r` output
  /// (e.g. `main`, `origin/feature/foo`).
  final String ref;
  final bool isRemote;

  const BranchSelection.local(this.ref) : isRemote = false;
  const BranchSelection.remote(this.ref) : isRemote = true;
}

class _BranchEntry {
  /// The ref exactly as git reports it. For locals this is just the
  /// branch name; for remotes it's the full `<remote>/<branch>` ref.
  final String ref;
  final bool isRemote;

  const _BranchEntry.local(this.ref) : isRemote = false;
  const _BranchEntry.remote(this.ref) : isRemote = true;

  BranchSelection toSelection() =>
      isRemote ? BranchSelection.remote(ref) : BranchSelection.local(ref);
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
      // Query local and remote branches SEPARATELY so we can tell
      // them apart unambiguously. `git branch -a` produces output
      // identical in shape for `feature/foo` (local) and
      // `origin/feature/foo` (remote) — there's no way to parse the
      // distinction post-hoc once both are mixed.
      final localResult = await Process.run(
        'git',
        ['branch', '--format=%(refname:short)'],
        workingDirectory: widget.cwd,
      );
      if (localResult.exitCode != 0) {
        if (mounted) {
          setState(() {
            _error = (localResult.stderr as String).trim();
            _loading = false;
          });
        }
        return;
      }
      final remoteResult = await Process.run(
        'git',
        ['branch', '-r', '--format=%(refname:short)'],
        workingDirectory: widget.cwd,
      );

      final entries = <_BranchEntry>[];

      // Local branches.
      final locals = (localResult.stdout as String)
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty);
      for (final name in locals) {
        entries.add(_BranchEntry.local(name));
      }

      // Remote branches. We intentionally do NOT try to strip a
      // remote-name prefix to derive a "local name" — a segment of a
      // branch name can coincidentally match a remote name, and any
      // prefix-guessing heuristic will misfire on that. Instead we
      // keep the full ref as-is and let `git checkout -t <ref>` on
      // the caller side derive the correct tracking local name.
      if (remoteResult.exitCode == 0) {
        final remotes = (remoteResult.stdout as String)
            .split('\n')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty);
        for (final ref in remotes) {
          // Drop the synthetic `origin/HEAD` pointer.
          if (ref.endsWith('/HEAD')) continue;
          entries.add(_BranchEntry.remote(ref));
        }
      }

      // Local branches first, then remotes; alphabetical within each.
      entries.sort((a, b) {
        if (a.isRemote != b.isRemote) return a.isRemote ? 1 : -1;
        return a.ref.toLowerCase().compareTo(b.ref.toLowerCase());
      });

      if (mounted) {
        setState(() {
          _branches = entries;
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
        .where((b) => b.ref.toLowerCase().contains(q))
        .toList();
  }

  void _select(_BranchEntry entry) {
    widget.onSelect(entry.toSelection());
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
    final isCurrent = !entry.isRemote && entry.ref == widget.currentBranch;
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
                  entry.ref,
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
