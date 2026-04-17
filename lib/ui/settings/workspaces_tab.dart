import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/bolan_theme.dart';
import '../../core/workspace/workspace.dart';
import '../../core/workspace/workspace_secrets.dart';
import '../../providers/workspace_provider.dart';
import '../shared/bolan_button.dart';

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

  static const _palette = [
    '#7AA2F7', '#F7768E', '#9ECE6A', '#E0AF68',
    '#BB9AF7', '#7DCFFF', '#FF9E64', '#73DACA',
  ];

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
            canDelete: registry.workspaces.length > 1,
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
            palette: _palette,
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
              label: '+ New Workspace',
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
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: workspace.accentColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        workspace.initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
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
                  else
                    BolanButton.ghost(
                      label: 'Switch',
                      onTap: onSwitch,
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
              theme: theme,
              canDelete: canDelete,
              onSave: onSave,
              onDelete: onDelete,
            ),
        ],
      ),
    );
  }
}

class _WorkspaceEditor extends StatefulWidget {
  final Workspace workspace;
  final BolonTheme theme;
  final bool canDelete;
  final ValueChanged<Workspace> onSave;
  final VoidCallback onDelete;

  const _WorkspaceEditor({
    required this.workspace,
    required this.theme,
    required this.canDelete,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<_WorkspaceEditor> createState() => _WorkspaceEditorState();
}

class _WorkspaceEditorState extends State<_WorkspaceEditor> {
  late TextEditingController _name;
  late TextEditingController _color;
  late TextEditingController _gitName;
  late TextEditingController _gitEmail;
  late List<MapEntry<String, String>> _envEntries;
  List<MapEntry<String, String>> _secretEntries = [];
  bool _secretsLoaded = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.workspace.name);
    _color = TextEditingController(text: widget.workspace.color);
    _gitName = TextEditingController(text: widget.workspace.gitName ?? '');
    _gitEmail =
        TextEditingController(text: widget.workspace.gitEmail ?? '');
    _envEntries = widget.workspace.envVars.entries
        .map((e) => MapEntry(e.key, e.value))
        .toList();
    _loadSecrets();
  }

