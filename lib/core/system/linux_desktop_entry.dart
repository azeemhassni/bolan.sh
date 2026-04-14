import 'dart:io';

import 'package:flutter/foundation.dart';

const _appId = 'sh.bolan.linux';
const _iconSizes = [16, 32, 48, 64, 128, 256, 512];

/// On GNOME Wayland (and most modern Linux compositors) the dock/overview
/// matches a window to a `.desktop` file by its `app_id`. Without one, the
/// app shows a generic placeholder icon — `gtk_window_set_icon` only
/// populates X11's `_NET_WM_ICON` which Wayland shells ignore.
///
/// Writes `~/.local/share/applications/sh.bolan.linux.desktop` pointing at
/// the currently running executable and copies the bundled PNGs into the
/// user's hicolor icon theme. Runs on every launch so the `Exec=` path
/// tracks the most recently launched binary — handy for `flutter run`
/// debug builds whose paths shift after `flutter clean`.
Future<void> ensureLinuxDesktopEntry() async {
  if (!Platform.isLinux) return;
  try {
    final home = Platform.environment['HOME'];
    if (home == null || home.isEmpty) return;
    final dataHome =
        Platform.environment['XDG_DATA_HOME']?.isNotEmpty == true
            ? Platform.environment['XDG_DATA_HOME']!
            : '$home/.local/share';

    final exePath = Platform.resolvedExecutable;
    final bundleDir = File(exePath).parent.path;

    final appsDir = Directory('$dataHome/applications');
    await appsDir.create(recursive: true);
    final desktopFile = File('${appsDir.path}/$_appId.desktop');
    final desktopBody = '''
[Desktop Entry]
Type=Application
Name=Bolan
GenericName=Terminal Emulator
Comment=AI-powered terminal
Exec=$exePath %U
Icon=$_appId
Terminal=false
Categories=System;TerminalEmulator;
StartupWMClass=$_appId
StartupNotify=true
''';
    // Only rewrite when the content actually changed — avoids touching
    // the file (and its mtime) on every launch.
    String? existing;
    if (await desktopFile.exists()) {
      existing = await desktopFile.readAsString();
    }
    if (existing != desktopBody) {
      await desktopFile.writeAsString(desktopBody);
    }

    var iconsChanged = false;
    for (final size in _iconSizes) {
      final src = File('$bundleDir/data/icons/app_icon_$size.png');
      if (!await src.exists()) continue;
      final destDir =
          Directory('$dataHome/icons/hicolor/${size}x$size/apps');
      await destDir.create(recursive: true);
      final dest = File('${destDir.path}/$_appId.png');
      final destExists = await dest.exists();
      if (!destExists || await dest.length() != await src.length()) {
        await src.copy(dest.path);
        iconsChanged = true;
      }
    }

    if (iconsChanged) {
      // Best-effort: refresh the hicolor icon cache so the new icons are
      // picked up without a session restart. Silently ignore if the tool
      // isn't installed.
      try {
        await Process.run(
          'gtk-update-icon-cache',
          ['-q', '-t', '-f', '$dataHome/icons/hicolor'],
        );
      } catch (_) {}
    }
  } catch (e, st) {
    debugPrint('linux_desktop_entry: install failed: $e\n$st');
  }
}
