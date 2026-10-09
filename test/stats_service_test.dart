import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usync_app/services/stats_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StatsService.init();
  });

  group('StatsService', () {
    test('initializes with default zero values', () {
      expect(StatsService.totalWatchSeconds, 0);
      expect(StatsService.totalVideos, 0);
      expect(StatsService.totalRooms, 0);
      expect(StatsService.totalReactions, 0);
      expect(StatsService.totalMessages, 0);
      expect(StatsService.history, isEmpty);
      expect(StatsService.formattedWatchTime, '0 นาที');
    });

    test('addWatchTime updates total seconds and formatted output', () async {
      await StatsService.addWatchTime(125);
      expect(StatsService.totalWatchSeconds, 125);
      expect(StatsService.formattedWatchTime, '2 นาที 5 วินาที');

      await StatsService.addWatchTime(3600);
      expect(StatsService.totalWatchSeconds, 3725);
      expect(StatsService.formattedWatchTime, '1 ชม. 2 นาที');
    });

    test('increments rooms, videos, reactions, and messages', () async {
      await StatsService.incrementRooms();
      await StatsService.incrementVideos();
      await StatsService.incrementReactions();
      await StatsService.incrementMessages();

      expect(StatsService.totalRooms, 1);
      expect(StatsService.totalVideos, 1);
      expect(StatsService.totalReactions, 1);
      expect(StatsService.totalMessages, 1);
    });

    test('records watch history', () async {
      await StatsService.addHistory('testVideo123', 'Sample Title');
      expect(StatsService.history.length, 1);
      expect(StatsService.history.first.videoId, 'testVideo123');
      expect(StatsService.history.first.title, 'Sample Title');

      await StatsService.clearHistory();
      expect(StatsService.history, isEmpty);
    });
  });
}