  Future<void> _loadSecrets() async {
    final secrets = await WorkspaceSecrets.load(widget.workspace.id);
    if (!mounted) return;
    setState(() {
      _secretEntries = secrets.entries
          .map((e) => MapEntry(e.key, e.value))
          .toList();
      _secretsLoaded = true;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _color.dispose();
    _gitName.dispose();
    _gitEmail.dispose();
    super.dispose();
  }

  void _save() {
    // Persist secrets to keychain (not TOML)
    final secretsMap = {
      for (final e in _secretEntries)
        if (e.key.trim().isNotEmpty) e.key.trim(): e.value,
    };
    WorkspaceSecrets.save(widget.workspace.id, secretsMap);

    widget.onSave(widget.workspace.copyWith(
      name: _name.text.trim().isEmpty ? widget.workspace.name : _name.text.trim(),
      color: _color.text.trim().isEmpty
          ? widget.workspace.color
          : _color.text.trim(),
      gitName: _gitName.text.trim().isEmpty ? null : _gitName.text.trim(),
      gitEmail:
          _gitEmail.text.trim().isEmpty ? null : _gitEmail.text.trim(),
      envVars: {
        for (final e in _envEntries)
          if (e.key.trim().isNotEmpty) e.key.trim(): e.value,
      },
      secrets: secretsMap,
    ));
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
          _field('Name', _name, t),
          _field('Color (hex)', _color, t),
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text('Git identity (optional)',
                style: _labelStyle(t)),
          ),
          Row(children: [
            Expanded(child: _field('Name', _gitName, t)),
            const SizedBox(width: 8),
            Expanded(child: _field('Email', _gitEmail, t)),
          ]),
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text('Environment variables', style: _labelStyle(t)),
          ),
          for (var i = 0; i < _envEntries.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                Expanded(
                  child: _envField(
                    _envEntries[i].key,
                    'KEY',
                    t,
                    (v) => setState(() => _envEntries[i] =
                        MapEntry(v, _envEntries[i].value)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _envField(
                    _envEntries[i].value,
                    'value',
                    t,
                    (v) => setState(() => _envEntries[i] =
                        MapEntry(_envEntries[i].key, v)),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close,
                      size: 14, color: t.dimForeground),
                  onPressed: () =>
                      setState(() => _envEntries.removeAt(i)),
                  splashRadius: 16,
                ),
              ]),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: BolanButton.ghost(
              label: '+ Add variable',
              icon: Icons.add,
              onTap: () => setState(
                  () => _envEntries.add(const MapEntry('', ''))),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text('Secrets (stored in OS keychain)', style: _labelStyle(t)),
          ),
          if (!_secretsLoaded)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Loading...',
                style: TextStyle(
                  color: t.dimForeground,
                  fontFamily: t.fontFamily,
                  fontSize: 11,
                ),
              ),
            )
          else ...[
            for (var i = 0; i < _secretEntries.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(children: [
                  Expanded(
                    child: _envField(
                      _secretEntries[i].key,
                      'KEY',
                      t,
                      (v) => setState(() => _secretEntries[i] =
                          MapEntry(v, _secretEntries[i].value)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _secretField(
                      _secretEntries[i].value,
                      'secret value',
                      t,
                      (v) => setState(() => _secretEntries[i] =
                          MapEntry(_secretEntries[i].key, v)),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close,
                        size: 14, color: t.dimForeground),
                    onPressed: () =>
                        setState(() => _secretEntries.removeAt(i)),
                    splashRadius: 16,
                  ),
                ]),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: BolanButton.ghost(
                label: '+ Add secret',
                icon: Icons.add,
                onTap: () => setState(
                    () => _secretEntries.add(const MapEntry('', ''))),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(children: [
            BolanButton.primary(
              label: 'Save',
              onTap: _save,
            ),
            const Spacer(),
            if (widget.canDelete)
              BolanButton.danger(
                label: 'Delete workspace',
                onTap: () => _confirmDelete(context),
              ),
          ]),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final t = widget.theme;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
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
    );
  }

  TextStyle _labelStyle(BolonTheme t) => TextStyle(
        color: t.dimForeground,
        fontFamily: t.fontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      );

  Widget _field(String label, TextEditingController controller,
      BolonTheme t,
      {String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _labelStyle(t)),
          const SizedBox(height: 2),
          TextField(
            controller: controller,
            style: TextStyle(
              color: t.foreground,
              fontFamily: t.fontFamily,
              fontSize: 12,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              hintStyle: TextStyle(color: t.dimForeground, fontSize: 11),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: t.blockBorder),
                borderRadius: BorderRadius.circular(4),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: t.blockBorder),
                borderRadius: BorderRadius.circular(4),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _envField(String value, String hint, BolonTheme t,
      ValueChanged<String> onChanged) {
    return TextFormField(
      initialValue: value,
      onChanged: onChanged,
      style: TextStyle(
        color: t.foreground,
        fontFamily: t.fontFamily,
        fontSize: 12,
      ),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: TextStyle(color: t.dimForeground, fontSize: 11),
        border: OutlineInputBorder(
          borderSide: BorderSide(color: t.blockBorder),
          borderRadius: BorderRadius.circular(4),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: t.blockBorder),
          borderRadius: BorderRadius.circular(4),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
    );
  }

  Widget _secretField(String value, String hint, BolonTheme t,
      ValueChanged<String> onChanged) {
    return TextFormField(
      initialValue: value,
      onChanged: onChanged,
      obscureText: true,
      style: TextStyle(
        color: t.foreground,
        fontFamily: t.fontFamily,
        fontSize: 12,
      ),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: TextStyle(color: t.dimForeground, fontSize: 11),
        border: OutlineInputBorder(
          borderSide: BorderSide(color: t.blockBorder),
          borderRadius: BorderRadius.circular(4),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: t.blockBorder),
          borderRadius: BorderRadius.circular(4),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
  final _name = TextEditingController();
  late String _color;
  String? _error;

  @override
  void initState() {
    super.initState();
    _color = widget.palette.first;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
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

  void _create() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }
    widget.onCreate(Workspace(
      id: _deriveId(name),
      name: name,
      color: _color,
    ));
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
          Text('New workspace',
              style: TextStyle(
                  color: t.foreground,
                  fontFamily: t.fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _name,
            autofocus: true,
            onSubmitted: (_) => _create(),
            style: TextStyle(
                color: t.foreground,
                fontFamily: t.fontFamily,
                fontSize: 12),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'e.g. Work, Personal, Side Projects',
              hintStyle: TextStyle(color: t.dimForeground, fontSize: 11),
              errorText: _error,
              border: OutlineInputBorder(
                borderSide: BorderSide(color: t.blockBorder),
                borderRadius: BorderRadius.circular(4),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: t.blockBorder),
                borderRadius: BorderRadius.circular(4),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 8),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              for (final c in widget.palette)
                _ColorSwatch(
                  color: c,
                  selected: c == _color,
                  onTap: () => setState(() => _color = c),
                ),
            ],
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

  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hex = color.replaceFirst('#', '');
    final v = int.tryParse(hex, radix: 16) ?? 0x888888;
    final c = Color(0xFF000000 | v);
    return GestureDetector(
      onTap: onTap,
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
