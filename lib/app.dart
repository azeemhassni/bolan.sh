import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_version.dart';
import 'providers/theme_provider.dart';
import 'providers/update_provider.dart';
import 'ui/shell/terminal_shell.dart';

/// Root widget for the Bolan terminal emulator.
class BolonApp extends ConsumerWidget {
  const BolonApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(activeThemeProvider);

    return MaterialApp(
      title: 'Bolan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: theme.brightness,
        scaffoldBackgroundColor: theme.background,
        fontFamily: theme.fontFamily,
        textTheme: const TextTheme().apply(
          decoration: TextDecoration.none,
        ),
      ),
      home: DefaultTextStyle(
        style: TextStyle(
          fontFamily: theme.fontFamily,
          decoration: TextDecoration.none,
          color: theme.foreground,
        ),
        child: PlatformMenuBar(
          menus: _buildMenus(ref),
          child: const TerminalShell(),
        ),
      ),
    );
  }

  List<PlatformMenuItem> _buildMenus(WidgetRef ref) {
    if (!Platform.isMacOS) return const [];

    return [
      // ── App menu ──
      PlatformMenu(
        label: 'Bolan',
        menus: [
          PlatformMenuItemGroup(members: [
            PlatformMenuItem(
              label: 'About Bolan',
              onSelected: () => _showAbout(),
            ),
            PlatformMenuItem(
              label: 'Check for Updates...',
              onSelected: () =>
                  ref.read(updateProvider).check(force: true),
            ),
          ]),
          const PlatformMenuItemGroup(members: [
            PlatformMenuItem(
              label: 'Settings...',
              shortcut: SingleActivator(
                  LogicalKeyboardKey.comma, meta: true),
              onSelected: null,
            ),
          ]),
          const PlatformMenuItemGroup(members: [
            PlatformMenuItem(
              label: 'Quit Bolan',
              shortcut: SingleActivator(
                  LogicalKeyboardKey.keyQ, meta: true),
              onSelected: null,
            ),
          ]),
        ],
      ),

      // ── File menu ──
      const PlatformMenu(
        label: 'File',
        menus: [
          PlatformMenuItemGroup(members: [
            PlatformMenuItem(
              label: 'New Tab',
              shortcut: SingleActivator(
                  LogicalKeyboardKey.keyT, meta: true),
              onSelected: null,
            ),
          ]),
          PlatformMenuItemGroup(members: [
            PlatformMenuItem(
              label: 'Close Tab',
              shortcut: SingleActivator(
                  LogicalKeyboardKey.keyW, meta: true),
              onSelected: null,
            ),
            PlatformMenuItem(
              label: 'Close Pane',
              shortcut: SingleActivator(
                  LogicalKeyboardKey.keyW, meta: true, shift: true),
              onSelected: null,
            ),
          ]),
        ],
      ),

      // ── Edit menu ──
      const PlatformMenu(
        label: 'Edit',
        menus: [
          PlatformMenuItemGroup(members: [
            PlatformMenuItem(
              label: 'Copy',
              shortcut: SingleActivator(
                  LogicalKeyboardKey.keyC, meta: true),
              onSelected: null,
            ),
            PlatformMenuItem(
              label: 'Paste',
              shortcut: SingleActivator(
                  LogicalKeyboardKey.keyV, meta: true),
              onSelected: null,
            ),
            PlatformMenuItem(
              label: 'Select All',
              shortcut: SingleActivator(
                  LogicalKeyboardKey.keyA, meta: true),
              onSelected: null,
            ),
          ]),
          PlatformMenuItemGroup(members: [
            PlatformMenuItem(
              label: 'Find...',
              shortcut: SingleActivator(
                  LogicalKeyboardKey.keyF, meta: true),
              onSelected: null,
            ),
            PlatformMenuItem(
              label: 'Clear',
              shortcut: SingleActivator(
                  LogicalKeyboardKey.keyK, meta: true),
              onSelected: null,
            ),
          ]),
        ],
      ),

      // ── Shell menu ──
      const PlatformMenu(
        label: 'Shell',
        menus: [
          PlatformMenuItemGroup(members: [
            PlatformMenuItem(
              label: 'Split Right',
              shortcut: SingleActivator(
                  LogicalKeyboardKey.keyD, meta: true),
              onSelected: null,
            ),
            PlatformMenuItem(
              label: 'Split Down',
              shortcut: SingleActivator(
                  LogicalKeyboardKey.keyD, meta: true, shift: true),
              onSelected: null,
            ),
          ]),
        ],
      ),

      // ── View menu ──
      const PlatformMenu(
        label: 'View',
        menus: [
          PlatformMenuItemGroup(members: [
            PlatformMenuItem(
              label: 'Toggle Sidebar',
              shortcut: SingleActivator(
                  LogicalKeyboardKey.backslash, meta: true),
              onSelected: null,
            ),
          ]),
          PlatformMenuItemGroup(members: [
            PlatformMenuItem(
              label: 'Zoom In',
              shortcut: SingleActivator(
                  LogicalKeyboardKey.equal, meta: true),
              onSelected: null,
            ),
            PlatformMenuItem(
              label: 'Zoom Out',
              shortcut: SingleActivator(
                  LogicalKeyboardKey.minus, meta: true),
              onSelected: null,
            ),
          ]),
        ],
      ),

      // ── Window menu ──
      const PlatformMenu(
        label: 'Window',
        menus: [
          PlatformMenuItemGroup(members: [
            PlatformMenuItem(
              label: 'Previous Tab',
              shortcut: SingleActivator(
                  LogicalKeyboardKey.bracketLeft, meta: true,
                  shift: true),
              onSelected: null,
            ),
            PlatformMenuItem(
              label: 'Next Tab',
              shortcut: SingleActivator(
                  LogicalKeyboardKey.bracketRight, meta: true,
                  shift: true),
              onSelected: null,
            ),
          ]),
        ],
      ),

      // ── Help menu ──
      PlatformMenu(
        label: 'Help',
        menus: [
          PlatformMenuItemGroup(members: [
            PlatformMenuItem(
              label: "What's New in v$appVersion",
              onSelected: () => _openUrl(
                  'https://github.com/AzeemHassni/bolan.sh/releases/tag/v$appVersion'),
            ),
            PlatformMenuItem(
              label: 'GitHub Repository',
              onSelected: () => _openUrl(
                  'https://github.com/AzeemHassni/bolan.sh'),
            ),
            PlatformMenuItem(
              label: 'Report an Issue',
              onSelected: () => _openUrl(
                  'https://github.com/AzeemHassni/bolan.sh/issues/new'),
            ),
          ]),
          PlatformMenuItemGroup(members: [
            PlatformMenuItem(
              label: 'Check for Updates...',
              onSelected: () =>
                  ref.read(updateProvider).check(force: true),
            ),
          ]),
        ],
      ),
    ];
  }

  static void _openUrl(String url) {
    if (Platform.isMacOS) {
      Process.run('open', [url]);
    } else if (Platform.isLinux) {
      Process.run('xdg-open', [url]);
    }
  }

  static void _showAbout() {
    _openUrl('https://github.com/AzeemHassni/bolan.sh');
  }
}
