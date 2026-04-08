import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/bolan_theme.dart';

/// Reference to a currently-mounted popover. Used to dismiss
/// programmatically (e.g. on selection from inside the content).
class AnchoredPopoverHandle {
  final void Function() dismiss;
  AnchoredPopoverHandle._(this.dismiss);
}

/// Tracks the active popover so opening a new one auto-closes the old.
AnchoredPopoverHandle? _active;

/// Shows [child] as a popover anchored to the on-screen position of
/// [anchorKey]. The popover is placed above the anchor when there's
/// room (chips live at the bottom of the prompt area), otherwise
/// below.
///
/// Returns a handle the caller can use to dismiss programmatically.
/// Tapping outside the popover or pressing Escape also dismisses it.
AnchoredPopoverHandle showAnchoredPopover({
  required BuildContext context,
  required GlobalKey anchorKey,
  required Widget child,
  double maxWidth = 360,
  double maxHeight = 320,
  double gap = 8,
}) {
  // Auto-dismiss any popover that's already open.
  _active?.dismiss();

  final overlay = Overlay.of(context);
  final theme = BolonTheme.of(context);

  final renderBox =
      anchorKey.currentContext?.findRenderObject() as RenderBox?;
  if (renderBox == null) {
    // Anchor not laid out yet — bail with a no-op handle.
    return AnchoredPopoverHandle._(() {});
  }
  final anchorPos = renderBox.localToGlobal(Offset.zero);
  final anchorSize = renderBox.size;
  final screen = MediaQuery.of(context).size;

  // Decide whether to place above or below the anchor.
  final spaceAbove = anchorPos.dy;
  final spaceBelow = screen.height - (anchorPos.dy + anchorSize.height);
  final placeAbove = spaceAbove >= maxHeight + gap || spaceAbove > spaceBelow;

  final actualHeight = placeAbove
      ? (maxHeight.clamp(120.0, spaceAbove - gap))
      : (maxHeight.clamp(120.0, spaceBelow - gap));

  final top = placeAbove
      ? anchorPos.dy - actualHeight - gap
      : anchorPos.dy + anchorSize.height + gap;

  // Horizontal position: try to align the popover's left edge with
  // the anchor, but clamp inside the screen.
  var left = anchorPos.dx;
  if (left + maxWidth > screen.width - 8) {
    left = screen.width - maxWidth - 8;
  }
  if (left < 8) left = 8;

  late OverlayEntry entry;
  late AnchoredPopoverHandle handle;

  void dismiss() {
    if (_active == handle) _active = null;
    entry.remove();
  }

  handle = AnchoredPopoverHandle._(dismiss);

  entry = OverlayEntry(
    builder: (ctx) {
      return Stack(
        children: [
          // Full-screen barrier — taps outside the popover dismiss it.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: dismiss,
              child: const SizedBox.expand(),
            ),
          ),
          // The popover itself.
          Positioned(
            left: left,
            top: top,
            width: maxWidth,
            height: actualHeight,
            child: BolonThemeProvider(
              theme: theme,
              child: _PopoverShell(
                onDismiss: dismiss,
                child: child,
              ),
            ),
          ),
        ],
      );
    },
  );

  overlay.insert(entry);
  _active = handle;
  return handle;
}

/// Styled chrome for popover content. Provides theme-consistent
/// background, border, shadow, and Escape-to-dismiss behavior.
///
/// We deliberately do NOT install a `Focus` widget with our own
/// `FocusNode` here. Doing so competed with the search TextField
/// inside the content and prevented typing on macOS desktop. ESC
/// is handled via [CallbackShortcuts], which routes shortcuts based
/// on whichever descendant currently has focus — the TextField wins,
/// owns all keystrokes, and ESC still bubbles up to the binding.
class _PopoverShell extends StatelessWidget {
  final Widget child;
  final VoidCallback onDismiss;

  const _PopoverShell({required this.child, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final theme = BolonTheme.of(context);
    // FocusScope is critical: the popover is mounted in the root
    // Overlay, which sits outside any route's focus scope. Without
    // an explicit scope here, descendant TextFields can call
    // `requestFocus()` but Flutter has nowhere to attach the input
    // connection — typing produces no characters on desktop.
    return Material(
      color: Colors.transparent,
      child: FocusScope(
        autofocus: true,
        child: CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.escape): onDismiss,
          },
          child: Container(
            decoration: BoxDecoration(
              color: theme.blockBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.blockBorder, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(120),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: child,
          ),
        ),
      ),
    );
  }
}
