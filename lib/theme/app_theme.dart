import 'package:flutter/material.dart';

class AppColors {
  // Base Colors
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
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      splashColor: AppColors.purplePastel.withValues(alpha: 0.25),
      highlightColor: AppColors.purplePastel.withValues(alpha: 0.12),
      splashFactory: InkRipple.splashFactory,
      colorScheme: const ColorScheme.light(
        primary: AppColors.purpleDeep,
        secondary: AppColors.orangeDeep,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
      ),
      fontFamily: null, // Uses default clean modern sans-serif
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          elevation: WidgetStateProperty.all(0),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return AppColors.purplePastel.withValues(alpha: 0.25);
            }
            if (states.contains(WidgetState.hovered)) {
              return AppColors.purplePastel.withValues(alpha: 0.1);
            }
            return null;
          }),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          textStyle: WidgetStateProperty.all(
            const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return AppColors.purplePastel.withValues(alpha: 0.25);
            }
            return null;
          }),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return AppColors.purplePastel.withValues(alpha: 0.2);
            }
            return null;
          }),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return AppColors.purplePastel.withValues(alpha: 0.25);
            }
            return null;
          }),
        ),
      ),
    );
  }
}
