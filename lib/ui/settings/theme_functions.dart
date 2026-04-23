import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../core/ai/ai_provider_helper.dart';
import '../../core/ai/features/theme_generator.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/bolan_theme.dart';
import '../../core/theme/theme_registry.dart';

/// Generate a theme from a natural-language description using the
/// configured AI provider. Returns the preview theme on success.
Future<BolonTheme> generateTheme(
  AiConfig ai,
  String description,
) async {
  final provider = await AiProviderHelper.create(
    providerName: ai.provider,
    geminiModel: ai.geminiModel,
    anthropicMode: ai.anthropicMode,
  );
  if (provider == null) {
    throw Exception('No AI provider configured.');
  }
  final generator = ThemeGenerator(provider: provider);
  return generator.generate(description.trim());
}

/// Duplicate a built-in or custom theme and return the copy.
Future<BolonTheme> duplicateTheme(
  ThemeRegistry registry,
  BolonTheme source,
) async {
  final newName = '${source.name}-copy';
  final displayName = '${source.displayName} Copy';
  return registry.duplicateTheme(source, newName, displayName);
}

/// Export a theme to a file chosen by the user. Returns the export
/// path on success, null if the user cancelled.
Future<String?> exportTheme(
  ThemeRegistry registry,
  BolonTheme theme,
) async {
  final location = await getSaveLocation(
    suggestedName: '${theme.name}.toml',
    acceptedTypeGroups: [
      const XTypeGroup(label: 'TOML', extensions: ['toml']),
    ],
  );
  if (location == null) return null;
  await registry.exportTheme(theme, location.path);
  return location.path;
}

/// Import a theme from a file chosen by the user. Returns the imported
/// theme on success, null if cancelled or invalid.
Future<BolonTheme?> importTheme(ThemeRegistry registry) async {
  final file = await openFile(
    acceptedTypeGroups: [
      const XTypeGroup(label: 'TOML', extensions: ['toml']),
    ],
  );
  if (file == null) return null;
  return registry.importTheme(file.path);
}

/// Show a rename dialog and persist the renamed theme. Returns the
/// renamed theme's slug on success, null if cancelled.
Future<String?> renameTheme(
  BuildContext context,
  ThemeRegistry registry,
  BolonTheme theme,
) async {
  final controller = TextEditingController(text: theme.displayName);
  final t = BolonTheme.of(context);

  final newName = await showDialog<String>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: t.blockBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rename Theme',
              style: TextStyle(
                color: t.foreground,
                fontFamily: t.fontFamily,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Material(
              color: t.statusChipBg,
              borderRadius: BorderRadius.circular(6),
              child: TextField(
                controller: controller,
                autofocus: true,
                style: TextStyle(
                  color: t.foreground,
                  fontFamily: t.fontFamily,
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: t.blockBorder),
                  ),
                  isDense: true,
                ),
                onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('Cancel',
                      style: TextStyle(color: t.dimForeground)),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.of(ctx).pop(controller.text.trim()),
                  child: Text('Rename',
                      style: TextStyle(color: t.cursor)),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  controller.dispose();
  if (newName == null || newName.isEmpty || newName == theme.displayName) {
    return null;
  }

  final slug = newName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  await registry.removeCustomTheme(theme.name);
  final renamed = theme.copyWith(name: slug, displayName: newName);
  await registry.saveCustomTheme(renamed);
  return slug;
}

/// Delete a custom theme from the registry.
Future<void> deleteTheme(ThemeRegistry registry, BolonTheme theme) {
  return registry.removeCustomTheme(theme.name);
}
