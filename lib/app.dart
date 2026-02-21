import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/theme_provider.dart';
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
        fontFamily: 'Operator Mono',
        textTheme: const TextTheme().apply(
          decoration: TextDecoration.none,
        ),
      ),
      home: DefaultTextStyle(
        style: TextStyle(
          fontFamily: 'Operator Mono',
          decoration: TextDecoration.none,
          color: theme.foreground,
        ),
        child: const TerminalShell(),
      ),
    );
  }
}
