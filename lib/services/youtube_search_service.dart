import 'dart:convert';
import 'package:http/http.dart' as http;
import 'url_helper.dart';

class YouTubeSearchResult {
  final String videoId;
  final String title;
  final String channelTitle;
  final String duration;
  final String thumbnailUrl;

  YouTubeSearchResult({
    required this.videoId,
    required this.title,
    required this.channelTitle,
    required this.duration,
    required this.thumbnailUrl,
  });
}

class YouTubeSearchService {
  /// Search YouTube videos by keyword or parse direct link
  static Future<List<YouTubeSearchResult>> search(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    // 1. If it's a direct YouTube URL or 11-char ID, return it as single result
    final directId = UrlHelper.extractYouTubeId(cleanQuery);
    if (directId != null && directId.length == 11) {
      return [
        YouTubeSearchResult(
          videoId: directId,
          title: 'วิดีโอ YouTube ($directId)',
          channelTitle: 'YouTube',
          duration: 'พร้อมเล่น',
          thumbnailUrl: 'https://img.youtube.com/vi/$directId/hqdefault.jpg',
        ),
      ];
    }

    // 2. Perform live YouTube web search via HTML extraction
    try {
      final searchUrl = Uri.parse(
        'https://www.youtube.com/results?search_query=${Uri.encodeComponent(cleanQuery)}&sp=EgIQAQ%253D%253D',
      );

      final response = await http.get(
        searchUrl,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept-Language': 'th,en;q=0.9',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final results = _parseYouTubeInitialData(response.body);
        if (results.isNotEmpty) {
          return results;
        }
      }
    } catch (_) {}

    // 3. Fallback: Public Invidious search API
    try {
      final invidiousUrl = Uri.parse(
        'https://inv.tux.pizza/api/v1/search?q=${Uri.encodeComponent(cleanQuery)}&type=video',
      );
      final response = await http
          .get(invidiousUrl)
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.take(15).map((item) {
          final id = item['videoId']?.toString() ?? '';
          final sec = (item['lengthSeconds'] as num?)?.toInt() ?? 0;
          final mins = sec ~/ 60;
          final secs = (sec % 60).toString().padLeft(2, '0');

          return YouTubeSearchResult(
            videoId: id,
            title: item['title']?.toString() ?? 'YouTube Video',
            channelTitle: item['author']?.toString() ?? '',
            duration: '$mins:$secs',
            thumbnailUrl: 'https://img.youtube.com/vi/$id/hqdefault.jpg',
          );
        }).where((e) => e.videoId.isNotEmpty).toList();
      }
    } catch (_) {}

    return [];
  }

  /// Parse videoRenderer from ytInitialData inside YouTube HTML
  static List<YouTubeSearchResult> _parseYouTubeInitialData(String html) {
    final List<YouTubeSearchResult> list = [];
    try {
      const startToken = 'var ytInitialData = ';
      final startIndex = html.indexOf(startToken);
      if (startIndex == -1) return list;

      final dataSub = html.substring(startIndex + startToken.length);
      final endIndex = dataSub.indexOf(';</script>');
      if (endIndex == -1) return list;

      final jsonStr = dataSub.substring(0, endIndex);
      final Map data = jsonDecode(jsonStr);

      final contents = data['contents']?['twoColumnSearchResultsRenderer']
          ?['primaryContents']?['sectionListRenderer']?['contents'];

      if (contents is List) {
        for (var section in contents) {
          final itemSection = section['itemSectionRenderer']?['contents'];
          if (itemSection is List) {
            for (var item in itemSection) {
              final video = item['videoRenderer'];
              if (video != null) {
                final videoId = video['videoId']?.toString() ?? '';
                final title =
                    video['title']?['runs']?[0]?['text']?.toString() ??
                        video['title']?['simpleText']?.toString() ??
                        '';
                final channel = video['ownerText']?['runs']?[0]?['text']
                        ?.toString() ??
                    video['shortBylineText']?['runs']?[0]?['text']
                        ?.toString() ??
                    '';
                final duration =
                    video['lengthText']?['simpleText']?.toString() ??
                        video['lengthText']?['runs']?[0]?['text']?.toString() ??
                        '';

                if (videoId.isNotEmpty && title.isNotEmpty) {
                  list.add(
                    YouTubeSearchResult(
                      videoId: videoId,
                      title: title,
                      channelTitle: channel,
                      duration: duration,
                      thumbnailUrl:
                          'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
                    ),
                  );
                }
              }
            }
          }
        }
      }
    } catch (_) {}

    return list.take(15).toList();
  }
}
