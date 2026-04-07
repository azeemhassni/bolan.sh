import 'package:flutter/material.dart';

import '../../core/system/system_memory.dart';
import '../../core/theme/bolan_theme.dart';

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
  final result = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => Dialog(
      backgroundColor: theme.blockBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    size: 20, color: theme.ansiYellow),
                const SizedBox(width: 10),
                Text(
                  'Not enough free memory',
                  style: TextStyle(
                    color: theme.foreground,
                    fontFamily: theme.fontFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'The $modelLabel model needs about ${SystemMemory.format(requiredBytes)} '
              'of RAM to run, but only ${SystemMemory.format(availableBytes)} '
              'is currently free${totalBytes != null ? ' (out of ${SystemMemory.format(totalBytes)} total)' : ''}.',
              style: TextStyle(
                color: theme.dimForeground,
                fontFamily: theme.fontFamily,
                fontSize: 12,
                height: 1.5,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Loading it may make your system unresponsive or cause Bolan to '
              'crash. Close other apps to free memory, or pick a smaller model.',
              style: TextStyle(
                color: theme.dimForeground,
                fontFamily: theme.fontFamily,
                fontSize: 12,
                height: 1.5,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _DialogButton(
                  label: 'Cancel',
                  theme: theme,
                  onTap: () => Navigator.of(ctx).pop(false),
                ),
                const SizedBox(width: 10),
                _DialogButton(
                  label: 'Proceed Anyway',
                  theme: theme,
                  isDanger: true,
                  onTap: () => Navigator.of(ctx).pop(true),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}

class _DialogButton extends StatelessWidget {
  final String label;
  final BolonTheme theme;
  final bool isDanger;
  final VoidCallback onTap;

  const _DialogButton({
    required this.label,
    required this.theme,
    this.isDanger = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isDanger ? theme.ansiYellow : theme.statusChipBg,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isDanger ? theme.background : theme.foreground,
              fontFamily: theme.fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}
