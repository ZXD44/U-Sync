class UrlHelper {
  /// Extracts the 11-character YouTube video ID from various URL formats:
  /// - https://www.youtube.com/watch?v=VIDEO_ID
  /// - https://youtu.be/VIDEO_ID
  /// - https://m.youtube.com/watch?v=VIDEO_ID
  /// - https://youtube.com/shorts/VIDEO_ID
  /// - https://www.youtube.com/live/VIDEO_ID
  /// - https://www.youtube.com/embed/VIDEO_ID
  /// - Plain 11-character ID directly
  static String? extractYouTubeId(String input) {
    final cleanInput = input.trim();
    if (cleanInput.isEmpty) return null;

    // Check if user already provided raw 11-character video ID
    if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(cleanInput)) {
      return cleanInput;
    }

    final RegExp regExp = RegExp(
      r'(?:https?:\/\/)?(?:www\.|m\.)?(?:youtube\.com\/(?:watch\?v=|embed\/|v\/|shorts\/|live\/)|youtu\.be\/)([a-zA-Z0-9_-]{11})',
      caseSensitive: false,
    );

    final Match? match = regExp.firstMatch(cleanInput);
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }

    // Secondary fallback for query parameters like ?v=XXXXXXXXXXX
    try {
      final uri = Uri.parse(cleanInput);
      if (uri.queryParameters.containsKey('v')) {
        final v = uri.queryParameters['v'];
        if (v != null && v.length == 11) {
          return v;
        }
      }
    } catch (_) {
      // Invalid URI syntax
    }

    return null;
  }

  /// Format seconds into mm:ss or hh:mm:ss
  static String formatDuration(double seconds) {
    final duration = Duration(milliseconds: (seconds * 1000).toInt());
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (duration.inHours > 0) {
      return '${duration.inHours}:$minutes:$secs';
    }
    return '$minutes:$secs';
  }
}
