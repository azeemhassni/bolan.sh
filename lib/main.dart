import 'dart:io';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macos_window_utils/macos_window_utils.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isMacOS) {
    await _initMacosWindow();
  }

  runApp(const ProviderScope(child: BolonApp()));

  if (Platform.isLinux) {
    doWhenWindowReady(() {
      const initialSize = Size(1100, 700);
      appWindow.minSize = const Size(600, 400);
      appWindow.size = initialSize;
      appWindow.alignment = Alignment.center;
      appWindow.title = 'Bolan';
      appWindow.show();
    });
  }
}

Future<void> _initMacosWindow() async {
  // flutter_acrylic's Window.initialize() calls WindowManipulator.initialize()
  // internally — calling both causes a "Future already completed" error.
  await Window.initialize();

  await WindowManipulator.makeTitlebarTransparent();
  await WindowManipulator.enableFullSizeContentView();
  await WindowManipulator.hideTitle();

  await Window.setEffect(
    effect: WindowEffect.sidebar,
    dark: true,
  );
}
