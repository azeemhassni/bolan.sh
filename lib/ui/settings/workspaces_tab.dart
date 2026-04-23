import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/bolan_theme.dart';
import '../../core/workspace/workspace.dart';
import '../../providers/workspace_provider.dart';
import '../shared/bolan_button.dart';
import '../shared/bolan_components.dart';
import '../workspace/workspace_icon.dart';
import '../workspace/workspace_icon_picker.dart';
import 'color_picker.dart';

/// Shared workspace accent palette. Extra colors can be picked via the
/// "Custom color" tile in [_WorkspaceColorPicker].
const kWorkspacePalette = [
  '#7AA2F7', '#F7768E', '#9ECE6A', '#E0AF68',
  '#BB9AF7', '#7DCFFF', '#FF9E64', '#73DACA',
];

/// CRUD UI for workspaces. Renders a list of workspaces, each row
/// expandable into an inline editor. New workspaces seed their config
/// from the currently-active one (see `WorkspaceRegistry.add`).
class WorkspacesTab extends ConsumerStatefulWidget {
  const WorkspacesTab({super.key});

  @override
  ConsumerState<WorkspacesTab> createState() => _WorkspacesTabState();
}

class _WorkspacesTabState extends ConsumerState<WorkspacesTab> {
  String? _expandedId;
  bool _adding = false;

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);
    final registry = ref.watch(workspaceRegistryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final w in registry.workspaces)
          _WorkspaceRow(
            workspace: w,
            isActive: w.id == registry.activeId,
            isExpanded: _expandedId == w.id,
            canDelete: registry.workspaces.length > 1 && w.id != registry.activeId,
            theme: theme,
            onToggleExpand: () => setState(
                () => _expandedId = _expandedId == w.id ? null : w.id),
            onSave: (updated) async {
              await registry.update(updated);
              setState(() => _expandedId = null);
            },
            onDelete: () async {
              await registry.delete(w.id);
              setState(() => _expandedId = null);
            },
            onSwitch: () async {
              final switcher = ref.read(switchWorkspaceActionProvider);
              await switcher(w.id);
            },
          ),
        const SizedBox(height: 12),
        if (_adding)
          _NewWorkspaceForm(
            theme: theme,
            existingIds: registry.workspaces.map((w) => w.id).toSet(),
            palette: kWorkspacePalette,
            onCancel: () => setState(() => _adding = false),
            onCreate: (w) async {
              await registry.add(w, seedFromId: registry.activeId);
              setState(() {
                _adding = false;
                _expandedId = w.id;
              });
            },
          )
        else
          Align(
            alignment: Alignment.centerLeft,
            child: BolanButton.ghost(
              label: 'New Workspace',
              icon: Icons.add,
              onTap: () => setState(() => _adding = true),
            ),
          ),
      ],
    );
  }
}

class _WorkspaceRow extends StatelessWidget {
  final Workspace workspace;
  final bool isActive;
  final bool isExpanded;
  final bool canDelete;
  final BolonTheme theme;
  final VoidCallback onToggleExpand;
  final ValueChanged<Workspace> onSave;
  final VoidCallback onDelete;
  final VoidCallback onSwitch;

