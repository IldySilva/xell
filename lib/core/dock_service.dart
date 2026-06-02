import 'dart:io';
import 'package:flutter/services.dart';

/// Manages macOS Dock badge and Dock menu items.
/// No-ops on non-macOS platforms.
class DockService {
  static const _channel = MethodChannel('xell/dock');

  static bool get _isMac => Platform.isMacOS;

  /// Sets the Dock badge to [count]. Pass null or 0 to clear it.
  static Future<void> setSessionCount(int count) async {
    if (!_isMac) return;
    await _channel.invokeMethod<void>(
      'setBadge',
      count > 0 ? '$count' : null,
    );
  }

  /// Updates the recent hosts shown in the Dock right-click menu.
  static Future<void> setRecentHosts(List<String> hostNames) async {
    if (!_isMac) return;
    await _channel.invokeMethod<void>('setRecentHosts', hostNames);
  }
}
