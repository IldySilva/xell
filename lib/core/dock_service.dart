import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Manages macOS Dock badge and Dock menu items.
/// No-ops on non-macOS platforms.
class DockService {
  static const _channel = MethodChannel('xell/dock');

  static bool get _isMac => Platform.isMacOS;

  /// Sets the Dock badge to [count]. Pass 0 to clear it.
  static Future<void> setSessionCount(int count) =>
      _invoke('setBadge', count > 0 ? '$count' : null);

  /// Updates the recent hosts shown in the Dock right-click menu.
  static Future<void> setRecentHosts(List<String> hostNames) =>
      _invoke('setRecentHosts', hostNames);

  /// Dock integration is cosmetic: never let a missing or failing native
  /// handler (registered in macos/Runner/MainFlutterWindow.swift) crash the app.
  static Future<void> _invoke(String method, Object? args) async {
    if (!_isMac) return;
    try {
      await _channel.invokeMethod<void>(method, args);
    } on MissingPluginException {
      debugPrint('DockService: no native handler for $method');
    } on PlatformException catch (e) {
      debugPrint('DockService: $method failed: ${e.message}');
    }
  }
}
