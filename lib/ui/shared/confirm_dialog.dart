import 'package:flutter/material.dart';

import '../../core/theme/bolan_theme.dart';
import 'bolan_dialog.dart';

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
  return showBolanDialog<ConfirmResult>(
    context: context,
    theme: theme,
    builder: (ctx) => BolanDialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BolanDialogTitle(text: title),
          const SizedBox(height: 12),
          BolanDialogText(message),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              BolanDialogButton(
                label: 'Cancel',
                onTap: () => Navigator.of(ctx).pop(ConfirmResult.cancel),
              ),
              if (secondaryLabel != null) ...[
                const SizedBox(width: 10),
                BolanDialogButton(
                  label: secondaryLabel,
                  onTap: () =>
                      Navigator.of(ctx).pop(ConfirmResult.closePane),
                ),
              ],
              const SizedBox(width: 10),
              BolanDialogButton(
                label: confirmLabel,
                kind: isDangerous
                    ? BolanButtonKind.danger
                    : BolanButtonKind.primary,
                onTap: () =>
                    Navigator.of(ctx).pop(ConfirmResult.closeAll),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
