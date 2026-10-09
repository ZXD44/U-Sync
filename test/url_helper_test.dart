import 'package:flutter_test/flutter_test.dart';
import 'package:usync_app/services/url_helper.dart';

void main() {
  group('UrlHelper.extractYouTubeId', () {
    test('extracts direct 11-char ID', () {
      expect(UrlHelper.extractYouTubeId('dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
    });

    test('extracts standard watch URL', () {
      expect(
        UrlHelper.extractYouTubeId('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
    });

    test('extracts youtu.be short URL', () {
      expect(
        UrlHelper.extractYouTubeId('https://youtu.be/dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
    });

    test('extracts shorts URL', () {
      expect(
        UrlHelper.extractYouTubeId('https://youtube.com/shorts/dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
    });

    test('extracts live URL', () {
      expect(
        UrlHelper.extractYouTubeId('https://www.youtube.com/live/dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
    });

    test('extracts embed URL', () {
      expect(
        UrlHelper.extractYouTubeId('https://www.youtube.com/embed/dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
    });

    test('returns null for empty or invalid string', () {
      expect(UrlHelper.extractYouTubeId(''), isNull);
      expect(UrlHelper.extractYouTubeId('   '), isNull);
      expect(UrlHelper.extractYouTubeId('not_a_valid_youtube_link_or_id'), isNull);
    });
  });

  group('UrlHelper.formatDuration', () {
    test('formats seconds to mm:ss', () {
      expect(UrlHelper.formatDuration(65), '01:05');
      expect(UrlHelper.formatDuration(0), '00:00');
    });

    test('formats hours to hh:mm:ss', () {
      expect(UrlHelper.formatDuration(3665), '1:01:05');
    });
  });
}
