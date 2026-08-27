import 'package:flutter/services.dart';

class PipService {
  static const MethodChannel _channel = MethodChannel('com.usync.app/pip');

  /// Check if Picture-in-Picture is supported on this Android device (Android 8.0+)
  static Future<bool> isPipSupported() async {
    try {
      final bool? supported = await _channel.invokeMethod<bool>('isPipSupported');
      return supported ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Manually enter Picture-in-Picture mode (Floating Mini Player)
  static Future<bool> enterPip() async {
    try {
      final bool? success = await _channel.invokeMethod<bool>('enterPip');
      return success ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Tell Android whether the user is actively in a watch party so auto-PiP triggers on swipe away
  static Future<void> setPartyActive(bool active) async {
    try {
      await _channel.invokeMethod('setPartyActive', {'active': active});
    } catch (_) {}
  }
}
