import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class FavoriteRoom {
  final String roomId;
  final String roomName;
  final int savedAt;

  FavoriteRoom({
    required this.roomId,
    required this.roomName,
    required this.savedAt,
  });

  Map<String, dynamic> toMap() => {
        'roomId': roomId,
        'roomName': roomName,
        'savedAt': savedAt,
      };

  factory FavoriteRoom.fromMap(Map<String, dynamic> map) => FavoriteRoom(
        roomId: map['roomId'] as String? ?? '',
        roomName: map['roomName'] as String? ?? '',
        savedAt: (map['savedAt'] as num?)?.toInt() ?? 0,
      );
}

class FavoritesService {
  static const String _keyFavorites = 'fav_saved_rooms';
  static const String _keySoundEnabled = 'setting_sound_enabled';

  static List<FavoriteRoom> _favorites = [];
  static bool _soundEnabled = true;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _soundEnabled = prefs.getBool(_keySoundEnabled) ?? true;

    final raw = prefs.getString(_keyFavorites);
    if (raw != null) {
      try {
        final List list = jsonDecode(raw);
        _favorites = list.map((e) => FavoriteRoom.fromMap(e)).toList();
      } catch (_) {}
    }
  }

  static List<FavoriteRoom> get favorites => _favorites;
  static bool get soundEnabled => _soundEnabled;

  static bool isFavorite(String roomId) {
    return _favorites.any((r) => r.roomId == roomId);
  }

  static Future<bool> toggleFavorite(String roomId, String roomName) async {
    final prefs = await SharedPreferences.getInstance();
    final index = _favorites.indexWhere((r) => r.roomId == roomId);

    if (index >= 0) {
      _favorites.removeAt(index);
      await prefs.setString(
          _keyFavorites, jsonEncode(_favorites.map((e) => e.toMap()).toList()));
      return false; // Removed
    } else {
      _favorites.insert(
        0,
        FavoriteRoom(
          roomId: roomId,
          roomName: roomName.isNotEmpty ? roomName : roomId,
          savedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      await prefs.setString(
          _keyFavorites, jsonEncode(_favorites.map((e) => e.toMap()).toList()));
      return true; // Added
    }
  }

  static Future<void> setSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySoundEnabled, enabled);
  }
}
