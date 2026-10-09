import 'package:flutter/material.dart';
import '../services/theme_service.dart';

class AppColors {
  static bool get isDark => ThemeService.isDarkMode;

  // Background & Surfaces
  static Color get background =>
      isDark ? const Color(0xFF0F0E17) : const Color(0xFFF6F4FA);
  static Color get surface =>
      isDark ? const Color(0xFF1A1826) : Colors.white;
  static Color get surfaceElevated =>
      isDark ? const Color(0xFF232033) : const Color(0xFFFFFFFF);
  static Color get cardBg =>
      isDark ? const Color(0xFF1A1826) : Colors.white;
  static Color get inputBg =>
      isDark ? const Color(0xFF13121E) : const Color(0xFFF2EEF8);
  static Color get divider =>
      isDark ? const Color(0xFF2B273D) : const Color(0xFFECE7F4);
  static Color get modalBg =>
      isDark ? const Color(0xFF1A1826) : Colors.white;

  // Text Colors (High contrast, beautiful typography)
  static Color get textPrimary =>
      isDark ? const Color(0xFFF5F4FA) : const Color(0xFF191824);
  static Color get textSecondary =>
      isDark ? const Color(0xFF9E9BAE) : const Color(0xFF7E7C8E);
  static Color get textMuted =>
      isDark ? const Color(0xFF6E6B7E) : const Color(0xFFA5A3B3);

  // Bento Pastel Accents (Rich in Light, Glowing & legible in Dark)
  static Color get purplePastel =>
      isDark ? const Color(0xFF2B224C) : const Color(0xFFD6C5FC);
  static Color get purpleDeep =>
      isDark ? const Color(0xFF9E77FF) : const Color(0xFF7B4DFF);

  static Color get orangePastel =>
      isDark ? const Color(0xFF382414) : const Color(0xFFFFC67D);
  static Color get orangeDeep =>
      isDark ? const Color(0xFFFF9A3C) : const Color(0xFFFF8A00);

  static Color get bluePastel =>
      isDark ? const Color(0xFF182944) : const Color(0xFFBCE3FF);
  static Color get blueDeep =>
      isDark ? const Color(0xFF4CA4FF) : const Color(0xFF2B93FF);

  static Color get greenPastel =>
      isDark ? const Color(0xFF173622) : const Color(0xFFC7F9CC);
  static Color get greenDeep =>
      isDark ? const Color(0xFF4ADE80) : const Color(0xFF38B000);

  static Color get pinkPastel =>
      isDark ? const Color(0xFF3D1B2C) : const Color(0xFFFFC4D6);
  static Color get pinkDeep =>
      isDark ? const Color(0xFFFF5E80) : const Color(0xFFFF4D6D);

  // Navigation Bar
  static Color get darkNav =>
      isDark ? const Color(0xFF13121E) : const Color(0xFF191824);
  static Color get currentNav =>
      isDark ? const Color(0xFF13121E) : const Color(0xFF191824);
  static Color get navItemActiveBg =>
      isDark ? const Color(0xFF2A263D) : Colors.white;
  static Color get bg => background;
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF6F4FA),
      splashColor: const Color(0xFFD6C5FC).withValues(alpha: 0.25),
      highlightColor: const Color(0xFFD6C5FC).withValues(alpha: 0.12),
      splashFactory: InkRipple.splashFactory,
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF7B4DFF),
        secondary: Color(0xFFFF8A00),
        surface: Colors.white,
        onSurface: Color(0xFF191824),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Color(0xFF191824),
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(26)),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0F0E17),
      splashColor: const Color(0xFF9E77FF).withValues(alpha: 0.25),
      highlightColor: const Color(0xFF9E77FF).withValues(alpha: 0.12),
      splashFactory: InkRipple.splashFactory,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF9E77FF),
        secondary: Color(0xFFFF9A3C),
        surface: Color(0xFF1A1826),
        onSurface: Color(0xFFF5F4FA),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Color(0xFFF5F4FA),
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: const CardThemeData(
        color: Color(0xFF1A1826),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Color(0xFF1A1826),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(26)),
        ),
      ),
    );
  }
}
