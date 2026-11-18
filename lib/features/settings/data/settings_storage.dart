import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../terminal/models/terminal_theme_presets.dart';

class SettingsStorage {
  static const _fontSizeKey = 'xell.terminalFontSize';
  static const _accentColorKey = 'xell.accentColor';
  static const _themeModeKey = 'xell.themeMode';
  static const _terminalThemeKey = 'xell.terminalTheme';

  Future<ThemeMode> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_themeModeKey);
    return switch (value) {
      'light' => ThemeMode.light,
      _ => ThemeMode.dark,
    };
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode == ThemeMode.light ? 'light' : 'dark');
  }

  Future<double> loadFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_fontSizeKey) ?? 13.5;
  }

  Future<void> saveFontSize(double size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontSizeKey, size);
  }

  Future<int?> loadAccentColorValue() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_accentColorKey);
  }

  Future<void> saveAccentColorValue(int colorValue) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_accentColorKey, colorValue);
  }

  Future<TerminalThemeName> loadTerminalTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_terminalThemeKey);
    return TerminalThemeName.values.firstWhere(
      (t) => t.name == value,
      orElse: () => TerminalThemeName.dark,
    );
  }

  Future<void> saveTerminalTheme(TerminalThemeName theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_terminalThemeKey, theme.name);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