  const _WorkspaceRow({
    required this.workspace,
    required this.isActive,
    required this.isExpanded,
    required this.canDelete,
    required this.theme,
    required this.onToggleExpand,
    required this.onSave,
    required this.onDelete,
    required this.onSwitch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.blockBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.blockBorder, width: 1),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggleExpand,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _rowAvatar(workspace, theme),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          workspace.name,
                          style: TextStyle(
                            color: theme.foreground,
                            fontFamily: theme.fontFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          workspace.id,
                          style: TextStyle(
                            color: theme.dimForeground,
                            fontFamily: theme.fontFamily,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: workspace.accentColor.withAlpha(60),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'active',
                        style: TextStyle(
                          color: workspace.accentColor,
                          fontFamily: theme.fontFamily,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else if (workspace.enabled)
                    BolanButton.ghost(
                      label: 'Switch',
                      onTap: onSwitch,
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.statusChipBg,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'disabled',
                        style: TextStyle(
                          color: theme.dimForeground,
                          fontFamily: theme.fontFamily,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  Icon(
                    isExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 18,
                    color: theme.dimForeground,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            _WorkspaceEditor(
              workspace: workspace,
              isActive: isActive,
              theme: theme,
              canDelete: canDelete,
              onSave: onSave,
              onDelete: onDelete,
            ),
        ],
      ),
    );
  }

  Widget _rowAvatar(Workspace workspace, BolonTheme theme) =>
      _WorkspaceAvatarTile(workspace: workspace, theme: theme, size: 28);
}

/// Squircle avatar showing the workspace's current look (icon + color).
/// Shared by the collapsed row, the inline preview in the editor, and the
/// anchor button that opens the icon popover.
///
/// SVG icons render on a neutral background so brand colors aren't
/// muddied by the accent fill; Material icons and the initial-letter
/// fallback render white-on-accent.
class _WorkspaceAvatarTile extends StatelessWidget {
  final Workspace workspace;
  final BolonTheme theme;
  final double size;

  const _WorkspaceAvatarTile({
    required this.workspace,
    required this.theme,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    final isSvg = workspace.icon == 'svg';
    final bg = isSvg ? theme.statusChipBg : workspace.accentColor;
    final inner = size * (18 / 28);
    final fontSize = size * (13 / 28);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(size * (6 / 28)),
      ),
      child: Center(
        child: WorkspaceIcon(
          workspace: workspace,
          size: inner,
          tintColor: Colors.white,
          fallback: Text(
            workspace.initial,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkspaceEditor extends StatefulWidget {
  final Workspace workspace;
  final BolonTheme theme;
  final bool isActive;
  final bool canDelete;
  final ValueChanged<Workspace> onSave;
  final VoidCallback onDelete;

  const _WorkspaceEditor({
    required this.workspace,
    required this.isActive,
    required this.theme,
    required this.canDelete,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<_WorkspaceEditor> createState() => _WorkspaceEditorState();
}

class _WorkspaceEditorState extends State<_WorkspaceEditor> {
  late String _name;
  late String _color;
  late String _icon;

  final _iconAnchorKey = GlobalKey();
  final _colorAnchorKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _name = widget.workspace.name;
    _color = widget.workspace.color;
    _icon = widget.workspace.icon;
  }

  /// The draft workspace — what the collapsed row will look like after
  /// Save. Used by the inline preview tile and the icon-anchor avatar.
  Workspace get _draft => widget.workspace.copyWith(
        name: _name.trim().isEmpty ? widget.workspace.name : _name.trim(),
        color: _color,
        icon: _icon,
      );

  Color _parseHex(String hex) {
    final s = hex.replaceFirst('#', '');
    final v = int.tryParse(s, radix: 16) ?? 0x888888;
    return Color(0xFF000000 | v);
  }

  void _save() {
    widget.onSave(widget.workspace.copyWith(
      name: _name.trim().isEmpty ? widget.workspace.name : _name.trim(),
      color: _color,
      icon: _icon,
    ));
  }

  Future<void> _openIconPopover() async {
    final t = widget.theme;
    await _showAnchoredPopover(
      context: context,
      anchorKey: _iconAnchorKey,
      theme: t,
      width: 308,
      builder: (popCtx) => WorkspaceIconPicker(
        currentIcon: _icon,
        accentColor: _parseHex(_color),
        theme: t,
        workspaceId: widget.workspace.id,
        onChanged: (v) {
          setState(() => _icon = v);
          Navigator.of(popCtx).pop();
        },
      ),
    );
  }

  Future<void> _openColorPopover() async {
    final t = widget.theme;
    await _showAnchoredPopover(
      context: context,
      anchorKey: _colorAnchorKey,
      theme: t,
      width: 240,
      builder: (popCtx) => _WorkspaceColorPicker(
        value: _color,
        theme: t,
        onChanged: (v) {
          setState(() => _color = v);
          Navigator.of(popCtx).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: t.blockBorder, height: 12),
          const SizedBox(height: 4),

          // ── Identity ──
          BolanTextField(
            value: _name,
            hint: 'Name',
            onChanged: (v) => setState(() => _name = v),
          ),
          const SizedBox(height: 12),

          // ── Appearance: icon anchor + color anchor + live preview ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _IconAnchor(
                key: _iconAnchorKey,
                workspace: _draft,
                theme: t,
                onTap: _openIconPopover,
              ),
              const SizedBox(width: 6),
              _ColorAnchor(
                key: _colorAnchorKey,
                colorHex: _color,
                theme: t,
                onTap: _openColorPopover,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _WorkspaceRowPreview(
                  workspace: _draft,
                  theme: t,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Quiet footnote ──
          const BolanText.caption(
            'Git identity, environment variables, and secrets for this '
            'workspace live under Settings → Environment.',
          ),
          const SizedBox(height: 12),

          // ── Footer: Save | Enabled switch (demoted) | Delete ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              BolanButton.primary(
                label: 'Save',
                onTap: _save,
              ),
              const SizedBox(width: 12),
              _InlineEnabledSwitch(
                value: widget.workspace.enabled,
                theme: t,
                onChanged: widget.isActive
                    ? null
                    : (v) => widget.onSave(
                        widget.workspace.copyWith(enabled: v)),
              ),
              const Spacer(),
              if (widget.canDelete)
                BolanButton.danger(
                  label: 'Delete',
                  onTap: () => _confirmDelete(context),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final t = widget.theme;
    showDialog<void>(
      context: context,
      builder: (ctx) => BolonThemeProvider(
        theme: t,
        child: AlertDialog(
          backgroundColor: t.blockBackground,
          title: Text('Delete "${widget.workspace.name}"?',
              style: TextStyle(color: t.foreground, fontFamily: t.fontFamily)),
          content: Text(
            'This permanently removes the workspace, its config, '
            'history, snippets, and saved tab layout. This cannot be undone.',
            style: TextStyle(
                color: t.dimForeground, fontFamily: t.fontFamily, fontSize: 12),
          ),
          actions: [
            BolanButton(
              label: 'Cancel',
              onTap: () => Navigator.of(ctx).pop(),
            ),
            BolanButton.danger(
              label: 'Delete',
            onTap: () {
              Navigator.of(ctx).pop();
              widget.onDelete();
            },
          ),
        ],
        ),
      ),
    );
  }

}

class _NewWorkspaceForm extends StatefulWidget {
  final BolonTheme theme;
  final Set<String> existingIds;
  final List<String> palette;
  final VoidCallback onCancel;
  final ValueChanged<Workspace> onCreate;

  const _NewWorkspaceForm({
    required this.theme,
    required this.existingIds,
    required this.palette,
    required this.onCancel,
    required this.onCreate,
  });

  @override
  State<_NewWorkspaceForm> createState() => _NewWorkspaceFormState();
}

class _NewWorkspaceFormState extends State<_NewWorkspaceForm> {
  String _name = '';
  late String _color;
  String _icon = '';
  String? _error;

  final _iconAnchorKey = GlobalKey();
  final _colorAnchorKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _color = widget.palette.first;
  }

  Color _parseHex(String hex) {
    final s = hex.replaceFirst('#', '');
    final v = int.tryParse(s, radix: 16) ?? 0x888888;
    return Color(0xFF000000 | v);
  }

  /// Derives a stable id from the name: lowercase, kebab-case, alnum
  /// only. Suffixes a counter if it collides with an existing id.
  String _deriveId(String name) {
    var base = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (base.isEmpty) base = 'workspace';
    var id = base;
    var n = 2;
    while (widget.existingIds.contains(id)) {
      id = '$base-$n';
      n++;
    }
    return id;
  }

  /// Draft workspace used by the live preview + icon anchor. Uses the
  /// typed name (or "Untitled") and the derived id so the user sees
  /// what the sidebar row will look like before they hit Create.
  Workspace get _draft {
    final name = _name.trim();
    return Workspace(
      id: _deriveId(name),
      name: name.isEmpty ? 'Untitled' : name,
      color: _color,
      icon: _icon,
    );
  }

  void _create() {
    final name = _name.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }
    widget.onCreate(Workspace(
      id: _deriveId(name),
      name: name,
      color: _color,
      icon: _icon,
    ));
  }

  Future<void> _openIconPopover() async {
    final t = widget.theme;
    await _showAnchoredPopover(
      context: context,
      anchorKey: _iconAnchorKey,
      theme: t,
      width: 308,
      builder: (popCtx) => WorkspaceIconPicker(
        currentIcon: _icon,
        accentColor: _parseHex(_color),
        theme: t,
        supportSvg: false,
        onChanged: (v) {
          setState(() => _icon = v);
          Navigator.of(popCtx).pop();
        },
      ),
    );
  }

  Future<void> _openColorPopover() async {
    final t = widget.theme;
    await _showAnchoredPopover(
      context: context,
      anchorKey: _colorAnchorKey,
      theme: t,
      width: 240,
      builder: (popCtx) => _WorkspaceColorPicker(
        value: _color,
        theme: t,
        onChanged: (v) {
          setState(() => _color = v);
          Navigator.of(popCtx).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.blockBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: t.blockBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BolanText.label('New workspace'),
          const SizedBox(height: 8),
          BolanTextField(
            value: _name,
            hint: 'e.g. Work, Personal, Side Projects',
            autofocus: true,
            onChanged: (v) => setState(() {
              _name = v;
              if (_error != null && v.trim().isNotEmpty) _error = null;
            }),
            onSubmitted: (_) => _create(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 4),
            BolanText.caption(_error!, color: t.exitFailureFg),
          ],
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _IconAnchor(
                key: _iconAnchorKey,
                workspace: _draft,
                theme: t,
                onTap: _openIconPopover,
              ),
              const SizedBox(width: 6),
              _ColorAnchor(
                key: _colorAnchorKey,
                colorHex: _color,
                theme: t,
                onTap: _openColorPopover,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _WorkspaceRowPreview(
                  workspace: _draft,
                  theme: t,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const BolanText.caption(
            'SVG upload is available after the workspace is created.',
          ),
          const SizedBox(height: 12),
          Row(children: [
            BolanButton.primary(
              label: 'Create',
              onTap: _create,
            ),
            const SizedBox(width: 8),
            BolanButton(
              label: 'Cancel',
              onTap: widget.onCancel,
            ),
          ]),
        ],
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final String color;
  final bool selected;
  final VoidCallback onTap;
  final BolonTheme theme;

  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final hex = color.replaceFirst('#', '');
    final v = int.tryParse(hex, radix: 16) ?? 0x888888;
    final c = Color(0xFF000000 | v);
    return _FocusableTile(
      onTap: onTap,
      theme: theme,
      borderRadius: BorderRadius.circular(6),
      tooltip: color.toUpperCase(),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? Colors.white : Colors.transparent,
            width: 2,
          ),
        ),
      ),
    );
  }
}

/// Palette swatches + a standalone swatch for a custom-picked color +
/// a "Custom color" gradient tile that opens the HSV picker dialog.
class _WorkspaceColorPicker extends StatelessWidget {
  final String value;
  final BolonTheme theme;
  final ValueChanged<String> onChanged;

  const _WorkspaceColorPicker({
    required this.value,
    required this.theme,
    required this.onChanged,
  });

  Color _parseHex(String hex) {
    final s = hex.replaceFirst('#', '');
    final v = int.tryParse(s, radix: 16) ?? 0x888888;
    return Color(0xFF000000 | v);
  }

  String _hex(Color c) =>
      '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  Future<void> _openCustom(BuildContext context) async {
    final result = await showDialog<Color>(
      context: context,
      builder: (_) => BolonThemeProvider(
        theme: theme,
        child: ColorPickerDialog(
          initialColor: _parseHex(value),
          theme: theme,
        ),
      ),
    );
    if (result != null) onChanged(_hex(result));
  }

  @override
  Widget build(BuildContext context) {
    final isCustom = !kWorkspacePalette.contains(value);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final c in kWorkspacePalette)
          _ColorSwatch(
            color: c,
            selected: c == value,
            theme: theme,
            onTap: () => onChanged(c),
          ),
        if (isCustom)
          _ColorSwatch(
            color: value,
            selected: true,
            theme: theme,
            onTap: () => _openCustom(context),
          ),
        _CustomColorTile(
          theme: theme,
          onTap: () => _openCustom(context),
        ),
      ],
    );
  }
}

class _CustomColorTile extends StatelessWidget {
  final BolonTheme theme;
  final VoidCallback onTap;

  const _CustomColorTile({required this.theme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _FocusableTile(
      onTap: onTap,
      theme: theme,
      borderRadius: BorderRadius.circular(6),
      tooltip: 'Custom color',
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          gradient: const SweepGradient(
            colors: [
              Color(0xFFFF0000),
              Color(0xFFFFFF00),
              Color(0xFF00FF00),
              Color(0xFF00FFFF),
              Color(0xFF0000FF),
              Color(0xFFFF00FF),
              Color(0xFFFF0000),
            ],
          ),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: theme.blockBorder, width: 1),
        ),
      ),
    );
  }
}

// ─── Focusable shell ───────────────────────────────────────────
//
// Wraps any tile with keyboard focus (Enter/Space → activate) and a
// visible focus halo drawn via boxShadow so layout doesn't shift when
// focus moves between siblings.

class _FocusableTile extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final BolonTheme theme;
  final BorderRadius borderRadius;
  final String? tooltip;

  const _FocusableTile({
    required this.child,
    required this.onTap,
    required this.theme,
    required this.borderRadius,
    this.tooltip,
  });

  @override
  State<_FocusableTile> createState() => _FocusableTileState();
}

class _FocusableTileState extends State<_FocusableTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final core = GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: _focused
            ? BoxDecoration(
                borderRadius: widget.borderRadius,
                boxShadow: [
                  BoxShadow(
                    color: t.cursor,
                    spreadRadius: 2,
                    blurRadius: 0,
                  ),
                ],
              )
            : null,
        child: widget.child,
      ),
    );
    final focusable = FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap();
            return null;
          },
        ),
      },
      child: core,
    );
    final tooltip = widget.tooltip;
    return tooltip == null
        ? focusable
        : Tooltip(message: tooltip, child: focusable);
  }
}

