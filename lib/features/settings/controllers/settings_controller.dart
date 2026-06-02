import 'package:flutter/material.dart';
import '../../../app/app_theme.dart';
import '../../terminal/models/terminal_theme_presets.dart';
import '../data/settings_storage.dart';

// Shared notifier so XellApp can rebuild MaterialApp without coupling.
final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

const List<double> terminalFontSizes = [11.0, 12.0, 13.5, 14.0, 15.0, 16.0];

const List<Color> accentColorPresets = [
  Color(0xFF5E81F4), // blue (default)
  Color(0xFFCBA6F7), // mauve
  Color(0xFF89DCEB), // sky
  Color(0xFFA6E3A1), // green
  Color(0xFFF9E2AF), // yellow
  Color(0xFFF38BA8), // red
];

class SettingsController {
  final _storage = SettingsStorage();

  final fontSizeNotifier = ValueNotifier<double>(13.5);
  final accentColorNotifier = ValueNotifier<Color>(AppColors.accent);
  final terminalThemeNotifier = ValueNotifier<TerminalThemeName>(TerminalThemeName.dark);

  Future<void> load() async {
    fontSizeNotifier.value = await _storage.loadFontSize();
    final colorValue = await _storage.loadAccentColorValue();
    if (colorValue != null) accentColorNotifier.value = Color(colorValue);
    themeModeNotifier.value = await _storage.loadThemeMode();
    terminalThemeNotifier.value = await _storage.loadTerminalTheme();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeModeNotifier.value = mode;
    await _storage.saveThemeMode(mode);
  }

  Future<void> setFontSize(double size) async {
    fontSizeNotifier.value = size;
    await _storage.saveFontSize(size);
  }

  Future<void> setAccentColor(Color color) async {
    accentColorNotifier.value = color;
    await _storage.saveAccentColorValue(color.toARGB32());
  }

  Future<void> setTerminalTheme(TerminalThemeName theme) async {
    terminalThemeNotifier.value = theme;
    await _storage.saveTerminalTheme(theme);
  }

  Future<void> clearAllData() async {
    await _storage.clearAll();
    fontSizeNotifier.value = 13.5;
    accentColorNotifier.value = accentColorPresets.first;
    themeModeNotifier.value = ThemeMode.dark;
    await _storage.saveFontSize(fontSizeNotifier.value);
  }

  void dispose() {
    fontSizeNotifier.dispose();
    accentColorNotifier.dispose();
    terminalThemeNotifier.dispose();
  }
}
