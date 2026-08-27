import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceService {
  static const String _keyDeviceId = 'sync_device_id';
  static const String _keyNickname = 'sync_nickname';

  static String? _cachedDeviceId;
  static String? _cachedNickname;

  /// Initialize and load saved deviceId and nickname
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedDeviceId = prefs.getString(_keyDeviceId);
    if (_cachedDeviceId == null) {
      _cachedDeviceId = const Uuid().v4().substring(0, 8);
      await prefs.setString(_keyDeviceId, _cachedDeviceId!);
    }

    _cachedNickname = prefs.getString(_keyNickname);
    if (_cachedNickname == null || _cachedNickname!.isEmpty) {
      _cachedNickname = 'ผู้ใช้-$_cachedDeviceId';
      await prefs.setString(_keyNickname, _cachedNickname!);
    }
  }

  static String getDeviceId() {
    _cachedDeviceId ??= const Uuid().v4().substring(0, 8);
    return _cachedDeviceId!;
  }

  static String getNickname() {
    return _cachedNickname ?? 'ผู้ใช้-${getDeviceId()}';
  }

  static Future<void> setNickname(String newNickname) async {
    final cleanName = newNickname.trim();
    if (cleanName.isEmpty) return;
    _cachedNickname = cleanName;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyNickname, cleanName);
  }

  static void setCustomDeviceId(String id) {
    _cachedDeviceId = id;
  }
}
