import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_version.dart';
import 'providers/font_size_provider.dart';
import 'providers/session_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/update_provider.dart';
import 'ui/shell/session_view.dart';
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
          child: TerminalShell(),
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
          PlatformMenuItemGroup(members: [
            PlatformMenuItem(
              label: 'Settings...',
              shortcut: const SingleActivator(
                  LogicalKeyboardKey.comma, meta: true),
              onSelected: () =>
                  TerminalShell.globalKey.currentState?.openSettings(),
            ),
          ]),
          PlatformMenuItemGroup(members: [
            PlatformMenuItem(
              label: 'Quit Bolan',
              shortcut: const SingleActivator(
                  LogicalKeyboardKey.keyQ, meta: true),
              onSelected: () =>
                  TerminalShell.globalKey.currentState?.quitWithConfirm(),
            ),
          ]),
        ],
      ),

      // ── File menu ──
      PlatformMenu(
        label: 'File',
        menus: [
          PlatformMenuItemGroup(members: [
            PlatformMenuItem(
              label: 'New Tab',
              shortcut: const SingleActivator(
                  LogicalKeyboardKey.keyT, meta: true),
              onSelected: () =>
                  ref.read(currentSessionNotifierProvider).createTab(),
            ),
          ]),
          PlatformMenuItemGroup(members: [
            PlatformMenuItem(
              label: 'Close Tab',
              shortcut: const SingleActivator(
                  LogicalKeyboardKey.keyW, meta: true),
              onSelected: () {
                final s = ref.read(currentSessionProvider);
                ref.read(currentSessionNotifierProvider)
                    .closeTab(s.activeTabIndex);
              },
            ),
            PlatformMenuItem(
              label: 'Close Pane',
              shortcut: const SingleActivator(
                  LogicalKeyboardKey.keyW, meta: true, shift: true),
              onSelected: () =>
                  ref.read(currentSessionNotifierProvider).closePane(),
            ),
          ]),
        ],
      ),

      // ── Edit menu ──
      PlatformMenu(
        label: 'Edit',
        menus: [
          const PlatformMenuItemGroup(members: [
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
              shortcut: const SingleActivator(
                  LogicalKeyboardKey.keyF, meta: true),
              onSelected: () {
                final s = ref.read(currentSessionProvider);
                final tab = s.activeTab;
                if (tab != null && tab.focusedPaneId != null) {
                  SessionViewState.of(tab.focusedPaneId!)?.toggleFindBar();
                }
              },
            ),
          ]),
        ],
      ),

      // ── Shell menu ──
      PlatformMenu(
        label: 'Shell',
        menus: [
          PlatformMenuItemGroup(members: [
            PlatformMenuItem(
              label: 'Split Right',
              shortcut: const SingleActivator(
                  LogicalKeyboardKey.keyD, meta: true),
              onSelected: () => ref
                  .read(currentSessionNotifierProvider)
                  .splitPane(Axis.horizontal),
            ),
            PlatformMenuItem(
              label: 'Split Down',
              shortcut: const SingleActivator(
                  LogicalKeyboardKey.keyD, meta: true, shift: true),
              onSelected: () => ref
                  .read(currentSessionNotifierProvider)
                  .splitPane(Axis.vertical),
            ),
          ]),
        ],
      ),

      // ── View menu ──
      PlatformMenu(
        label: 'View',
        menus: [
          PlatformMenuItemGroup(members: [
            PlatformMenuItem(
              label: 'Toggle Sidebar',
              shortcut: const SingleActivator(
                  LogicalKeyboardKey.backslash, meta: true),
              onSelected: () =>
                  TerminalShell.globalKey.currentState?.toggleSidebar(),
            ),
          ]),
          PlatformMenuItemGroup(members: [
            PlatformMenuItem(
              label: 'Zoom In',
              shortcut: const SingleActivator(
                  LogicalKeyboardKey.equal, meta: true),
              onSelected: () =>
                  ref.read(fontSizeProvider.notifier).increase(),
            ),
            PlatformMenuItem(
              label: 'Zoom Out',
              shortcut: const SingleActivator(
                  LogicalKeyboardKey.minus, meta: true),
              onSelected: () =>
                  ref.read(fontSizeProvider.notifier).decrease(),
            ),
          ]),
        ],
      ),

      // ── Window menu ──
      PlatformMenu(
        label: 'Window',
        menus: [
          PlatformMenuItemGroup(members: [
            PlatformMenuItem(
              label: 'Previous Tab',
              shortcut: const SingleActivator(
                  LogicalKeyboardKey.bracketLeft, meta: true,
                  shift: true),
              onSelected: () {
                final s = ref.read(currentSessionProvider);
                final count = s.tabs.length;
                if (count <= 1) return;
                final i = (s.activeTabIndex - 1) % count;
                ref.read(currentSessionNotifierProvider).switchTab(i);
              },
            ),
            PlatformMenuItem(
              label: 'Next Tab',
              shortcut: const SingleActivator(
                  LogicalKeyboardKey.bracketRight, meta: true,
                  shift: true),
              onSelected: () {
                final s = ref.read(currentSessionProvider);
                final count = s.tabs.length;
                if (count <= 1) return;
                final i = (s.activeTabIndex + 1) % count;
                ref.read(currentSessionNotifierProvider).switchTab(i);
              },
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
