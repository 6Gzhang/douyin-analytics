import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../security/secure_http_client.dart' as secure;
import '../security/secure_logger.dart';

class AppVersion {
  final String version;
  final String? downloadUrl;
  final String? releaseNotes;
  final DateTime? publishedAt;

  AppVersion({
    required this.version,
    this.downloadUrl,
    this.releaseNotes,
    this.publishedAt,
  });

  bool isNewerThan(String currentVersion) {
    final current = _parseVersion(currentVersion);
    final latest = _parseVersion(version);
    if (current == null || latest == null) return false;
    for (int i = 0; i < 3; i++) {
      if (latest[i] > current[i]) return true;
      if (latest[i] < current[i]) return false;
    }
    return false;
  }

  List<int>? _parseVersion(String v) {
    try {
      final cleaned = v.toLowerCase().replaceAll('v', '').split('+').first;
      final parts = cleaned.split('.').map(int.parse).toList();
      while (parts.length < 3) {
        parts.add(0);
      }
      return parts.sublist(0, 3);
    } catch (_) {
      return null;
    }
  }
}

class UpdateService {
  static const String repoOwner = '6Gzhang';
  static const String repoName = 'douyin-analytics';
  static const String apiUrl =
      'https://api.github.com/repos/$repoOwner/$repoName/releases/latest';

  static Future<String> getCurrentVersion() async {
    try {
      final manifestContent = await rootBundle.loadString('pubspec.yaml');
      final lines = manifestContent.split('\n');
      for (final line in lines) {
        if (line.startsWith('version:')) {
          return line.substring(9).trim();
        }
      }
    } catch (e) {
      debugPrint('读取版本号失败: $e');
    }
    return '1.1.0';
  }

  static Future<AppVersion?> checkForUpdate([String? currentVersion]) async {
    try {
      final version = currentVersion ?? await getCurrentVersion();
      debugPrint('检查更新: 当前版本 $version');

      // URL 安全校验
      if (!secure.SecureHttpClient.isUrlSafe(apiUrl)) {
        SecureLogger.instance.warning(
          '更新检查 URL 不安全: $apiUrl',
          event: SecurityEventType.suspiciousActivity,
        );
        return null;
      }

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('更新检查失败: HTTP ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = data['tag_name'] as String?;
      if (tagName == null) {
        debugPrint('更新检查失败: tag_name 为空');
        return null;
      }

      final latestVersion = tagName.toLowerCase().replaceAll('v', '');
      debugPrint('更新检查: 最新版本 $latestVersion');
      
      final appVersion = AppVersion(
        version: latestVersion,
        downloadUrl: _findDownloadUrl(data),
        releaseNotes: data['body'] as String?,
        publishedAt: data['published_at'] != null
            ? DateTime.tryParse(data['published_at'] as String)
            : null,
      );

      if (appVersion.isNewerThan(version)) {
        debugPrint('更新检查: 发现新版本 $latestVersion');
        SecureLogger.instance.info(
          '发现新版本: $latestVersion',
          event: SecurityEventType.updateChecked,
          meta: {'current': version, 'latest': latestVersion},
        );
        return appVersion;
      }
      debugPrint('更新检查: 当前已是最新版本');
      return null;
    } on http.ClientException catch (e) {
      debugPrint('更新检查失败: 网络错误 $e');
      return null;
    } on TimeoutException catch (_) {
      debugPrint('更新检查失败: 请求超时');
      return null;
    } catch (e) {
      debugPrint('更新检查失败: $e');
      return null;
    }
  }

  static String? _findDownloadUrl(Map<String, dynamic> data) {
    final assets = data['assets'] as List<dynamic>?;
    if (assets == null || assets.isEmpty) {
      final htmlUrl = data['html_url'] as String?;
      if (htmlUrl != null && secure.SecureHttpClient.isUrlSafe(htmlUrl)) {
        return htmlUrl;
      }
      return null;
    }

    for (final asset in assets) {
      final name = (asset['name'] as String).toLowerCase();
      if (Platform.isMacOS && (name.contains('.dmg') || name.contains('macos'))) {
        final url = asset['browser_download_url'] as String?;
        if (url != null && secure.SecureHttpClient.isUrlSafe(url)) {
          return url;
        }
      }
    }

    final htmlUrl = data['html_url'] as String?;
    if (htmlUrl != null && secure.SecureHttpClient.isUrlSafe(htmlUrl)) {
      return htmlUrl;
    }
    return null;
  }

  /// 下载更新文件，返回下载文件路径
  static Future<String> downloadUpdate(
    String url, {
    void Function(double progress)? onProgress,
  }) async {
    final dir = await getTemporaryDirectory();
    final fileName = 'douyin_analytics_update.dmg';
    final file = File('${dir.path}/$fileName');

    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode != 200) {
        throw Exception('下载失败: HTTP ${response.statusCode}');
      }

      final totalBytes = response.contentLength;
      final sink = file.openWrite();
      int received = 0;

      await for (final chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        if (totalBytes > 0 && onProgress != null) {
          onProgress(received / totalBytes);
        }
      }

      await sink.close();
      SecureLogger.instance.info(
        '更新文件下载完成: $fileName (${(received / 1024 / 1024).toStringAsFixed(1)} MB)',
        event: SecurityEventType.updateDownloaded,
      );

      return file.path;
    } catch (e) {
      // 清理下载失败的文件
      if (await file.exists()) {
        await file.delete();
      }
      rethrow;
    } finally {
      client.close();
    }
  }

  /// 打开下载的安装包
  static Future<void> openInstaller(String filePath) async {
    if (Platform.isMacOS) {
      await Process.run('open', [filePath]);
    } else {
      throw UnsupportedError('当前平台不支持自动安装');
    }
  }
}