// ─── Anchor buttons (collapsed pickers) ────────────────────────

/// 32×32 button showing the workspace's current icon. Tapping (or
/// Enter/Space with keyboard focus) opens the icon popover.
class _IconAnchor extends StatelessWidget {
  final Workspace workspace;
  final BolonTheme theme;
  final VoidCallback onTap;

  const _IconAnchor({
    super.key,
    required this.workspace,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _FocusableTile(
      onTap: onTap,
      theme: theme,
      borderRadius: BorderRadius.circular(6),
      tooltip: 'Icon',
      child: _WorkspaceAvatarTile(
        workspace: workspace,
        theme: theme,
        size: 32,
      ),
    );
  }
}

/// 32×32 swatch showing the workspace's current color. Tapping (or
/// Enter/Space with keyboard focus) opens the color popover.
class _ColorAnchor extends StatelessWidget {
  final String colorHex;
  final BolonTheme theme;
  final VoidCallback onTap;

  const _ColorAnchor({
    super.key,
    required this.colorHex,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hex = colorHex.replaceFirst('#', '');
    final v = int.tryParse(hex, radix: 16) ?? 0x888888;
    final c = Color(0xFF000000 | v);
    return _FocusableTile(
      onTap: onTap,
      theme: theme,
      borderRadius: BorderRadius.circular(6),
      tooltip: 'Color',
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: theme.blockBorder, width: 1),
        ),
      ),
    );
  }
}

