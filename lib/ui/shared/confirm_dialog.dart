import 'package:flutter/material.dart';

import '../../core/theme/bolan_theme.dart';

/// Result of a close/quit confirmation dialog.
enum ConfirmResult {
  /// Close the entire tab (all panes).
  closeAll,

  /// Close only the focused pane.
  closePane,

  /// Cancel the action.
  cancel,
}

/// Shows a themed confirmation dialog for close/quit actions.
///
/// Returns a [ConfirmResult] or null if dismissed.
Future<ConfirmResult?> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Close',
  String? secondaryLabel,
  bool isDangerous = false,
  BolonTheme? theme,
}) async {
  final t = theme ?? BolonTheme.of(context);

  return showDialog<ConfirmResult>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => Dialog(
      backgroundColor: t.blockBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: t.foreground,
                fontFamily: 'Operator Mono',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: TextStyle(
                color: t.dimForeground,
                fontFamily: 'Operator Mono',
                fontSize: 13,
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
                  theme: t,
                  onTap: () => Navigator.of(ctx).pop(ConfirmResult.cancel),
                ),
                if (secondaryLabel != null) ...[
                  const SizedBox(width: 8),
                  _DialogButton(
                    label: secondaryLabel,
                    theme: t,
                    onTap: () =>
                        Navigator.of(ctx).pop(ConfirmResult.closePane),
                  ),
                ],
                const SizedBox(width: 8),
                _DialogButton(
                  label: confirmLabel,
                  theme: t,
                  isPrimary: true,
                  isDangerous: isDangerous,
                  onTap: () =>
                      Navigator.of(ctx).pop(ConfirmResult.closeAll),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _DialogButton extends StatelessWidget {
  final String label;
  final BolonTheme theme;
  final bool isPrimary;
  final bool isDangerous;
  final VoidCallback onTap;

  const _DialogButton({
    required this.label,
    required this.theme,
    this.isPrimary = false,
    this.isDangerous = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isPrimary
        ? (isDangerous ? theme.exitFailureFg : theme.cursor)
        : theme.statusChipBg;
    final fg = isPrimary ? theme.background : theme.foreground;

    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: fg,
              fontFamily: 'Operator Mono',
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
