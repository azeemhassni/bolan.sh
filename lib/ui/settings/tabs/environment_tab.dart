import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/bolan_theme.dart';
import '../../../core/workspace/workspace.dart';
import '../../../core/workspace/workspace_secrets.dart';
import '../../../providers/workspace_provider.dart';
import '../../shared/bolan_button.dart';
import '../../shared/bolan_components.dart';

class EnvironmentTab extends ConsumerStatefulWidget {
  final Workspace workspace;
  final BolonTheme theme;

  const EnvironmentTab({
    super.key,
    required this.workspace,
    required this.theme,
  });

  @override
  ConsumerState<EnvironmentTab> createState() => _EnvironmentTabState();
}

class _EnvironmentTabState extends ConsumerState<EnvironmentTab> {
  late TextEditingController _gitName;
  late TextEditingController _gitEmail;
  late List<MapEntry<String, String>> _envEntries;
  List<MapEntry<String, String>> _secretEntries = [];
  bool _secretsLoaded = false;
  bool _saving = false;
  bool _justSaved = false;

  @override
  void initState() {
    super.initState();
    _seed();
    _loadSecrets();
  }

  @override
  void didUpdateWidget(EnvironmentTab old) {
    super.didUpdateWidget(old);
    if (old.workspace.id != widget.workspace.id) {
      _gitName.dispose();
      _gitEmail.dispose();
      _seed();
      _secretsLoaded = false;
      _loadSecrets();
    }
  }

  void _seed() {
    _gitName = TextEditingController(text: widget.workspace.gitName ?? '');
    _gitEmail = TextEditingController(text: widget.workspace.gitEmail ?? '');
    _envEntries = widget.workspace.envVars.entries
        .map((e) => MapEntry(e.key, e.value))
        .toList();
  }

  Future<void> _loadSecrets() async {
    final secrets = await WorkspaceSecrets.load(widget.workspace.id);
    if (!mounted) return;
    setState(() {
      _secretEntries =
          secrets.entries.map((e) => MapEntry(e.key, e.value)).toList();
      _secretsLoaded = true;
    });
  }

  @override
  void dispose() {
    _gitName.dispose();
    _gitEmail.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    final secretsMap = {
      for (final e in _secretEntries)
        if (e.key.trim().isNotEmpty) e.key.trim(): e.value,
    };
    final envMap = {
      for (final e in _envEntries)
        if (e.key.trim().isNotEmpty) e.key.trim(): e.value,
    };

    await WorkspaceSecrets.save(widget.workspace.id, secretsMap);

    final registry = ref.read(workspaceRegistryProvider);
    await registry.update(widget.workspace.copyWith(
      gitName: _gitName.text.trim().isEmpty ? null : _gitName.text.trim(),
      gitEmail:
          _gitEmail.text.trim().isEmpty ? null : _gitEmail.text.trim(),
      envVars: envMap,
      secrets: secretsMap,
    ));

    if (!mounted) return;
    setState(() {
      _saving = false;
      _justSaved = true;
    });
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _justSaved = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      children: [
        _sectionHeader(t, 'Workspace', widget.workspace.name),
        const SizedBox(height: 16),

        const BolanSectionHeader('Git Identity'),
        Text(
          'Injected into PTY env. Requires Git 2.31+.',
          style: _helpStyle(t),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: BolanField(
              label: 'Name',
              child: BolanTextField(
                value: _gitName.text,
                hint: 'Jane Doe',
                onChanged: (v) => _gitName.text = v,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: BolanField(
              label: 'Email',
              child: BolanTextField(
                value: _gitEmail.text,
                hint: 'jane@example.com',
                onChanged: (v) => _gitEmail.text = v,
              ),
            ),
          ),
        ]),

        const SizedBox(height: 8),
        const BolanSectionHeader('Environment Variables'),
        Text(
          'Plain-text values stored in this workspace\'s config.toml.',
          style: _helpStyle(t),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < _envEntries.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Expanded(
                child: BolanTextField(
                  value: _envEntries[i].key,
                  hint: 'KEY',
                  onChanged: (v) => setState(() =>
                      _envEntries[i] = MapEntry(v, _envEntries[i].value)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: BolanTextField(
                  value: _envEntries[i].value,
                  hint: 'value',
                  onChanged: (v) => setState(() =>
                      _envEntries[i] = MapEntry(_envEntries[i].key, v)),
                ),
              ),
              IconButton(
                icon:
                    Icon(Icons.close, size: 16, color: t.dimForeground),
                onPressed: () => setState(() => _envEntries.removeAt(i)),
                splashRadius: 16,
                tooltip: 'Remove',
              ),
            ]),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: BolanButton.ghost(
            label: 'Add variable',
            icon: Icons.add,
            onTap: () =>
                setState(() => _envEntries.add(const MapEntry('', ''))),
          ),
        ),

        const SizedBox(height: 24),
        const BolanSectionHeader('Secrets'),
        Text(
          'Stored in the OS keychain, never written to disk in plain text.',
          style: _helpStyle(t),
        ),
        const SizedBox(height: 8),
        if (!_secretsLoaded)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Loading…', style: _helpStyle(t)),
          )
        else ...[
          for (var i = 0; i < _secretEntries.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Expanded(
                  child: BolanTextField(
                    value: _secretEntries[i].key,
                    hint: 'KEY',
                    onChanged: (v) => setState(() => _secretEntries[i] =
                        MapEntry(v, _secretEntries[i].value)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: BolanTextField(
                    value: _secretEntries[i].value,
                    hint: 'secret value',
                    obscure: true,
                    onChanged: (v) => setState(() => _secretEntries[i] =
                        MapEntry(_secretEntries[i].key, v)),
                  ),
                ),
                IconButton(
                  icon:
                      Icon(Icons.close, size: 16, color: t.dimForeground),
                  onPressed: () =>
                      setState(() => _secretEntries.removeAt(i)),
                  splashRadius: 16,
                  tooltip: 'Remove',
                ),
              ]),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: BolanButton.ghost(
              label: 'Add secret',
              icon: Icons.add,
              onTap: () => setState(
                  () => _secretEntries.add(const MapEntry('', ''))),
            ),
          ),
        ],

        const SizedBox(height: 24),
        Row(children: [
          BolanButton.primary(
            label: _saving ? 'Saving…' : 'Save',
            onTap: _saving ? null : _save,
          ),
          const SizedBox(width: 12),
          if (_justSaved)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check, size: 14, color: t.ansiGreen),
                const SizedBox(width: 4),
                Text(
                  'Saved',
                  style: TextStyle(
                    color: t.dimForeground,
                    fontFamily: t.fontFamily,
                    fontSize: 12,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
        ]),
      ],
    );
  }

  Widget _sectionHeader(BolonTheme t, String prefix, String name) {
    return Row(
      children: [
        Text(
          prefix,
          style: TextStyle(
            color: t.dimForeground,
            fontFamily: t.fontFamily,
            fontSize: 11,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          name,
          style: TextStyle(
            color: t.foreground,
            fontFamily: t.fontFamily,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }

  TextStyle _helpStyle(BolonTheme t) => TextStyle(
        color: t.dimForeground,
        fontFamily: t.fontFamily,
        fontSize: 11,
        decoration: TextDecoration.none,
      );
}
