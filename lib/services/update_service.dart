import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class AppReleaseInfo {
  final String latestVersion;
  final String changelog;
  final String downloadUrl;
  final bool hasUpdate;

  AppReleaseInfo({
    required this.latestVersion,
    required this.changelog,
    required this.downloadUrl,
    required this.hasUpdate,
  });
}

class UpdateService {
  static const String currentVersion = '1.0.7';
  static const String githubRepo = 'ZXD44/U-Sync';
  static const MethodChannel _channel = MethodChannel('com.usync.app/updater');

  /// Check GitHub releases for a newer version
  static Future<AppReleaseInfo?> checkForUpdate() async {
    try {
      final url = Uri.parse('https://api.github.com/repos/$githubRepo/releases/latest');
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'U-Sync-App',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final String tagName = (data['tag_name'] ?? '').toString().replaceAll('v', '').trim();
        final String body = (data['body'] ?? 'อัปเดตประสิทธิภาพและการแก้ไขข้อผิดพลาดทั่วไป').toString();

        String apkUrl = '';
        final assets = data['assets'] as List?;
        if (assets != null && assets.isNotEmpty) {
          for (var asset in assets) {
            final name = (asset['name'] ?? '').toString();
            if (name.endsWith('.apk')) {
              apkUrl = (asset['browser_download_url'] ?? '').toString();
              break;
            }
          }
        }

        if (apkUrl.isEmpty) {
          apkUrl = 'https://github.com/$githubRepo/releases/latest/download/U-Sync.apk';
        }

        final bool hasNewer = _isVersionNewer(tagName, currentVersion);

        return AppReleaseInfo(
          latestVersion: tagName.isNotEmpty ? tagName : currentVersion,
          changelog: body,
          downloadUrl: apkUrl,
          hasUpdate: hasNewer,
        );
      }
    } catch (_) {}
    return null;
  }

  /// Compare two semantic version strings (e.g. "1.0.1" > "1.0.0")
  static bool _isVersionNewer(String latest, String current) {
    if (latest.isEmpty) return false;
    try {
      final latestParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      for (int i = 0; i < 3; i++) {
        final l = i < latestParts.length ? latestParts[i] : 0;
        final c = i < currentParts.length ? currentParts[i] : 0;
        if (l > c) return true;
        if (l < c) return false;
      }
    } catch (_) {}
    return false;
  }

  /// Download APK with progress stream & trigger installation
  static Future<bool> downloadAndInstall({
    required String downloadUrl,
    required Function(double progress, double downloadedMb, double totalMb) onProgress,
  }) async {
    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(downloadUrl));
      request.headers['User-Agent'] = 'U-Sync-App';
      final response = await client.send(request);

      if (response.statusCode != 200 && response.statusCode != 302) {
        return false;
      }

      final totalBytes = response.contentLength ?? (23 * 1024 * 1024); // Fallback ~23MB
      final totalMb = totalBytes / (1024 * 1024);

      final tempDir = await getTemporaryDirectory();
      final apkFile = File('${tempDir.path}/U-Sync-update.apk');
      if (await apkFile.exists()) {
        await apkFile.delete();
      }

      final sink = apkFile.openWrite();
      int receivedBytes = 0;

      await for (var chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        final progress = (receivedBytes / totalBytes).clamp(0.0, 1.0);
        final downloadedMb = receivedBytes / (1024 * 1024);
        onProgress(progress, downloadedMb, totalMb);
      }

      await sink.flush();
      await sink.close();

      // Trigger native package install via MethodChannel
      final bool? success = await _channel.invokeMethod<bool>('installApk', {
        'filePath': apkFile.path,
      });

      return success ?? false;
    } catch (_) {
      return false;
    }
  }
}
