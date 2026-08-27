import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  static const String _keyDarkMode = 'u_sync_dark_mode_active';
  static final ValueNotifier<bool> isDarkModeNotifier = ValueNotifier<bool>(false);

  static bool get isDarkMode => isDarkModeNotifier.value;

  /// Initialize theme mode from SharedPreferences
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDark = prefs.getBool(_keyDarkMode) ?? false;
      isDarkModeNotifier.value = savedDark;
    } catch (_) {}
  }

  /// Set dark mode value and persist
  static Future<void> setDarkMode(bool enabled) async {
    if (isDarkModeNotifier.value == enabled) return;
    isDarkModeNotifier.value = enabled;
    HapticFeedback.lightImpact();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyDarkMode, enabled);
    } catch (_) {}
  }

  /// Toggle dark mode on / off
  static Future<void> toggleDarkMode() async {
    await setDarkMode(!isDarkModeNotifier.value);
  }
}
