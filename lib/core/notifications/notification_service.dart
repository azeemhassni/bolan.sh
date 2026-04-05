import 'dart:io';

/// Sends system notifications when long-running commands complete.
///
/// Uses platform-native tools:
/// - macOS: `osascript` with `display notification`
/// - Linux: `notify-send`
class NotificationService {
  bool _appFocused = true;

  /// Update the app focus state. Call from `WidgetsBindingObserver`.
  void setAppFocused(bool focused) {
    _appFocused = focused;
  }

  /// Whether the app is currently focused.
  bool get isAppFocused => _appFocused;

  /// Sends a notification if the app is not focused.
  /// Returns true if the notification was sent.
  Future<bool> notifyIfUnfocused({
    required String title,
    required String body,
  }) async {
    if (_appFocused) return false;
    await _sendNotification(title: title, body: body);
    return true;
  }

  Future<void> _sendNotification({
    required String title,
    required String body,
  }) async {
    try {
      if (Platform.isMacOS) {
        await Process.run('osascript', [
          '-e',
          'display notification "$body" with title "$title"'
              .replaceAll(r'$body', _escapeAppleScript(body))
              .replaceAll(r'$title', _escapeAppleScript(title)),
        ]);
      } else if (Platform.isLinux) {
        await Process.run('notify-send', [
          title,
          body,
          '--app-name=Bolan',
        ]);
      }
    } on ProcessException {
      // notify-send may not be installed on all Linux distros
    }
  }

  String _escapeAppleScript(String input) {
    return input.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
  }
}
