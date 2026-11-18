import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

abstract final class WindowPreferences {
  static const _keyWidth = 'xell.window.width';
  static const _keyHeight = 'xell.window.height';
  static const _keyX = 'xell.window.x';
  static const _keyY = 'xell.window.y';

  static bool get _isDesktop =>
      Platform.isMacOS || Platform.isLinux || Platform.isWindows;

  static Future<void> restore() async {
    if (!_isDesktop) return;
    final prefs = await SharedPreferences.getInstance();
    final width = prefs.getDouble(_keyWidth);
    final height = prefs.getDouble(_keyHeight);
    final x = prefs.getDouble(_keyX);
    final y = prefs.getDouble(_keyY);

    final window = WindowManager.instance.getCurrent();
    if (window == null) return;
    if (width != null && height != null) {
      window.setSize(Size(width, height).toNative(), false);
    }
    if (x != null && y != null) {
      window.position = Offset(x, y).toNative();
    }
  }

  static Future<void> save() async {
    if (!_isDesktop) return;
    final window = WindowManager.instance.getCurrent();
    if (window == null) return;
    final prefs = await SharedPreferences.getInstance();
    final size = window.size.toSize();
    final position = window.position.toOffset();
    await prefs.setDouble(_keyWidth, size.width);
    await prefs.setDouble(_keyHeight, size.height);
    await prefs.setDouble(_keyX, position.dx);
    await prefs.setDouble(_keyY, position.dy);
  }
}
