import 'package:material_ui/material_ui.dart';

abstract final class AppColors {
  static const background = Color(0xFF0F1115);
  static const surface = Color(0xFF151922);
  static const surfaceElevated = Color(0xFF1A2030);
  static const border = Color(0xFF232734);
  static const text = Color(0xFFE6EAF2);
  static const textMuted = Color(0xFF9AA4B2);
  static const accent = Color(0xFF5E81F4);
}

abstract final class AppSpacing {
  static const s4 = 4.0;
  static const s8 = 8.0;
  static const s12 = 12.0;
  static const s16 = 16.0;
  static const s24 = 24.0;
  static const s32 = 32.0;
  static const s48 = 48.0;
  static const s64 = 64.0;
}

abstract final class AppTheme {
  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.surface,
        primary: AppColors.accent,
        onPrimary: Colors.white,
        onSurface: AppColors.text,
        outline: AppColors.border,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppColors.text, fontSize: 14),
        bodyMedium: TextStyle(color: AppColors.text, fontSize: 13),
        bodySmall: TextStyle(color: AppColors.textMuted, fontSize: 12),
        titleMedium: TextStyle(
          color: AppColors.text,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        labelSmall: TextStyle(color: AppColors.textMuted, fontSize: 11),
      ),
      dividerColor: AppColors.border,
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static ThemeData light() {
    const bg = Color(0xFFF5F6F8);
    const surface = Color(0xFFFFFFFF);
    const border = Color(0xFFE2E8F0);
    const text = Color(0xFF1A202C);
    const muted = Color(0xFF718096);

    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.light(
        surface: surface,
        primary: AppColors.accent,
        onPrimary: Colors.white,
        onSurface: text,
        outline: border,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: text, fontSize: 14),
        bodyMedium: TextStyle(color: text, fontSize: 13),
        bodySmall: TextStyle(color: muted, fontSize: 12),
        titleMedium: TextStyle(color: text, fontSize: 14, fontWeight: FontWeight.w600),
        labelSmall: TextStyle(color: muted, fontSize: 11),
      ),
      dividerColor: border,
      dividerTheme: const DividerThemeData(color: border, thickness: 1, space: 1),
    );
  }
}
