import 'package:flutter/material.dart';

import '../../core/system/system_memory.dart';
import '../../core/theme/bolan_theme.dart';
import '../shared/bolan_dialog.dart';

/// Confirmation dialog shown when the user is about to download or load
/// a local model that may exceed available system memory.
///
/// Returns `true` if the user chose to proceed anyway, `false` otherwise.
Future<bool> showMemoryWarningDialog(
  BuildContext context, {
  required BolonTheme theme,
  required String modelLabel,
  required int requiredBytes,
  required int availableBytes,
  int? totalBytes,
}) async {
  final result = await showBolanDialog<bool>(
    context: context,
    theme: theme,
    builder: (ctx) => BolanDialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BolanDialogTitle(
            text: 'Not enough free memory',
            icon: Icons.warning_amber_rounded,
            iconColor: theme.ansiYellow,
          ),
          const SizedBox(height: 14),
          BolanDialogText(
            'The $modelLabel model needs about ${SystemMemory.format(requiredBytes)} '
            'of RAM to run, but only ${SystemMemory.format(availableBytes)} '
            'is currently free${totalBytes != null ? ' (out of ${SystemMemory.format(totalBytes)} total)' : ''}.',
          ),
          const SizedBox(height: 10),
          const BolanDialogText(
            'Loading it may make your system unresponsive or cause Bolan to '
            'crash. Close other apps to free memory, or pick a smaller model.',
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              BolanDialogButton(
                label: 'Cancel',
                onTap: () => Navigator.of(ctx).pop(false),
              ),
              const SizedBox(width: 10),
              BolanDialogButton(
                label: 'Proceed Anyway',
                kind: BolanButtonKind.danger,
                onTap: () => Navigator.of(ctx).pop(true),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}
