import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class WatchHistoryItem {
  final String videoId;
  final String title;
  final int timestamp;

  WatchHistoryItem({
    required this.videoId,
    required this.title,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'videoId': videoId,
        'title': title,
        'timestamp': timestamp,
      };

  factory WatchHistoryItem.fromMap(Map<String, dynamic> map) =>
      WatchHistoryItem(
        videoId: map['videoId'] as String? ?? '',
        title: map['title'] as String? ?? '',
        timestamp: (map['timestamp'] as num?)?.toInt() ?? 0,
      );
}

class StatsService {
  static const String _keyTotalWatchSeconds = 'stats_real_watch_seconds';
  static const String _keyTotalVideos = 'stats_real_videos';
  static const String _keyTotalRooms = 'stats_real_rooms';
  static const String _keyTotalReactions = 'stats_real_reactions';
  static const String _keyTotalMessages = 'stats_real_messages';
  static const String _keyAvatarIndex = 'stats_avatar_index';
  static const String _keyHistory = 'stats_real_history';
  static const String _keyDailyPrefix = 'stats_daily_day_';

  static int _totalWatchSeconds = 0;
  static int _totalVideos = 0;
  static int _totalRooms = 0;
  static int _totalReactions = 0;
  static int _totalMessages = 0;
  static int _avatarIndex = 0;
  static List<WatchHistoryItem> _history = [];
  static final Map<int, int> _dailyWatchSeconds = {}; // 1 = Mon, 7 = Sun

  static const List<String> availableAvatars = [
    '🐱', '🐶', '🦊', '🐻', '🐼', '🐨', '🦁', '🐯', '🦄', '🐰', '🍿', '🎬'
  ];

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _totalWatchSeconds = prefs.getInt(_keyTotalWatchSeconds) ?? 0;
    _totalVideos = prefs.getInt(_keyTotalVideos) ?? 0;
    _totalRooms = prefs.getInt(_keyTotalRooms) ?? 0;
    _totalReactions = prefs.getInt(_keyTotalReactions) ?? 0;
    _totalMessages = prefs.getInt(_keyTotalMessages) ?? 0;
    _avatarIndex = prefs.getInt(_keyAvatarIndex) ?? 0;

    for (int day = 1; day <= 7; day++) {
      _dailyWatchSeconds[day] = prefs.getInt('$_keyDailyPrefix$day') ?? 0;
    }

    final historyRaw = prefs.getString(_keyHistory);
    if (historyRaw != null) {
      try {
        final List list = jsonDecode(historyRaw);
        _history = list.map((e) => WatchHistoryItem.fromMap(e)).toList();
      } catch (_) {}
    }
  }

  static int get totalWatchSeconds => _totalWatchSeconds;
  static int get totalVideos => _totalVideos;
  static int get totalRooms => _totalRooms;
  static int get totalReactions => _totalReactions;
  static int get totalMessages => _totalMessages;
  static int get avatarIndex => _avatarIndex;
  static List<WatchHistoryItem> get history => _history;

  static String get avatarEmoji =>
      availableAvatars[_avatarIndex % availableAvatars.length];

  static String get formattedWatchTime {
    if (_totalWatchSeconds <= 0) {
      return '0 นาที';
    }
    final hours = _totalWatchSeconds ~/ 3600;
    final minutes = (_totalWatchSeconds % 3600) ~/ 60;
    final seconds = _totalWatchSeconds % 60;

    if (hours > 0) {
      return '$hours ชม. $minutes นาที';
    } else if (minutes > 0) {
      return '$minutes นาที $seconds วินาที';
    }
    return '$seconds วินาที';
  }

  static double get totalWatchHours =>
      double.parse((_totalWatchSeconds / 3600.0).toStringAsFixed(1));

  /// Record real watch time tick (called every second during active playback)
  static Future<void> addWatchTime(int seconds) async {
    _totalWatchSeconds += seconds;
    final int todayWeekday = DateTime.now().weekday; // 1 = Mon, 7 = Sun
    _dailyWatchSeconds[todayWeekday] =
        (_dailyWatchSeconds[todayWeekday] ?? 0) + seconds;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTotalWatchSeconds, _totalWatchSeconds);
    await prefs.setInt(
        '$_keyDailyPrefix$todayWeekday', _dailyWatchSeconds[todayWeekday]!);
  }

  /// Get normalized heights for weekly bar chart (Mon - Sun)
  static List<double> getWeeklyNormalizedHeights() {
    int maxSeconds = 1;
    for (int day = 1; day <= 7; day++) {
      final sec = _dailyWatchSeconds[day] ?? 0;
      if (sec > maxSeconds) maxSeconds = sec;
    }

    final List<double> heights = [];
    for (int day = 1; day <= 7; day++) {
      final sec = _dailyWatchSeconds[day] ?? 0;
      if (sec == 0) {
        heights.add(0.12); // subtle base indicator
      } else {
        heights.add((sec / maxSeconds).clamp(0.2, 1.0));
      }
    }
    return heights;
  }

  static Future<void> incrementVideos() async {
    _totalVideos += 1;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTotalVideos, _totalVideos);
  }

  static Future<void> incrementRooms() async {
    _totalRooms += 1;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTotalRooms, _totalRooms);
  }

  static Future<void> incrementReactions() async {
    _totalReactions += 1;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTotalReactions, _totalReactions);
  }

  static Future<void> incrementMessages() async {
    _totalMessages += 1;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTotalMessages, _totalMessages);
  }

  static Future<void> setAvatarIndex(int index) async {
    _avatarIndex = index % availableAvatars.length;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyAvatarIndex, _avatarIndex);
  }

  static Future<void> addHistory(String videoId, String title) async {
    if (videoId.isEmpty) return;
    _history.removeWhere((item) => item.videoId == videoId);
    _history.insert(
      0,
      WatchHistoryItem(
        videoId: videoId,
        title: title.isNotEmpty ? title : 'YouTube Video ($videoId)',
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    if (_history.length > 30) {
      _history = _history.sublist(0, 30);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyHistory,
      jsonEncode(_history.map((e) => e.toMap()).toList()),
    );
  }

  static Future<void> clearHistory() async {
    _history.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyHistory);
  }
}
