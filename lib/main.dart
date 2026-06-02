import 'dart:io';

import 'package:flutter/material.dart';
import 'package:macos_window_utils/macos_window_utils.dart';
import 'package:window_manager/window_manager.dart';
import 'app/xell_app.dart';
import 'core/window_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(1280, 800),
      minimumSize: Size(860, 560),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await WindowPreferences.restore();
      await windowManager.show();
      await windowManager.focus();
    });

    if (Platform.isMacOS) {
      await WindowManipulator.initialize();
      WindowManipulator.makeTitlebarTransparent();
      await WindowManipulator.setMaterial(
        NSVisualEffectViewMaterial.underWindowBackground,
      );
    }
  }

  runApp(const XellApp());
}