// ─── Live preview tile ─────────────────────────────────────────

/// Miniature of the collapsed workspace row. Mirrors the avatar +
/// name + id layout so the user sees the final look as they edit.
class _WorkspaceRowPreview extends StatelessWidget {
  final Workspace workspace;
  final BolonTheme theme;

  const _WorkspaceRowPreview({
    required this.workspace,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.statusChipBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.blockBorder),
      ),
      child: Row(
        children: [
          _WorkspaceAvatarTile(
            workspace: workspace,
            theme: theme,
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BolanText.label(
                  workspace.name.isEmpty ? 'Untitled' : workspace.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                BolanText.caption(
                  workspace.id,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Demoted Enabled switch ────────────────────────────────────

/// Compact `Enabled` label + Switch pair, small enough to sit next
/// to the Save button in the editor footer.
class _InlineEnabledSwitch extends StatelessWidget {
  final bool value;
  final BolonTheme theme;
  final ValueChanged<bool>? onChanged;

  const _InlineEnabledSwitch({
    required this.value,
    required this.theme,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.scale(
          scale: 0.75,
          child: Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: theme.cursor,
            inactiveTrackColor: theme.statusChipBg,
          ),
        ),
        const BolanText.caption('Enabled'),
      ],
    );
  }
}

// ─── Anchored popover ──────────────────────────────────────────
//
// showDialog-based popover positioned below an anchor widget.
// Inherits showDialog's built-in focus trap + Esc-to-dismiss.
// Tap outside the card also dismisses. Arrow keys navigate between
// focusable children inside the popover (FocusableActionDetector
// tiles).

Future<void> _showAnchoredPopover({
  required BuildContext context,
  required GlobalKey anchorKey,
  required BolonTheme theme,
  required Widget Function(BuildContext) builder,
  double width = 280,
}) async {
  final anchorCtx = anchorKey.currentContext;
  if (anchorCtx == null) return;
  final anchorBox = anchorCtx.findRenderObject() as RenderBox?;
  if (anchorBox == null) return;
  final anchorOffset = anchorBox.localToGlobal(Offset.zero);
  final anchorSize = anchorBox.size;
  final screenSize = MediaQuery.of(context).size;

  // Clamp x so the popover stays on-screen when the anchor is near
  // the right edge of the workspace row.
  double left = anchorOffset.dx;
  if (left + width + 8 > screenSize.width) {
    left = (screenSize.width - width - 8).clamp(8.0, screenSize.width);
  }
  final top = anchorOffset.dy + anchorSize.height + 6;

  await showDialog<void>(
    context: context,
    barrierColor: Colors.transparent,
    builder: (ctx) {
      return BolonThemeProvider(
        theme: theme,
        child: Stack(
          children: [
            // Tap-outside dismiss
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(ctx).pop(),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              child: CallbackShortcuts(
                bindings: <ShortcutActivator, VoidCallback>{
                  const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                      FocusManager.instance.primaryFocus
                          ?.focusInDirection(TraversalDirection.right),
                  const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                      FocusManager.instance.primaryFocus
                          ?.focusInDirection(TraversalDirection.left),
                  const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                      FocusManager.instance.primaryFocus
                          ?.focusInDirection(TraversalDirection.up),
                  const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                      FocusManager.instance.primaryFocus
                          ?.focusInDirection(TraversalDirection.down),
                },
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: width,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.blockBackground,
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: theme.blockBorder, width: 1),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 16,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: FocusScope(
                      autofocus: true,
                      child: builder(ctx),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
