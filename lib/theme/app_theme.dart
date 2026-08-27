import 'package:flutter/material.dart';
import '../services/theme_service.dart';

class AppColors {
  // Base Constants (preserves const safety across all widgets)
  static const Color background = Color(0xFFF4F0FA);
  static const Color surface = Colors.white;
  static const Color surfaceElevated = Color(0xFFFFFFFF);

  // Text Colors
  static const Color textPrimary = Color(0xFF191824);
  static const Color textSecondary = Color(0xFF7E7C8E);
  static const Color textMuted = Color(0xFFA5A3B3);

  // Bento Pastel Accents
  static const Color purplePastel = Color(0xFFD6C5FC);
  static const Color purpleDeep = Color(0xFF7B4DFF);
  
  static const Color orangePastel = Color(0xFFFFC67D);
  static const Color orangeDeep = Color(0xFFFF8A00);
  
  static const Color bluePastel = Color(0xFFBCE3FF);
  static const Color blueDeep = Color(0xFF2B93FF);
  
  static const Color greenPastel = Color(0xFFC7F9CC);
  static const Color greenDeep = Color(0xFF38B000);
  
  static const Color pinkPastel = Color(0xFFFFC4D6);
  static const Color pinkDeep = Color(0xFFFF4D6D);

  // Bottom Navigation
  static const Color darkNav = Color(0xFF191824);

  // Dynamic Theme Helpers
  static bool get isDark => ThemeService.isDarkMode;
  static Color get cardBg => isDark ? const Color(0xFF1B1926) : Colors.white;
  static Color get divider => isDark ? const Color(0xFF2B283D) : const Color(0xFFF0EDF6);
  static Color get bg => isDark ? const Color(0xFF0F0E16) : const Color(0xFFF4F0FA);
  static Color get currentNav => isDark ? const Color(0xFF1B1926) : const Color(0xFF191824);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF4F0FA),
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
        centerTitle: false,
      ),
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0F0E16),
      splashColor: const Color(0xFF9D78FF).withValues(alpha: 0.25),
      highlightColor: const Color(0xFF9D78FF).withValues(alpha: 0.12),
      splashFactory: InkRipple.splashFactory,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF9D78FF),
        secondary: Color(0xFFFF9E3B),
        surface: Color(0xFF1B1926),
        onSurface: Color(0xFFF7F5FC),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Color(0xFFF7F5FC),
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: const CardThemeData(
        color: Color(0xFF1B1926),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
      ),
    );
  }
}
