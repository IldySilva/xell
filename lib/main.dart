import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:macos_window_utils/macos_window_utils.dart';
import 'package:window_manager/window_manager.dart';
import 'app/xell_app.dart';
import 'core/window_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
    final window = WindowManager.instance.getCurrent();
    if (window != null) {
      window
        ..minimumSize = const Size(860, 560).toNative()
        ..backgroundColor = Colors.transparent.toNative();
      // On macOS this would also remove the traffic lights; the title bar is
      // handled by macos_window_utils below instead.
      if (!Platform.isMacOS) window.titleBarStyle = TitleBarStyle.hidden;
      window.setSize(const Size(1280, 800).toNative(), false);
      window.center();
      await WindowPreferences.restore();
      window
        ..show()
        ..focus();
    }

    if (Platform.isMacOS) {
      await WindowManipulator.initialize();
      // nativeapi's titleBarStyle does not extend content under the title
      // bar on macOS; do it with macos_window_utils, as before.
      await WindowManipulator.makeTitlebarTransparent();
      await WindowManipulator.enableFullSizeContentView();
      await WindowManipulator.hideTitle();
      await WindowManipulator.setMaterial(
        NSVisualEffectViewMaterial.underWindowBackground,
      );
    }
  }

  runApp(const XellApp());
}


