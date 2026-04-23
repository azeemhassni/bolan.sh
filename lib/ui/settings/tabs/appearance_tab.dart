import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/bolan_theme.dart';
import '../../../core/theme/theme_registry.dart';
import '../../shared/bolan_components.dart';
import '../theme_editor.dart';
import '../theme_functions.dart';
import '../widgets/action_button.dart';
import '../widgets/ai_theme_generator.dart';
import '../widgets/theme_card.dart';

class AppearanceTab extends StatefulWidget {
  final AppConfig config;
  final ThemeRegistry registry;
  final BolonTheme theme;
  final ValueChanged<String> onActiveThemeChanged;

  const AppearanceTab({
    super.key,
    required this.config,
    required this.registry,
    required this.theme,
    required this.onActiveThemeChanged,
  });

  @override
  State<AppearanceTab> createState() => _AppearanceTabState();
}

class _AppearanceTabState extends State<AppearanceTab> {
  bool _generating = false;
  String? _error;
  BolonTheme? _preview;
  bool _legacyExpanded = false;

  Future<void> _generate(String description) async {
    if (description.trim().isEmpty) return;
    setState(() {
      _generating = true;
      _error = null;
      _preview = null;
    });
    try {
      final theme = await generateTheme(widget.config.ai, description);
      if (!mounted) return;
      setState(() {
        _preview = theme;
        _generating = false;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to generate: $e';
        _generating = false;
      });
    }
  }

  Future<void> _saveGenerated() async {
    final theme = _preview;
    if (theme == null) return;
    await widget.registry.saveCustomTheme(theme);
    widget.onActiveThemeChanged(theme.name);
    setState(() => _preview = null);
  }

  Future<void> _duplicate(BolonTheme source) async {
    final copy = await duplicateTheme(widget.registry, source);
    if (!mounted) return;
    widget.onActiveThemeChanged(copy.name);
  }

  Future<void> _export(BolonTheme theme) async {
    final path = await exportTheme(widget.registry, theme);
    if (path != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported to $path')),
      );
    }
  }

  Future<void> _import() async {
    final theme = await importTheme(widget.registry);
    if (theme != null && mounted) {
      widget.onActiveThemeChanged(theme.name);
    }
  }

  Future<void> _rename(BolonTheme theme) async {
    final slug = await renameTheme(context, widget.registry, theme);
    if (slug != null && mounted) {
      widget.onActiveThemeChanged(slug);
    }
  }

  Future<void> _delete(BolonTheme theme) async {
    await deleteTheme(widget.registry, theme);
    if (!mounted) return;
    widget.onActiveThemeChanged('midnight-cove');
  }

  Widget _themeGrid(List<BolonTheme> themes, BolonTheme currentTheme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final t in themes)
          ThemeCard(
            theme: t,
            isActive: widget.config.activeTheme == t.name,
            currentTheme: currentTheme,
            onTap: () => widget.onActiveThemeChanged(t.name),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = widget.registry.primaryBuiltIns;
    final custom = widget.registry.customThemes;
    final legacy = widget.registry.legacyBuiltIns;
    final activeTheme = widget.registry.getTheme(widget.config.activeTheme);
    final theme = widget.theme;
    final activeIsLegacy = widget.registry.isLegacy(activeTheme);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      children: [
        const BolanSectionHeader('BUILT-IN'),
        _themeGrid(primary, theme),
        const SizedBox(height: 20),
        if (custom.isNotEmpty) ...[
          const BolanSectionHeader('CUSTOM'),
          _themeGrid(custom, theme),
          const SizedBox(height: 20),
        ],
        _LegacyAccordion(
          theme: theme,
          expanded: _legacyExpanded || activeIsLegacy,
          count: legacy.length,
          onToggle: () =>
              setState(() => _legacyExpanded = !_legacyExpanded),
          child: _themeGrid(legacy, theme),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            ActionButton(
              label: 'Duplicate',
              color: theme.cursor,
              theme: theme,
              onTap: () => _duplicate(activeTheme),
            ),
            const SizedBox(width: 12),
            ActionButton(
              label: 'Export',
              color: theme.cursor,
              theme: theme,
              onTap: () => _export(activeTheme),
            ),
            const SizedBox(width: 12),
            ActionButton(
              label: 'Import',
              color: theme.cursor,
              theme: theme,
              onTap: _import,
            ),
            if (!activeTheme.isBuiltIn) ...[
              const SizedBox(width: 12),
              ActionButton(
                label: 'Rename',
                color: theme.cursor,
                theme: theme,
                onTap: () => _rename(activeTheme),
              ),
              const SizedBox(width: 12),
              ActionButton(
                label: 'Delete',
                color: theme.exitFailureFg,
                theme: theme,
                onTap: () => _delete(activeTheme),
              ),
            ],
          ],
        ),
        const SizedBox(height: 24),
        if (widget.config.ai.enabled)
          AiThemeGenerator(
            generating: _generating,
            error: _error,
            previewTheme: _preview,
            onGenerate: _generate,
            onSave: _saveGenerated,
            onDiscard: () => setState(() {
              _preview = null;
              _error = null;
            }),
          ),
        const SizedBox(height: 24),
        ThemeEditor(
          theme: activeTheme,
          editable: !activeTheme.isBuiltIn,
          onChanged: (updated) async {
            await widget.registry.saveCustomTheme(updated);
            setState(() {});
          },
        ),
      ],
    );
  }
}

class _LegacyAccordion extends StatelessWidget {
  final BolonTheme theme;
  final bool expanded;
  final int count;
  final VoidCallback onToggle;
  final Widget child;

  const _LegacyAccordion({
    required this.theme,
    required this.expanded,
    required this.count,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onToggle,
          behavior: HitTestBehavior.opaque,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(
                    expanded ? Icons.expand_more : Icons.chevron_right,
                    size: 16,
                    color: theme.dimForeground,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Legacy themes',
                    style: TextStyle(
                      color: theme.dimForeground,
                      fontFamily: theme.fontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '($count)',
                    style: TextStyle(
                      color: theme.dimForeground.withAlpha(160),
                      fontFamily: theme.fontFamily,
                      fontSize: 11,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: child,
          ),
      ],
    );
  }
}
