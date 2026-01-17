import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/default_dark.dart';
import 'ui/shell/terminal_shell.dart';

/// Root widget for the Bolan terminal emulator.
class BolonApp extends ConsumerWidget {
  const BolonApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Bolan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bolonDefaultDark.background,
        fontFamily: 'JetBrainsMono',
        textTheme: const TextTheme().apply(
          decoration: TextDecoration.none,
        ),
      ),
      home: DefaultTextStyle(
        style: TextStyle(
          fontFamily: 'JetBrainsMono',
          decoration: TextDecoration.none,
          color: bolonDefaultDark.foreground,
        ),
        child: const TerminalShell(),
      ),
    );
  }
}
